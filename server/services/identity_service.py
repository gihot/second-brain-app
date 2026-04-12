"""IdentityService — reads/writes identity.md in the vault root."""
from pathlib import Path
from typing import Optional

_MAX_CHARS = 800


class IdentityService:
    _instance: Optional["IdentityService"] = None
    _cached: Optional[str] = None

    def __init__(self, vault_root: Path):
        self._path = vault_root / "identity.md"

    @classmethod
    def init(cls, vault_root: Path) -> "IdentityService":
        cls._instance = cls(vault_root)
        return cls._instance

    @classmethod
    def instance(cls) -> "IdentityService":
        if cls._instance is None:
            raise RuntimeError("IdentityService not initialized")
        return cls._instance

    def get(self) -> str:
        if self._cached is not None:
            return self._cached
        if not self._path.exists():
            return ""
        text = self._path.read_text(encoding="utf-8").strip()
        self._cached = text
        return text

    def update(self, text: str) -> None:
        truncated = text.strip()[:_MAX_CHARS]
        self._path.write_text(truncated, encoding="utf-8")
        self._cached = truncated  # Invalidate cache with new value
