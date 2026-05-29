"""
Free-standing YAML-frontmatter parser shared by VaultService and IndexService.

Lives in its own module so it can be imported by both without creating a
cycle (vault_service imports index_service, so index_service can't import
back). Imports nothing from the rest of the codebase.
"""
from pathlib import Path
from typing import Optional


def parse_frontmatter(path: Path, vault_root: Path) -> Optional[dict]:
    """Parse a vault markdown file into a frontmatter meta dict.

    Returns keys: `file_path` (relative to vault_root), `content`, plus every
    `key: value` pair from the YAML frontmatter block. Returns None for files
    without a leading `---` frontmatter or on any read error.
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


# Keys die parse_frontmatter zusätzlich erzeugt, aber NICHT Teil des
# YAML-Blocks sind — beim Serialisieren übersprungen.
_NON_FRONTMATTER_KEYS = {"file_path", "content"}


def serialize_frontmatter(meta: dict, body: str) -> str:
    """Inverse zu [parse_frontmatter]: baut den vollständigen Datei-Inhalt
    (`---\\n<frontmatter>\\n---\\n\\n<body>`) aus einem meta-Dict + Body.

    J6 (Plan v2): eine Round-trip-Quelle statt zweier Frontmatter-Parser
    (vault_service.update_note hatte einen eigenen inline). Die
    Schlüssel-Reihenfolge des Dicts bleibt erhalten (dict ist insertion-
    ordered) — wichtig damit Updates die Frontmatter-Struktur nicht
    umsortieren. `file_path`/`content` werden übersprungen.
    """
    lines = [
        f"{k}: {v}"
        for k, v in meta.items()
        if k not in _NON_FRONTMATTER_KEYS
    ]
    return "---\n" + "\n".join(lines) + "\n---\n\n" + body
