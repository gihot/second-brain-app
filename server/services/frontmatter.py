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
