"""
UserService — minimal SQLite-backed user store with bcrypt password hashing.

Single tiny table (`users`), stdlib `sqlite3` only — no ORM, no
SQLAlchemy. Thread-safety: each operation opens its own connection
(SQLite handles concurrency at the file level; FastAPI runs request
handlers concurrently in a threadpool via `asyncio.to_thread`).
"""
from __future__ import annotations

import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import bcrypt


# Pre-computed bcrypt hash used as a timing-side-channel guard when an
# email is unknown. Generated once at import (gensalt randomizes per
# server start — value is never compared for truth, only for timing).
_DUMMY_HASH = bcrypt.hashpw(b"dummy", bcrypt.gensalt())


class UserService:
    _db_path: Optional[Path] = None

    # ── Lifecycle ─────────────────────────────────────────────────────────────

    @classmethod
    def init(cls, db_path: Path) -> None:
        """Create the table if needed. Called once from the FastAPI lifespan."""
        cls._db_path = db_path
        db_path.parent.mkdir(parents=True, exist_ok=True)
        with cls._conn() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id            TEXT PRIMARY KEY,
                    email         TEXT UNIQUE NOT NULL,
                    password_hash TEXT NOT NULL,
                    created_at    TEXT NOT NULL
                )
                """
            )

    @classmethod
    def _conn(cls) -> sqlite3.Connection:
        if cls._db_path is None:
            raise RuntimeError("UserService.init() was not called")
        conn = sqlite3.connect(cls._db_path)
        conn.row_factory = sqlite3.Row
        return conn

    # ── Queries ───────────────────────────────────────────────────────────────

    @classmethod
    def count(cls) -> int:
        with cls._conn() as conn:
            row = conn.execute("SELECT COUNT(*) AS n FROM users").fetchone()
            return int(row["n"])

    @classmethod
    def create(cls, email: str, password: str) -> str:
        """Create a user. Returns the new user_id. Raises ValueError on
        duplicate email or empty inputs."""
        email = (email or "").strip().lower()
        if not email or not password:
            raise ValueError("email and password are required")
        user_id = str(uuid.uuid4())
        pw_hash = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        created_at = datetime.now(timezone.utc).isoformat()
        try:
            with cls._conn() as conn:
                conn.execute(
                    "INSERT INTO users (id, email, password_hash, created_at) VALUES (?, ?, ?, ?)",
                    (user_id, email, pw_hash, created_at),
                )
        except sqlite3.IntegrityError as e:
            raise ValueError("email already registered") from e
        return user_id

    @classmethod
    def verify(cls, email: str, password: str) -> Optional[dict]:
        """Return the user dict on success, None on bad credentials.

        Note on timing: when the email is unknown we still run a bcrypt
        check against [_DUMMY_HASH] so the response latency is
        indistinguishable from a real "bad password". `bcrypt.checkpw` is
        synchronous; this method is currently only invoked via
        `asyncio.to_thread(UserService.verify, ...)` from
        `routers/auth.py`, so the dummy call lives in the same threadpool
        worker as the real one and does NOT block the event loop. If you
        ever invoke `verify()` directly from async code, both paths need
        to go through `run_in_executor` to keep the symmetry.
        """
        email = (email or "").strip().lower()
        if not email or not password:
            # Match real-path cost so empty inputs aren't detectably faster.
            bcrypt.checkpw(b"dummy", _DUMMY_HASH)
            return None
        with cls._conn() as conn:
            row = conn.execute(
                "SELECT id, email, password_hash, created_at FROM users WHERE email = ?",
                (email,),
            ).fetchone()
        if row is None:
            # Unknown user — dummy compare to equalize latency vs. real check.
            bcrypt.checkpw(password.encode("utf-8"), _DUMMY_HASH)
            return None
        if not bcrypt.checkpw(password.encode("utf-8"), row["password_hash"].encode("utf-8")):
            return None
        return {"id": row["id"], "email": row["email"], "created_at": row["created_at"]}

    @classmethod
    def get(cls, user_id: str) -> Optional[dict]:
        with cls._conn() as conn:
            row = conn.execute(
                "SELECT id, email, created_at FROM users WHERE id = ?",
                (user_id,),
            ).fetchone()
        if row is None:
            return None
        return {"id": row["id"], "email": row["email"], "created_at": row["created_at"]}
