"""Auth routes: POST /auth/login, POST /auth/signup, GET /auth/me.

- `/login`  is always open (the client needs to authenticate).
- `/signup` is gated by `SIGNUP_ENABLED`; default closed.
- `/me`     requires a valid bearer token (mounted with verify_token).
"""
import asyncio

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from pydantic import BaseModel, EmailStr

from auth import create_token, verify_token
from config import get_settings
from rate_limit import limiter
from services.user_service import UserService
from services.vault_service import VaultService

router = APIRouter()


async def _first_touch_setup(user_id: str) -> None:
    """Clone-or-pull the vault. Fast (~hundreds of ms on a small repo).
    Safe to await inline. Embedding reconcile is *not* here — see
    [VaultService.reconcile_if_needed] which runs as a BackgroundTask."""
    try:
        await VaultService.for_user(user_id).ensure_vault()
    except Exception as e:
        print(f"ensure_vault on login failed for {user_id}: {e}")


def _background_reconcile(user_id: str) -> None:
    """Synchronous wrapper for the embedding reconcile. Called as a
    FastAPI BackgroundTask so the auth response isn't blocked by the
    OpenAI calls."""
    try:
        VaultService.for_user(user_id).reconcile_if_needed()
    except Exception as e:
        print(f"background reconcile failed for {user_id}: {e}")


class _Creds(BaseModel):
    email: EmailStr
    password: str


class _AuthResponse(BaseModel):
    token: str
    user: dict


@router.post("/login", response_model=_AuthResponse)
@limiter.limit("5/minute;30/hour")
async def login(request: Request, background: BackgroundTasks, creds: _Creds):
    user = await asyncio.to_thread(
        UserService.verify, str(creds.email), creds.password
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials"
        )
    token = create_token(user["id"], user["email"])

    # Light setup awaited inline (sub-second git pull) so the user's first
    # request after login finds an up-to-date vault. Heavy work (embedding
    # reconcile) goes to a BackgroundTask — would otherwise block the
    # response for tens of seconds on a fresh-deployed vault.
    await _first_touch_setup(user["id"])
    background.add_task(_background_reconcile, user["id"])

    return {"token": token, "user": {"id": user["id"], "email": user["email"]}}


@router.post("/signup", response_model=_AuthResponse)
@limiter.limit("3/hour")
async def signup(request: Request, background: BackgroundTasks, creds: _Creds):
    settings = get_settings()
    if not settings.signup_enabled:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Signup is currently disabled",
        )
    try:
        user_id = await asyncio.to_thread(
            UserService.create, str(creds.email), creds.password
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    token = create_token(user_id, str(creds.email))
    await _first_touch_setup(user_id)
    background.add_task(_background_reconcile, user_id)
    return {"token": token, "user": {"id": user_id, "email": str(creds.email)}}


@router.get("/me")
async def me(payload: dict = Depends(verify_token)):
    user = await asyncio.to_thread(UserService.get, payload["sub"])
    if user is None:
        # Token references a user that no longer exists — treat as 401.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Unknown user"
        )
    return {"user": user}
