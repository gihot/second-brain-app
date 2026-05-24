"""
PausedPairsService — small SQLite-backed store for "wisch weg"-feedback
on the daily connection card.

The user sees a single connection on the dashboard per day. If they
dismiss it, we don't want to bother them with the same pair for two
weeks. Storage is per-user, keyed by a stable hash of the two note IDs
sorted, so (A, B) and (B, A) are the same pair.

Lives in the same `auth.db` SQLite file as users — keeps the persistence
story trivial. Stdlib `sqlite3`, no ORM.
"""
from __future__ import annotations

import hashlib
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional


def _pair_key(note_a_id: str, note_b_id: str) -> str:
    a, b = sorted([note_a_id or "", note_b_id or ""])
    return hashlib.sha256(f"{a}|{b}".encode("utf-8")).hexdigest()


class PausedPairsService:
    _db_path: Optional[Path] = None

    @classmethod
    def init(cls, db_path: Path) -> None:
        cls._db_path = db_path
        db_path.parent.mkdir(parents=True, exist_ok=True)
        with cls._conn() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS paused_pairs (
                    user_id    TEXT NOT NULL,
                    pair_key   TEXT NOT NULL,
                    expires_at TEXT NOT NULL,
                    PRIMARY KEY (user_id, pair_key)
                )
                """
            )

    @classmethod
    def _conn(cls) -> sqlite3.Connection:
        if cls._db_path is None:
            raise RuntimeError("PausedPairsService.init() was not called")
        conn = sqlite3.connect(cls._db_path)
        conn.row_factory = sqlite3.Row
        return conn

    @classmethod
    def pause(cls, user_id: str, note_a_id: str, note_b_id: str,
              days: int = 14) -> None:
        """Mark a pair as paused for `days` (default 14). Upsert — if the
        pair was already paused, the expiry is extended."""
        expires = (datetime.now(timezone.utc) + timedelta(days=days)).isoformat()
        key = _pair_key(note_a_id, note_b_id)
        with cls._conn() as conn:
            conn.execute(
                """
                INSERT INTO paused_pairs (user_id, pair_key, expires_at)
                VALUES (?, ?, ?)
                ON CONFLICT(user_id, pair_key)
                  DO UPDATE SET expires_at = excluded.expires_at
                """,
                (user_id, key, expires),
            )

    @classmethod
    def is_paused(cls, user_id: str, note_a_id: str, note_b_id: str) -> bool:
        """True if this pair is currently within an active pause window."""
        key = _pair_key(note_a_id, note_b_id)
        now_iso = datetime.now(timezone.utc).isoformat()
        with cls._conn() as conn:
            row = conn.execute(
                "SELECT expires_at FROM paused_pairs WHERE user_id = ? AND pair_key = ?",
                (user_id, key),
            ).fetchone()
        if row is None:
            return False
        return row["expires_at"] > now_iso

    @classmethod
    def purge_expired(cls) -> int:
        """Delete rows whose pause has ended. Returns the number deleted.
        Cheap maintenance, can be called occasionally — not on every read."""
        now_iso = datetime.now(timezone.utc).isoformat()
        with cls._conn() as conn:
            cur = conn.execute(
                "DELETE FROM paused_pairs WHERE expires_at <= ?",
                (now_iso,),
            )
            return cur.rowcount
