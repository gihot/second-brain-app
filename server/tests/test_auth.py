"""Tests for the JWT helpers in server/auth.py — roundtrip, expiry,
tampered signature."""
import os
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials


# Ensure a stable JWT_SECRET before any module that reads it imports
# `get_settings()`. Settings reads env at class-evaluation time.
os.environ["JWT_SECRET"] = "test-secret-do-not-use-in-production"

# Import AFTER env setup.
from auth import create_token, verify_token  # noqa: E402
from config import get_settings  # noqa: E402


def _bearer(token: str) -> HTTPAuthorizationCredentials:
    return HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)


def test_create_and_verify_roundtrip():
    token = create_token("uid-123", "alice@example.com")
    payload = verify_token(_bearer(token))
    assert payload["sub"] == "uid-123"
    assert payload["email"] == "alice@example.com"
    assert "iat" in payload
    assert "exp" in payload


def test_expired_token_raises_401():
    settings = get_settings()
    past = datetime.now(timezone.utc) - timedelta(seconds=10)
    token = jwt.encode(
        {"sub": "uid-x", "iat": past, "exp": past + timedelta(seconds=1)},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )
    with pytest.raises(HTTPException) as exc_info:
        verify_token(_bearer(token))
    assert exc_info.value.status_code == 401
    assert "expired" in str(exc_info.value.detail).lower()


def test_tampered_signature_raises_401():
    token = create_token("uid-1", "a@a.de")
    # Replace the signature with same-length garbage (single-char flips
    # can decode to a different but coincidentally adjacent byte that
    # pyjwt's base64 layer still digests — wholesale replacement is the
    # unambiguous "this is wrong" case the test cares about).
    head, payload, sig = token.split(".")
    bad_sig = "A" * len(sig)
    with pytest.raises(HTTPException) as exc_info:
        verify_token(_bearer(f"{head}.{payload}.{bad_sig}"))
    assert exc_info.value.status_code == 401


def test_garbage_token_raises_401():
    with pytest.raises(HTTPException) as exc_info:
        verify_token(_bearer("not.a.jwt"))
    assert exc_info.value.status_code == 401
