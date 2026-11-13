from datetime import datetime, timedelta, timezone

from config import Settings, get_settings
from services.push_service import PushService
from services.reminder_service import ReminderService
from services.user_service import UserService
from services.vault_service import VaultService


def test_due_reminders_retry_only_failed_destination(temp_vault, monkeypatch):
    monkeypatch.setattr(Settings, "smtp_host", "test.invalid")
    monkeypatch.setattr(Settings, "smtp_from", "reminder@test.invalid")
    get_settings.cache_clear()
    monkeypatch.setattr(PushService, "enabled", lambda: True)

    user_id = UserService.create("owner@example.com", "long-test-password")
    ReminderService.set_email(user_id, True)
    PushService.save_subscription(user_id, {
        "endpoint": "https://fcm.googleapis.com/device",
        "keys": {},
    })
    due = datetime.now(timezone.utc) + timedelta(minutes=1)
    vault = VaultService.for_user(user_id).vault_path
    vault.mkdir(parents=True)
    (vault / "note.md").write_text(
        "---\nid: note\ntitle: Test\nthought_type: reminder\n"
        f"remind_at: {due.isoformat()}\n---\n",
        encoding="utf-8",
    )
    emails = []
    pushes = []
    monkeypatch.setattr(ReminderService, "send_email", lambda *args: emails.append(args))

    def send_push(*args, endpoint):
        pushes.append(endpoint)
        return int(len(pushes) > 1)

    monkeypatch.setattr(PushService, "send_to_user", send_push)

    assert ReminderService.send_due(now=due - timedelta(seconds=1)) == 0
    assert ReminderService.send_due(now=due) == 1
    assert ReminderService.send_due(now=due + timedelta(minutes=1)) == 0
    assert ReminderService.send_due(now=due + timedelta(minutes=6)) == 1
    assert ReminderService.send_due(now=due + timedelta(minutes=12)) == 0
    assert emails == [("owner@example.com", "Test")]
    assert pushes == ["https://fcm.googleapis.com/device"] * 2
