"""
IndexService: an embedding index for semantic search over the vault.

Each note is embedded once (OpenAI), the query is embedded per request, and
ranking is brute-force cosine similarity (numpy). Combined with the existing
keyword search this yields a hybrid result set.

Graceful degradation: without OPENAI_API_KEY — or on any embedding-API
failure — every method is a no-op and search falls back to keyword-only.
The server must never break because of the index.

This module imports nothing from vault_service (vault_service imports this) —
so it carries its own lean frontmatter parser.
"""
import hashlib
import json
import os
from pathlib import Path
from typing import Optional

import numpy as np

from config import get_settings


def _parse_note(path: Path, vault_root: Path) -> Optional[dict]:
    """Parse a vault markdown file into a frontmatter meta dict.

    Returns keys: file_path (relative), content, plus every frontmatter field.
    Mirrors VaultService._parse_frontmatter without importing it.
    """
    try:
        text = path.read_text(encoding="utf-8")
        if not text.startswith("---"):
            return None
        end = text.index("---", 3)
        fm = text[3:end].strip()
        result = {
            "file_path": str(path.relative_to(vault_root)),
            "content": text[end + 3:].strip(),
        }
        for line in fm.splitlines():
            if ":" in line:
                k, _, v = line.partition(":")
                result[k.strip()] = v.strip()
        return result
    except Exception:
        return None


def _cosine_topk(qvec, matrix, ids, k):
    q = np.asarray(qvec, dtype=np.float32)
    m = np.asarray(matrix, dtype=np.float32)
    sims = m @ q / (np.linalg.norm(m, axis=1) * np.linalg.norm(q) + 1e-9)
    order = np.argsort(-sims)[:k]
    return [ids[i] for i in order]


class IndexService:
    _instance: Optional["IndexService"] = None

    def __init__(self):
        self._settings = get_settings()
        self._vault = Path(self._settings.vault_path)
        self._index_path = Path(self._settings.index_path)
        self.enabled = bool(self._settings.openai_api_key)
        self._client = None  # lazy OpenAI client
        self._index = self._load_index()

    @classmethod
    def instance(cls) -> "IndexService":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    # ── Index file ─────────────────────────────────────────────────────────────

    def _load_index(self) -> dict:
        if self._index_path.exists():
            try:
                return json.loads(self._index_path.read_text(encoding="utf-8"))
            except Exception as e:
                print(f"Index load failed, starting fresh: {e}")
        return {"model": self._settings.embedding_model, "notes": {}}

    def _persist(self) -> None:
        try:
            self._index_path.parent.mkdir(parents=True, exist_ok=True)
            tmp = self._index_path.with_suffix(".json.tmp")
            tmp.write_text(json.dumps(self._index), encoding="utf-8")
            os.replace(tmp, self._index_path)
        except Exception as e:
            print(f"Index persist failed: {e}")

    # ── Embedding ──────────────────────────────────────────────────────────────

    def _get_client(self):
        if self._client is None:
            from openai import OpenAI
            self._client = OpenAI(api_key=self._settings.openai_api_key)
        return self._client

    def _embed(self, texts: list[str]) -> list[list[float]]:
        """Embed texts via OpenAI. Returns [] on any failure (never raises)."""
        if not self.enabled or not texts:
            return []
        try:
            client = self._get_client()
            out: list[list[float]] = []
            for i in range(0, len(texts), 100):
                batch = texts[i:i + 100]
                resp = client.embeddings.create(
                    model=self._settings.embedding_model, input=batch
                )
                out.extend(d.embedding for d in resp.data)
            return out
        except Exception as e:
            print(f"Embedding API failed: {e}")
            return []

    @staticmethod
    def _hash(title: str, content: str, tags) -> str:
        if isinstance(tags, (list, tuple)):
            tags_str = ", ".join(str(t) for t in tags)
        else:
            tags_str = str(tags or "")
        payload = f"{title}\n{content}\n{tags_str}"
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()

    # ── Mutation hooks ─────────────────────────────────────────────────────────

    def index_note(self, meta: Optional[dict]) -> None:
        """Embed (or re-embed) a single note. No-op when disabled."""
        if not self.enabled or not meta:
            return
        note_id = meta.get("id")
        if not note_id:
            return
        file_path = meta.get("file_path", "")
        title = meta.get("title", "")
        content = meta.get("content", "")
        tags = meta.get("tags", "")
        h = self._hash(title, content, tags)

        existing = self._index["notes"].get(note_id)
        if existing and existing.get("content_hash") == h:
            if existing.get("file_path") != file_path:
                existing["file_path"] = file_path
                self._persist()
            return

        vectors = self._embed([f"{title}\n{content}"])
        if not vectors:
            return
        self._index["notes"][note_id] = {
            "file_path": file_path,
            "title": title,
            "content_hash": h,
            "vector": vectors[0],
        }
        self._persist()

    def remove_note(self, file_path: str) -> None:
        """Drop any index entry matching file_path. No-op when disabled."""
        if not self.enabled:
            return
        to_drop = [
            nid for nid, e in self._index["notes"].items()
            if e.get("file_path") == file_path
        ]
        if to_drop:
            for nid in to_drop:
                del self._index["notes"][nid]
            self._persist()

    def reconcile(self, notes: list[dict]) -> None:
        """Sync the index against the full note set: embed new/changed notes
        in one batch, drop entries for notes that no longer exist."""
        if not self.enabled:
            return

        current_ids: set[str] = set()
        pending: list[tuple[str, dict, str]] = []  # (id, meta, hash)

        for meta in notes:
            note_id = meta.get("id")
            if not note_id:
                continue
            current_ids.add(note_id)
            file_path = meta.get("file_path", "")
            title = meta.get("title", "")
            content = meta.get("content", "")
            h = self._hash(title, content, meta.get("tags", ""))
            existing = self._index["notes"].get(note_id)
            if existing and existing.get("content_hash") == h:
                if existing.get("file_path") != file_path:
                    existing["file_path"] = file_path
                continue
            pending.append((note_id, meta, h))

        if pending:
            texts = [f"{m.get('title', '')}\n{m.get('content', '')}" for _, m, _ in pending]
            vectors = self._embed(texts)
            if vectors and len(vectors) == len(pending):
                for (note_id, meta, h), vec in zip(pending, vectors):
                    self._index["notes"][note_id] = {
                        "file_path": meta.get("file_path", ""),
                        "title": meta.get("title", ""),
                        "content_hash": h,
                        "vector": vec,
                    }

        # Drop entries for deleted notes
        for nid in [n for n in self._index["notes"] if n not in current_ids]:
            del self._index["notes"][nid]

        self._persist()

    # ── Search ─────────────────────────────────────────────────────────────────

    def semantic_search(self, query: str, limit: int) -> list[str]:
        """Return up to `limit` file_paths ranked by cosine similarity."""
        if not self.enabled or not self._index["notes"]:
            return []
        qvecs = self._embed([query])
        if not qvecs:
            return []
        ids = list(self._index["notes"].keys())
        matrix = [self._index["notes"][nid]["vector"] for nid in ids]
        top_ids = _cosine_topk(qvecs[0], matrix, ids, limit)
        return [self._index["notes"][nid]["file_path"] for nid in top_ids]

    def hybrid_search(self, query: str, keyword_results: list[dict],
                      limit: int) -> list[dict]:
        """Combine semantic ranking with the keyword result set.

        Falls back to keyword_results[:limit] when the index is disabled.
        """
        if not self.enabled:
            return keyword_results[:limit]

        sem_paths = self.semantic_search(query, limit)
        kw_by_path = {r.get("file_path"): r for r in keyword_results}

        scores: dict[str, float] = {}
        n = max(len(sem_paths), 1)
        for idx, path in enumerate(sem_paths):
            scores[path] = scores.get(path, 0.0) + (1.0 - idx / n)
        for path in kw_by_path:
            scores[path] = scores.get(path, 0.0) + 0.5

        ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)[:limit]
        results: list[dict] = []
        for path, _score in ranked:
            if path in kw_by_path:
                results.append(kw_by_path[path])
            else:
                note = _parse_note(self._vault / path, self._vault)
                if note:
                    results.append(note)
        return results
