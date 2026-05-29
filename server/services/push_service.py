"""
PushService — Web-Push-Subscriptions + Versand (Notifications-Phase 1).

Speichert pro User die Push-Subscriptions (Browser-Endpoint + Keys) und
sendet Notifications via pywebpush/VAPID. Die eigentliche Reminder-
Auswahl (welche Notiz ist fällig) kommt in Phase 2 — hier nur die
Zustell-Mechanik + ein Test-Versand.

Graceful degradation: ohne VAPID-Keys (ENV nicht gesetzt) ist `enabled`
False und alle Sends sind no-ops. Tabelle lebt in derselben auth.db.
Stdlib sqlite3 + pywebpush.
"""
from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from config import get_settings


class PushService:
    _db_path: Optional[Path] = None

    @classmethod
    def init(cls, db_path: Path) -> None:
        cls._db_path = db_path
        db_path.parent.mkdir(parents=True, exist_ok=True)
        with cls._conn() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS push_subscriptions (
                    user_id    TEXT NOT NULL,
                    endpoint   TEXT NOT NULL,
                    keys_json  TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    PRIMARY KEY (user_id, endpoint)
                )
                """
            )

    @classmethod
    def _conn(cls) -> sqlite3.Connection:
        if cls._db_path is None:
            raise RuntimeError("PushService.init() was not called")
        conn = sqlite3.connect(cls._db_path)
        conn.row_factory = sqlite3.Row
        return conn

    @classmethod
    def enabled(cls) -> bool:
        """True nur wenn ein VAPID-Keypair konfiguriert ist."""
        s = get_settings()
        return bool(s.vapid_private_key and s.vapid_public_key)

    @classmethod
    def public_key(cls) -> str:
        return get_settings().vapid_public_key

    # ── Subscriptions ─────────────────────────────────────────────────────────

    @classmethod
    def save_subscription(cls, user_id: str, subscription: dict) -> None:
        """Upsert einer Browser-Subscription. `subscription` ist das
        PushSubscription-JSON des Clients: {endpoint, keys: {p256dh, auth}}.
        Keyed auf (user_id, endpoint) → mehrere Geräte pro User möglich,
        dasselbe Gerät überschreibt sich selbst."""
        endpoint = subscription.get("endpoint")
        keys = subscription.get("keys")
        if not endpoint or not isinstance(keys, dict):
            raise ValueError("invalid subscription payload")
        now = datetime.now(timezone.utc).isoformat()
        with cls._conn() as conn:
            conn.execute(
                """
                INSERT INTO push_subscriptions (user_id, endpoint, keys_json, created_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(user_id, endpoint) DO UPDATE SET
                    keys_json = excluded.keys_json
                """,
                (user_id, endpoint, json.dumps(keys), now),
            )

    @classmethod
    def remove_subscription(cls, user_id: str, endpoint: str) -> None:
        with cls._conn() as conn:
            conn.execute(
                "DELETE FROM push_subscriptions WHERE user_id = ? AND endpoint = ?",
                (user_id, endpoint),
            )

    @classmethod
    def get_subscriptions(cls, user_id: str) -> list[dict]:
        with cls._conn() as conn:
            rows = conn.execute(
                "SELECT endpoint, keys_json FROM push_subscriptions WHERE user_id = ?",
                (user_id,),
            ).fetchall()
        return [
            {"endpoint": r["endpoint"], "keys": json.loads(r["keys_json"])}
            for r in rows
        ]

    @classmethod
    def delete_user_data(cls, user_id: str) -> int:
        """Wave-4.2-Hard-Delete-Hook."""
        if cls._db_path is None:
            return 0
        with cls._conn() as conn:
            cur = conn.execute(
                "DELETE FROM push_subscriptions WHERE user_id = ?", (user_id,)
            )
            return cur.rowcount

    # ── Versand ───────────────────────────────────────────────────────────────

    @classmethod
    def send_to_user(cls, user_id: str, title: str, body: str,
                     url: str = "/") -> int:
        """Sendet eine Notification an alle Subscriptions des Users.
        Returns die Anzahl erfolgreicher Sends. Abgelaufene Subscriptions
        (404/410) werden automatisch gelöscht. No-op wenn nicht enabled."""
        if not cls.enabled():
            return 0

        from pywebpush import WebPushException, webpush
        from py_vapid import Vapid

        s = get_settings()
        vapid = Vapid.from_pem(s.vapid_private_key.encode("utf-8"))
        payload = json.dumps({"title": title, "body": body, "url": url})

        sent = 0
        for sub in cls.get_subscriptions(user_id):
            try:
                webpush(
                    subscription_info=sub,
                    data=payload,
                    vapid_private_key=vapid,
                    vapid_claims={"sub": s.vapid_subject},
                )
                sent += 1
            except WebPushException as e:
                # 404/410 = Subscription tot (Browser hat sie verworfen) →
                # aufräumen. Andere Fehler: loggen, nicht crashen.
                status = getattr(e.response, "status_code", None)
                if status in (404, 410):
                    cls.remove_subscription(user_id, sub["endpoint"])
                else:
                    print(f"webpush failed for {user_id}: {e}")
            except Exception as e:
                print(f"webpush unexpected error for {user_id}: {e}")
        return sent
