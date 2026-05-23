"""Auth routes: POST /auth/login, POST /auth/signup, GET /auth/me.

- `/login`  is always open (the client needs to authenticate).
- `/signup` is gated by `SIGNUP_ENABLED`; default closed.
- `/me`     requires a valid bearer token (mounted with verify_token).
"""
import asyncio

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr

from auth import create_token, verify_token
from config import get_settings
from services.user_service import UserService
from services.vault_service import VaultService

router = APIRouter()


class _Creds(BaseModel):
    email: EmailStr
    password: str


class _AuthResponse(BaseModel):
    token: str
    user: dict


@router.post("/login", response_model=_AuthResponse)
async def login(creds: _Creds):
    user = await asyncio.to_thread(
        UserService.verify, str(creds.email), creds.password
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials"
        )
    token = create_token(user["id"], user["email"])

    # First-touch vault setup: clone if missing, lazy reconcile once.
    # Errors here must not block login — the user can still hit /vault/sync later.
    try:
        await VaultService.for_user(user["id"]).ensure_vault()
    except Exception as e:
        print(f"ensure_vault on login failed for {user['id']}: {e}")

    return {"token": token, "user": {"id": user["id"], "email": user["email"]}}


@router.post("/signup", response_model=_AuthResponse)
async def signup(creds: _Creds):
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
    try:
        await VaultService.for_user(user_id).ensure_vault()
    except Exception as e:
        print(f"ensure_vault on signup failed for {user_id}: {e}")
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
