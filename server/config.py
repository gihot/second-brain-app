"""
Environment-based configuration.
All secrets come from environment variables — never hardcoded.
"""
import os
from functools import lru_cache


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


@lru_cache
def get_settings() -> Settings:
    return Settings()
