"""
InviteService — Einladungs-Codes für kontrolliertes Signup (Wave 4.3).

Konzept: der Signup-Endpoint bleibt geschlossen, **außer** der Client
schickt einen gültigen Einladungs-Code mit. Codes werden von
bestehenden Usern erzeugt („Freund einladen"-Tile in den Settings),
sind 14 Tage gültig und einmalig nutzbar.

Tabelle in derselben auth.db wie users + paused_pairs + resurfacings.
Stdlib sqlite3, kein ORM.
"""
from __future__ import annotations

import secrets
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional


# Max offene (= nicht eingelöste, nicht abgelaufene) Einladungen pro User.
# Bremst Spam-Generierung. 10 ist großzügig — wer mehr braucht, hat
# entweder eine sehr soziale Phase oder ein Problem.
_MAX_OPEN_INVITES = 10
_DEFAULT_TTL_DAYS = 14


class InviteService:
    _db_path: Optional[Path] = None

    @classmethod
    def init(cls, db_path: Path) -> None:
        cls._db_path = db_path
        db_path.parent.mkdir(parents=True, exist_ok=True)
        with cls._conn() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS invite_codes (
                    code        TEXT PRIMARY KEY,
                    created_by  TEXT NOT NULL,
                    created_at  TEXT NOT NULL,
                    expires_at  TEXT NOT NULL,
                    used_by     TEXT,
                    used_at     TEXT
                )
                """
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_invite_created_by "
                "ON invite_codes(created_by)"
            )

    @classmethod
    def _conn(cls) -> sqlite3.Connection:
        if cls._db_path is None:
            raise RuntimeError("InviteService.init() was not called")
        conn = sqlite3.connect(cls._db_path)
        conn.row_factory = sqlite3.Row
        return conn

    @classmethod
    def create(
        cls, created_by: str, ttl_days: int = _DEFAULT_TTL_DAYS
    ) -> tuple[Optional[str], Optional[str]]:
        """Erzeugt einen neuen Code. Returns (code, error).
        Wirft nicht — Limit-Überschreitung kommt als error-String zurück.
        """
        # Limit-Check: nur offene (nicht eingelöst, nicht abgelaufen).
        now_iso = datetime.now(timezone.utc).isoformat()
        with cls._conn() as conn:
            row = conn.execute(
                """
                SELECT COUNT(*) AS n FROM invite_codes
                WHERE created_by = ?
                  AND used_at IS NULL
                  AND expires_at > ?
                """,
                (created_by, now_iso),
            ).fetchone()
        if int(row["n"]) >= _MAX_OPEN_INVITES:
            return None, (
                f"Maximum {_MAX_OPEN_INVITES} offene Einladungen erreicht. "
                "Warte bis welche genutzt werden oder ablaufen."
            )

        # 9-Zeichen-Code aus URL-safen Base64-Zeichen. Genug Entropie
        # gegen Brute-Force (≈ 53 Bit), kurz genug zum Tippen am Telefon.
        code = secrets.token_urlsafe(7)[:9].upper()
        expires_at = (
            datetime.now(timezone.utc) + timedelta(days=ttl_days)
        ).isoformat()
        with cls._conn() as conn:
            conn.execute(
                """
                INSERT INTO invite_codes (code, created_by, created_at, expires_at)
                VALUES (?, ?, ?, ?)
                """,
                (code, created_by, now_iso, expires_at),
            )
        return code, None

    @classmethod
    def consume(cls, code: str, used_by: str) -> bool:
        """Prüft + markiert einen Code als eingelöst. Returns True wenn
        der Code gültig war und jetzt verbraucht ist. Atomar via
        UPDATE … WHERE used_at IS NULL, damit zwei parallele Signups
        nicht denselben Code beide einlösen können."""
        now_iso = datetime.now(timezone.utc).isoformat()
        normalized = (code or "").strip().upper()
        if not normalized:
            return False
        with cls._conn() as conn:
            cur = conn.execute(
                """
                UPDATE invite_codes
                SET used_by = ?, used_at = ?
                WHERE code = ?
                  AND used_at IS NULL
                  AND expires_at > ?
                """,
                (used_by, now_iso, normalized, now_iso),
            )
            return cur.rowcount > 0

    @classmethod
    def list_for_user(cls, created_by: str) -> list[dict]:
        """Alle Codes eines Users — gemischt offene + eingelöste +
        abgelaufene, damit das Settings-Tile auch Historie zeigen kann.
        Sortiert: offen zuerst, dann nach Datum absteigend."""
        now_iso = datetime.now(timezone.utc).isoformat()
        with cls._conn() as conn:
            rows = conn.execute(
                """
                SELECT code, created_at, expires_at, used_by, used_at,
                       CASE
                         WHEN used_at IS NOT NULL THEN 'used'
                         WHEN expires_at <= ? THEN 'expired'
                         ELSE 'open'
                       END AS state
                FROM invite_codes
                WHERE created_by = ?
                ORDER BY
                  CASE
                    WHEN used_at IS NULL AND expires_at > ? THEN 0
                    ELSE 1
                  END,
                  created_at DESC
                """,
                (now_iso, created_by, now_iso),
            ).fetchall()
        return [dict(r) for r in rows]

    @classmethod
    def delete_user_data(cls, user_id: str) -> int:
        """Wave 4.2 Hard-Delete-Hook: löscht alle Codes, die dieser
        User erzeugt hat. Codes die er **eingelöst** hat, lassen wir
        stehen (used_by ist nur historisch), löschen aber den
        Personenbezug raus."""
        if cls._db_path is None:
            return 0
        with cls._conn() as conn:
            cur = conn.execute(
                "DELETE FROM invite_codes WHERE created_by = ?",
                (user_id,),
            )
            conn.execute(
                "UPDATE invite_codes SET used_by = NULL WHERE used_by = ?",
                (user_id,),
            )
            return cur.rowcount
