"""
Environment-based configuration.
All secrets come from environment variables — never hardcoded.
"""
import os
from functools import lru_cache
from pathlib import Path


class Settings:
    # JWT
    jwt_secret: str = os.environ.get("JWT_SECRET", "change-me-in-production")
    jwt_algorithm: str = "HS256"

    # GitHub vault
    github_token: str = os.environ.get("GITHUB_TOKEN", "")
    github_repo: str = os.environ.get("GITHUB_REPO", "")  # e.g. "username/second-brain"
    vault_path: str = os.environ.get("VAULT_PATH", "/tmp/vault")

    # Claude API
    anthropic_api_key: str = os.environ.get("ANTHROPIC_API_KEY", "")
    claude_model: str = os.environ.get("CLAUDE_MODEL", "claude-sonnet-4-6")

    # Rate limiting
    rate_limit_per_minute: int = int(os.environ.get("RATE_LIMIT", "60"))

    # Semantic search (embedding index)
    openai_api_key: str = os.environ.get("OPENAI_API_KEY", "")
    embedding_model: str = os.environ.get("EMBEDDING_MODEL", "text-embedding-3-small")
    # Index file: sibling of the vault dir, kept out of the Git vault.
    index_path: str = os.environ.get(
        "INDEX_PATH",
        str(Path(os.environ.get("VAULT_PATH", "/tmp/vault")).parent / "embedding_index.json"),
    )

    # Persistent data root — auth.db, per-user vaults, per-user indexes
    # all live under this directory on the persistent volume.
    data_root: str = os.environ.get(
        "DATA_ROOT",
        str(Path(os.environ.get("VAULT_PATH", "/tmp/vault")).parent),
    )

    # Bootstrap: when the users table is empty AND both vars are set,
    # the lifespan handler creates this user on first boot and migrates
    # the legacy /data/vault to /data/users/<uid>/vault.
    bootstrap_email: str = os.environ.get("BOOTSTRAP_EMAIL", "")
    bootstrap_password: str = os.environ.get("BOOTSTRAP_PASSWORD", "")

    # Whether POST /auth/signup is open. Default: closed (single-user phase).
    signup_enabled: bool = os.environ.get("SIGNUP_ENABLED", "false").lower() in ("1", "true", "yes")

    # JWT lifetime — 30 days, rolling (refresh = re-login for now).
    jwt_ttl_days: int = int(os.environ.get("JWT_TTL_DAYS", "30"))


@lru_cache
def get_settings() -> Settings:
    return Settings()
