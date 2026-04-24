"""
VaultService: manages the local Git clone of the vault.
All file I/O is sandboxed inside vault_path — no path traversal possible.
"""
import os
import re
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional

import git

from config import get_settings


class VaultService:
    _instance: Optional["VaultService"] = None

    def __init__(self):
        self._settings = get_settings()
        self._vault = Path(self._settings.vault_path)

    @classmethod
    def instance(cls) -> "VaultService":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    # ── Setup ─────────────────────────────────────────────────────────────────

    async def ensure_vault(self) -> None:
        """Clone vault on first boot, pull on subsequent boots."""
        if not self._settings.github_repo:
            self._vault.mkdir(parents=True, exist_ok=True)
            (self._vault / "00-Inbox").mkdir(exist_ok=True)
            return

        repo_url = f"https://{self._settings.github_token}@github.com/{self._settings.github_repo}.git"

        if not (self._vault / ".git").exists():
            self._vault.mkdir(parents=True, exist_ok=True)
            git.Repo.clone_from(repo_url, self._vault)
        else:
            repo = git.Repo(self._vault)
            repo.remotes.origin.pull()

    # ── Write ──────────────────────────────────────────────────────────────────

    def write_note(self, note_id: str, title: str, content: str,
                   tags: list[str], para: str = "00-Inbox",
                   hall: str = "unclassified",
                   wing: Optional[str] = None,
                   thought_type: str = "standard",
                   remind_at: Optional[str] = None) -> str:
        """Write a markdown note with YAML frontmatter to the vault. Returns file path."""
        safe_title = re.sub(r"[^\w\s-]", "", title).strip()[:50]
        filename = f"{safe_title or note_id}.md"
        folder = self._safe_path(para)
        folder.mkdir(parents=True, exist_ok=True)
        filepath = folder / filename

        now = datetime.utcnow().isoformat()
        tag_list = ", ".join(f'"{t}"' for t in tags)
        frontmatter = (
            f"---\n"
            f"id: {note_id}\n"
            f"title: {title}\n"
            f"tags: [{tag_list}]\n"
            f"created: {now}\n"
            f"modified: {now}\n"
            f"source: capture\n"
            f"status: inbox\n"
            f"para: {para}\n"
            f"hall: {hall}\n"
        )
        if wing:
            frontmatter += f"wing: {wing}\n"
        frontmatter += f"thought_type: {thought_type}\n"
        if remind_at:
            frontmatter += f"remind_at: {remind_at}\n"
        frontmatter += f"---\n\n"
        filepath.write_text(frontmatter + content, encoding="utf-8")
        return str(filepath.relative_to(self._vault))

    def update_note(
        self,
        file_path: str,
        *,
        title: Optional[str] = None,
        content: Optional[str] = None,
        tags: Optional[list[str]] = None,
        status: Optional[str] = None,
        para: Optional[str] = None,
        hall: Optional[str] = None,
        wing: Optional[str] = None,
        thought_type: Optional[str] = None,
        remind_at: Optional[str] = None,
    ) -> str:
        """Update an existing note in-place. Moves file if `para` changes.

        Returns the (possibly new) relative file path. Filename stays stable
        across edits — users who want a different filename should delete+recreate.
        """
        src = self._safe_path(file_path)
        if not src.exists():
            raise FileNotFoundError(f"Note not found: {file_path}")

        existing = src.read_text(encoding="utf-8")
        # Split frontmatter from body
        if not existing.startswith("---"):
            raise ValueError(f"Note has no frontmatter: {file_path}")
        end = existing.index("---", 3)
        fm_block = existing[3:end]
        body = existing[end + 3:].lstrip("\n")

        # Parse existing frontmatter into dict (order-preserving via list)
        fm_lines: list[tuple[str, str]] = []
        for line in fm_block.splitlines():
            if ":" in line:
                k, _, v = line.partition(":")
                fm_lines.append((k.strip(), v.strip()))

        # Apply updates
        now = datetime.utcnow().isoformat()
        updates: dict[str, str] = {"modified": now}
        if title is not None:
            updates["title"] = title
        if tags is not None:
            updates["tags"] = "[" + ", ".join(f'"{t}"' for t in tags) + "]"
        if status is not None:
            updates["status"] = status
        if para is not None:
            updates["para"] = para
        if hall is not None:
            updates["hall"] = hall
        if wing is not None:
            # Normalize: lowercase kebab-case
            updates["wing"] = re.sub(r"[^a-z0-9]+", "-", wing.lower()).strip("-")
        if thought_type is not None:
            updates["thought_type"] = thought_type
        if remind_at is not None:
            updates["remind_at"] = remind_at

        merged: list[tuple[str, str]] = []
        seen: set[str] = set()
        for k, v in fm_lines:
            if k in updates:
                merged.append((k, updates[k]))
                seen.add(k)
            else:
                merged.append((k, v))
        # Append any new keys that weren't present
        for k, v in updates.items():
            if k not in seen:
                merged.append((k, v))

        new_body = content if content is not None else body
        new_fm = "---\n" + "\n".join(f"{k}: {v}" for k, v in merged) + "\n---\n\n"
        new_text = new_fm + new_body

        # If para changed, move file to new folder
        if para is not None:
            dest_folder = self._safe_path(para)
            dest_folder.mkdir(parents=True, exist_ok=True)
            dest = dest_folder / src.name
            if dest != src:
                src.unlink()
                dest.write_text(new_text, encoding="utf-8")
                self._git_commit(f"update: {src.name} → {para}")
                return str(dest.relative_to(self._vault))

        src.write_text(new_text, encoding="utf-8")
        self._git_commit(f"update: {src.name}")
        return str(src.relative_to(self._vault))

    def get_wings(self) -> list[dict]:
        """Return distinct wings with note counts and display names."""
        from collections import Counter
        counts: Counter = Counter()
        for f in self._vault.rglob("*.md"):
            meta = self._parse_frontmatter(f)
            if meta and meta.get("wing"):
                counts[meta["wing"]] += 1
        return [
            {
                "wing": wing,
                "display": wing.replace("-", " ").title(),
                "count": count,
            }
            for wing, count in sorted(counts.items())
        ]

    def rename_wing(self, old_wing: str, new_wing: str) -> int:
        """Rename all notes with old_wing to new_wing. Returns count updated."""
        new_normalized = re.sub(r"[^a-z0-9]+", "-", new_wing.lower()).strip("-")
        updated = 0
        for f in self._vault.rglob("*.md"):
            meta = self._parse_frontmatter(f)
            if meta and meta.get("wing") == old_wing:
                content = f.read_text(encoding="utf-8")
                content = re.sub(r"^wing: .+$", f"wing: {new_normalized}", content, flags=re.MULTILINE)
                content = re.sub(r"^modified: .+$", f"modified: {datetime.utcnow().isoformat()}", content, flags=re.MULTILINE)
                f.write_text(content, encoding="utf-8")
                updated += 1
        if updated:
            self._git_commit(f"rename-wing: {old_wing} → {new_normalized}")
        return updated

    def delete_note(self, file_path: str) -> None:
        """Permanently delete a note from the vault."""
        src = self._safe_path(file_path)
        if not src.exists():
            raise FileNotFoundError(f"Note not found: {file_path}")
        src.unlink()
        self._git_commit(f"delete: {src.name}")

    def move_note(self, file_path: str, new_para: str, new_status: str) -> str:
        """Move a note to a different PARA folder."""
        src = self._safe_path(file_path)
        if not src.exists():
            raise FileNotFoundError(f"Note not found: {file_path}")

        dest_folder = self._safe_path(new_para)
        dest_folder.mkdir(parents=True, exist_ok=True)
        dest = dest_folder / src.name

        content = src.read_text(encoding="utf-8")
        # Update frontmatter fields
        content = re.sub(r"^status: .+$", f"status: {new_status}", content, flags=re.MULTILINE)
        content = re.sub(r"^para: .+$", f"para: {new_para}", content, flags=re.MULTILINE)
        content = re.sub(r"^modified: .+$", f"modified: {datetime.utcnow().isoformat()}", content, flags=re.MULTILINE)

        src.unlink()
        dest.write_text(content, encoding="utf-8")
        self._git_commit(f"move: {src.name} → {new_para}")
        return str(dest.relative_to(self._vault))

    # ── Read ───────────────────────────────────────────────────────────────────

    def get_inbox_notes(self) -> list[dict]:
        """Return all notes in 00-Inbox as dicts."""
        inbox = self._safe_path("00-Inbox")
        if not inbox.exists():
            return []
        notes = []
        for f in sorted(inbox.glob("*.md"), key=lambda x: x.stat().st_mtime, reverse=True):
            meta = self._parse_frontmatter(f)
            if meta:
                notes.append(meta)
        return notes

    def search(self, query: str, limit: int = 20) -> list[dict]:
        """Full-text search across all markdown files in the vault."""
        lower = query.lower()
        results = []
        for f in self._vault.rglob("*.md"):
            if ".git" in f.parts:
                continue
            try:
                text = f.read_text(encoding="utf-8")
                if lower in text.lower():
                    meta = self._parse_frontmatter(f)
                    if meta:
                        excerpt = self._excerpt(text, lower)
                        results.append({**meta, "excerpt": excerpt})
            except Exception:
                pass
        return results[:limit]

    def get_all_notes(self, limit: int = 200) -> list[dict]:
        """Return all notes from every PARA folder as dicts."""
        notes = []
        for f in sorted(self._vault.rglob("*.md"), key=lambda x: x.stat().st_mtime, reverse=True):
            if ".git" in f.parts:
                continue
            meta = self._parse_frontmatter(f)
            if meta:
                notes.append(meta)
            if len(notes) >= limit:
                break
        return notes

    def get_status(self) -> dict:
        total = sum(1 for _ in self._vault.rglob("*.md") if ".git" not in _.parts)
        inbox_count = len(list((self._vault / "00-Inbox").glob("*.md"))) if (self._vault / "00-Inbox").exists() else 0
        return {
            "total_notes": total,
            "inbox_count": inbox_count,
            "last_sync": datetime.utcnow().isoformat(),
        }

    # ── Git ────────────────────────────────────────────────────────────────────

    def git_commit_and_push(self, message: str) -> None:
        if not (self._vault / ".git").exists():
            return
        repo = git.Repo(self._vault)
        repo.git.add(A=True)
        if repo.is_dirty(index=True, working_tree=False):
            repo.index.commit(message)
            repo.remotes.origin.push()

    def _git_commit(self, message: str) -> None:
        self.git_commit_and_push(message)

    # ── Helpers ────────────────────────────────────────────────────────────────

    def _safe_path(self, rel: str) -> Path:
        """Resolve path inside vault, reject traversal attempts."""
        resolved = (self._vault / rel).resolve()
        if not str(resolved).startswith(str(self._vault.resolve())):
            raise ValueError(f"Path traversal rejected: {rel}")
        return resolved

    def _parse_frontmatter(self, path: Path) -> Optional[dict]:
        try:
            text = path.read_text(encoding="utf-8")
            if not text.startswith("---"):
                return None
            end = text.index("---", 3)
            fm = text[3:end].strip()
            result = {"file_path": str(path.relative_to(self._vault)), "content": text[end + 3:].strip()}
            for line in fm.splitlines():
                if ":" in line:
                    k, _, v = line.partition(":")
                    result[k.strip()] = v.strip()
            return result
        except Exception:
            return None

    def _excerpt(self, text: str, query: str, radius: int = 80) -> str:
        lower = text.lower()
        idx = lower.find(query)
        if idx == -1:
            return text[:radius * 2]
        start = max(0, idx - radius)
        end = min(len(text), idx + len(query) + radius)
        return ("..." if start > 0 else "") + text[start:end] + ("..." if end < len(text) else "")
