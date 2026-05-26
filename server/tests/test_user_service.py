"""Tests for the SQLite-backed UserService — bcrypt round-trip, lookup,
duplicates, case-insensitivity, dummy-bcrypt timing guard."""
import pytest

from services.user_service import UserService


@pytest.fixture
def user_db(tmp_path):
    """Fresh per-test sqlite DB, initialized via UserService.init()."""
    UserService.init(tmp_path / "auth.db")
    yield
    # No teardown needed — tmp_path is cleaned by pytest, and the next
    # test reinitializes.


def test_create_and_verify_roundtrip(user_db):
    uid = UserService.create("alice@example.com", "s3cret!")
    assert uid

    user = UserService.verify("alice@example.com", "s3cret!")
    assert user is not None
    assert user["id"] == uid
    assert user["email"] == "alice@example.com"


def test_verify_wrong_password_returns_none(user_db):
    UserService.create("bob@example.com", "right-password")
    assert UserService.verify("bob@example.com", "wrong-password") is None


def test_verify_unknown_email_returns_none(user_db):
    assert UserService.verify("ghost@example.com", "anything") is None


def test_create_duplicate_email_raises(user_db):
    UserService.create("carol@example.com", "pw1")
    with pytest.raises(ValueError):
        UserService.create("carol@example.com", "pw2")


def test_create_empty_inputs_raises(user_db):
    with pytest.raises(ValueError):
        UserService.create("", "pw")
    with pytest.raises(ValueError):
        UserService.create("a@b.de", "")


def test_email_case_insensitivity(user_db):
    """create() and verify() both .strip().lower() the email — so
    Foo@Bar.de and foo@bar.de are the same account."""
    uid = UserService.create("Foo@Bar.de", "pw")
    user = UserService.verify("foo@bar.de", "pw")
    assert user is not None
    assert user["id"] == uid


def test_get_by_id(user_db):
    uid = UserService.create("dave@example.com", "pw")
    user = UserService.get(uid)
    assert user is not None
    assert user["email"] == "dave@example.com"


def test_get_unknown_id_returns_none(user_db):
    assert UserService.get("nonexistent-uid") is None


def test_count(user_db):
    assert UserService.count() == 0
    UserService.create("a@a.de", "pw")
    UserService.create("b@b.de", "pw")
    assert UserService.count() == 2


def test_change_password_happy_path(user_db):
    uid = UserService.create("frank@example.com", "old-pw1!")
    ok, err = UserService.change_password(uid, "old-pw1!", "new-pw2!")
    assert ok is True
    assert err is None
    # old password fails, new password works
    assert UserService.verify("frank@example.com", "old-pw1!") is None
    assert UserService.verify("frank@example.com", "new-pw2!") is not None


def test_change_password_wrong_current(user_db):
    uid = UserService.create("grace@example.com", "real-pw1")
    ok, err = UserService.change_password(uid, "wrong-pw", "new-pw1!")
    assert ok is False
    assert err is not None
    # original password still works
    assert UserService.verify("grace@example.com", "real-pw1") is not None


def test_change_password_too_short(user_db):
    uid = UserService.create("heidi@example.com", "long-enough!")
    ok, err = UserService.change_password(uid, "long-enough!", "short")
    assert ok is False
    assert err is not None


def test_change_password_same_as_old(user_db):
    uid = UserService.create("ivan@example.com", "long-enough!")
    ok, err = UserService.change_password(uid, "long-enough!", "long-enough!")
    assert ok is False
    assert err is not None


def test_verify_with_empty_password_dummy_check(user_db):
    """Empty inputs hit the dummy bcrypt path. Should return None without
    raising — and *should* take roughly bcrypt time (we don't assert
    timing here, just that the call completes cleanly)."""
    UserService.create("eve@example.com", "real-pw")
    assert UserService.verify("eve@example.com", "") is None
    assert UserService.verify("", "real-pw") is None
