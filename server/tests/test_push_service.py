"""Notifications-Phase-1: Tests für PushService.

Subscription-CRUD + Versand-Logik (pywebpush gemockt). VAPID-Keys
werden per monkeypatch gesetzt — kein echtes Senden.
"""
import pytest

from services.push_service import PushService


def _sub(endpoint="https://push.example/abc"):
    return {"endpoint": endpoint, "keys": {"p256dh": "k1", "auth": "k2"}}


def test_disabled_without_vapid(temp_vault, monkeypatch):
    from config import Settings, get_settings
    monkeypatch.setattr(Settings, "vapid_private_key", "", raising=False)
    monkeypatch.setattr(Settings, "vapid_public_key", "", raising=False)
    get_settings.cache_clear()
    assert PushService.enabled() is False
    # send ist no-op
    PushService.save_subscription("u1", _sub())
    assert PushService.send_to_user("u1", "t", "b") == 0


def test_save_and_get_subscription(temp_vault):
    PushService.save_subscription("u1", _sub())
    subs = PushService.get_subscriptions("u1")
    assert len(subs) == 1
    assert subs[0]["endpoint"] == "https://push.example/abc"
    assert subs[0]["keys"]["auth"] == "k2"


def test_subscription_upsert_same_endpoint(temp_vault):
    PushService.save_subscription("u1", _sub())
    PushService.save_subscription("u1", {
        "endpoint": "https://push.example/abc",
        "keys": {"p256dh": "new", "auth": "new"},
    })
    subs = PushService.get_subscriptions("u1")
    assert len(subs) == 1  # kein Duplikat
    assert subs[0]["keys"]["p256dh"] == "new"


def test_multiple_devices_per_user(temp_vault):
    PushService.save_subscription("u1", _sub("https://push.example/dev1"))
    PushService.save_subscription("u1", _sub("https://push.example/dev2"))
    assert len(PushService.get_subscriptions("u1")) == 2


def test_invalid_subscription_raises(temp_vault):
    with pytest.raises(ValueError):
        PushService.save_subscription("u1", {"endpoint": "", "keys": None})


def test_remove_subscription(temp_vault):
    PushService.save_subscription("u1", _sub())
    PushService.remove_subscription("u1", "https://push.example/abc")
    assert PushService.get_subscriptions("u1") == []


def test_delete_user_data(temp_vault):
    PushService.save_subscription("u1", _sub("https://push.example/a"))
    PushService.save_subscription("u2", _sub("https://push.example/b"))
    n = PushService.delete_user_data("u1")
    assert n == 1
    assert PushService.get_subscriptions("u1") == []
    assert len(PushService.get_subscriptions("u2")) == 1


def test_send_to_user_calls_webpush(temp_vault, monkeypatch):
    """enabled + zwei Subscriptions → zwei webpush-Calls, sent=2."""
    from config import Settings, get_settings
    # Minimal-PEM nicht nötig — wir mocken webpush + Vapid.from_pem.
    monkeypatch.setattr(Settings, "vapid_private_key", "PEMSTUB", raising=False)
    monkeypatch.setattr(Settings, "vapid_public_key", "PUBSTUB", raising=False)
    get_settings.cache_clear()

    PushService.save_subscription("u1", _sub("https://push.example/a"))
    PushService.save_subscription("u1", _sub("https://push.example/b"))

    calls = []
    import pywebpush
    from py_vapid import Vapid
    monkeypatch.setattr(Vapid, "from_pem", staticmethod(lambda pem: object()))
    monkeypatch.setattr(
        pywebpush, "webpush",
        lambda **kw: calls.append(kw["subscription_info"]["endpoint"]),
    )

    sent = PushService.send_to_user("u1", "Titel", "Body", url="/x")
    assert sent == 2
    assert set(calls) == {"https://push.example/a", "https://push.example/b"}


def test_send_removes_dead_subscription_on_410(temp_vault, monkeypatch):
    from config import Settings, get_settings
    monkeypatch.setattr(Settings, "vapid_private_key", "PEMSTUB", raising=False)
    monkeypatch.setattr(Settings, "vapid_public_key", "PUBSTUB", raising=False)
    get_settings.cache_clear()

    PushService.save_subscription("u1", _sub("https://push.example/dead"))

    import pywebpush
    from py_vapid import Vapid
    monkeypatch.setattr(Vapid, "from_pem", staticmethod(lambda pem: object()))

    class _Resp:
        status_code = 410

    def _raise(**kw):
        raise pywebpush.WebPushException("gone", response=_Resp())

    monkeypatch.setattr(pywebpush, "webpush", _raise)

    sent = PushService.send_to_user("u1", "t", "b")
    assert sent == 0
    # Tote Subscription wurde entfernt
    assert PushService.get_subscriptions("u1") == []
