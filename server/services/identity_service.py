"""IdentityService — reads/writes identity.md inside the user's vault."""
from pathlib import Path
from typing import Optional

from config import get_settings

_MAX_CHARS = 800


class IdentityService:
    """Per-user, lazily-cached. identity.md lives in the user's vault root."""

    _instances: dict[str, "IdentityService"] = {}

    def __init__(self, user_id: str):
        settings = get_settings()
        self._path = (
            Path(settings.data_root) / "users" / user_id / "vault" / "identity.md"
        )
        self._cached: Optional[str] = None

    @classmethod
    def for_user(cls, user_id: str) -> "IdentityService":
        inst = cls._instances.get(user_id)
        if inst is None:
            inst = cls(user_id)
            cls._instances[user_id] = inst
        return inst

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
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._path.write_text(truncated, encoding="utf-8")
        self._cached = truncated
