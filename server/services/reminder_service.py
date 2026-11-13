"""Deliver due Markdown reminders through each enabled destination."""
import logging
import smtplib
import sqlite3
import ssl
from contextlib import closing
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from pathlib import Path

from config import get_settings
from services.push_service import PushService, is_browser_push_endpoint
from services.vault_service import VaultService


logger = logging.getLogger(__name__)
RETRY_DELAY = timedelta(minutes=5)


class ReminderService:
    _db_path: Path | None = None

    @classmethod
    def _connect(cls):
        return closing(sqlite3.connect(cls._db_path, timeout=10))

    @classmethod
    def init(cls, db_path: Path) -> None:
        cls._db_path = db_path
        with cls._connect() as conn:
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS reminder_email_settings (
                    user_id TEXT PRIMARY KEY,
                    enabled_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS reminder_deliveries (
                    user_id TEXT NOT NULL,
                    note_id TEXT NOT NULL,
                    due_at TEXT NOT NULL,
                    destination TEXT NOT NULL,
                    attempt_after TEXT NOT NULL,
                    sent_at TEXT,
                    PRIMARY KEY (user_id, note_id, due_at, destination)
                );
            """)

    @staticmethod
    def email_available() -> bool:
        settings = get_settings()
        return bool(settings.smtp_host and settings.smtp_from)

    @classmethod
    def email_enabled(cls, user_id: str) -> bool:
        with cls._connect() as conn:
            return conn.execute(
                "SELECT 1 FROM reminder_email_settings WHERE user_id = ?", (user_id,)
            ).fetchone() is not None

    @classmethod
    def set_email(cls, user_id: str, enabled: bool) -> None:
        with cls._connect() as conn, conn:
            if enabled:
                conn.execute(
                    "INSERT OR IGNORE INTO reminder_email_settings VALUES (?, ?)",
                    (user_id, datetime.now(timezone.utc).isoformat()),
                )
            else:
                conn.execute(
                    "DELETE FROM reminder_email_settings WHERE user_id = ?", (user_id,)
                )

    @classmethod
    def delete_user_data(cls, user_id: str) -> None:
        with cls._connect() as conn, conn:
            conn.execute("DELETE FROM reminder_email_settings WHERE user_id = ?", (user_id,))
            conn.execute("DELETE FROM reminder_deliveries WHERE user_id = ?", (user_id,))

    @staticmethod
    def send_email(recipient: str, body: str) -> None:
        settings = get_settings()
        message = EmailMessage()
        message["From"] = settings.smtp_from
        message["To"] = recipient
        message["Subject"] = "Second Brain · Erinnerung"
        message.set_content(body)
        tls = ssl.create_default_context()
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as smtp:
            smtp.starttls(context=tls)
            if settings.smtp_user:
                smtp.login(settings.smtp_user, settings.smtp_password)
            smtp.send_message(message)

    @classmethod
    def _destinations(cls) -> dict[str, list[tuple[str, str, datetime]]]:
        with cls._connect() as conn:
            email = conn.execute("""
                SELECT users.id, users.email, reminder_email_settings.enabled_at
                FROM users JOIN reminder_email_settings ON users.id = reminder_email_settings.user_id
                WHERE users.pending_deletion_at IS NULL
            """).fetchall() if cls.email_available() else []
            push = conn.execute("""
                SELECT users.id, push_subscriptions.endpoint, push_subscriptions.created_at
                FROM users JOIN push_subscriptions ON users.id = push_subscriptions.user_id
                WHERE users.pending_deletion_at IS NULL
            """).fetchall() if PushService.enabled() else []

        result = {}
        for channel, rows in (("email", email), ("push", push)):
            for user_id, address, enabled_at in rows:
                if channel == "push" and not is_browser_push_endpoint(address):
                    continue
                enabled = _utc_date(enabled_at)
                if enabled is not None:
                    result.setdefault(user_id, []).append((channel, address, enabled))
        return result

    @classmethod
    def _claim(cls, key: tuple[str, str, str, str], now: datetime) -> bool:
        with cls._connect() as conn, conn:
            result = conn.execute("""
                INSERT INTO reminder_deliveries
                    (user_id, note_id, due_at, destination, attempt_after)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(user_id, note_id, due_at, destination) DO UPDATE SET
                    attempt_after = excluded.attempt_after
                WHERE sent_at IS NULL AND attempt_after <= ?
            """, (*key, (now + RETRY_DELAY).isoformat(), now.isoformat()))
            return result.rowcount == 1

    @classmethod
    def send_due(cls, now: datetime | None = None) -> int:
        now = now or datetime.now(timezone.utc)
        count = 0
        for user_id, destinations in cls._destinations().items():
            vault = VaultService.for_user(user_id)
            for note in vault.iter_reminders():
                due = _utc_date(note.get("remind_at"))
                if due is None or due > now:
                    continue
                note_id = note["id"]
                for channel, address, enabled in destinations:
                    if due < enabled:
                        continue
                    key = (user_id, note_id, due.isoformat(), f"{channel}:{address}")
                    if not cls._claim(key, now):
                        continue
                    try:
                        title = note.get("title") or "Eine Erinnerung ist fällig"
                        if channel == "email":
                            cls.send_email(address, title)
                        elif not PushService.send_to_user(
                            user_id, "Second Brain · Erinnerung", title, endpoint=address
                        ):
                            continue
                    except Exception:
                        logger.exception("Reminder delivery failed via %s", channel)
                        continue
                    with cls._connect() as conn, conn:
                        conn.execute("""
                            UPDATE reminder_deliveries SET sent_at = ?
                            WHERE user_id = ? AND note_id = ? AND due_at = ? AND destination = ?
                        """, (datetime.now(timezone.utc).isoformat(), *key))
                    count += 1
        return count


def _utc_date(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        date = datetime.fromisoformat(value.strip("\"'"))
    except ValueError:
        return None
    if date.tzinfo is None:
        return None
    return date.astimezone(timezone.utc)
