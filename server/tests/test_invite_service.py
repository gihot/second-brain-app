"""Tests für InviteService — create/consume-Roundtrip, Limit,
Atomarität gegen Doppel-Einlösung, Cleanup bei User-Delete."""
import pytest

from services.invite_service import InviteService


@pytest.fixture
def invite_db(tmp_path):
    InviteService.init(tmp_path / "auth.db")
    yield


def test_create_and_consume_roundtrip(invite_db):
    code, err = InviteService.create("alice-uid")
    assert err is None
    assert code and len(code) >= 8
    assert InviteService.consume(code, "bob-uid") is True


def test_consume_returns_false_for_unknown_code(invite_db):
    assert InviteService.consume("NOTAREALCODE", "x-uid") is False


def test_consume_is_atomic_no_double_use(invite_db):
    code, _ = InviteService.create("alice-uid")
    assert InviteService.consume(code, "bob-uid") is True
    # Zweiter Versuch mit demselben Code → False
    assert InviteService.consume(code, "carol-uid") is False


def test_consume_case_insensitive(invite_db):
    code, _ = InviteService.create("alice-uid")
    assert InviteService.consume(code.lower(), "bob-uid") is True


def test_max_open_invites_per_user(invite_db):
    for _ in range(10):
        code, err = InviteService.create("greedy-uid")
        assert err is None and code is not None
    # 11.: blockiert
    code, err = InviteService.create("greedy-uid")
    assert code is None
    assert err is not None


def test_list_for_user_shows_states(invite_db):
    open_code, _ = InviteService.create("alice-uid")
    used_code, _ = InviteService.create("alice-uid")
    InviteService.consume(used_code, "bob-uid")
    rows = InviteService.list_for_user("alice-uid")
    assert len(rows) == 2
    states = {r["code"]: r["state"] for r in rows}
    assert states[open_code] == "open"
    assert states[used_code] == "used"


def test_delete_user_data_removes_created_codes(invite_db):
    InviteService.create("alice-uid")
    InviteService.create("alice-uid")
    InviteService.create("other-uid")
    n = InviteService.delete_user_data("alice-uid")
    assert n == 2
    assert InviteService.list_for_user("alice-uid") == []
    assert len(InviteService.list_for_user("other-uid")) == 1
