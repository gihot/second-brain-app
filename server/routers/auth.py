"""Auth routes: POST /auth/login, POST /auth/signup, GET /auth/me.

- `/login`  is always open (the client needs to authenticate).
- `/signup` is gated by `SIGNUP_ENABLED`; default closed.
- `/me`     requires a valid bearer token (mounted with verify_token).
"""
import asyncio
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from pydantic import BaseModel, EmailStr

from auth import create_token, verify_token
from config import get_settings
from rate_limit import limiter
from services.invite_service import InviteService
from services.user_service import UserService
from services.vault_service import VaultService


def _purge_due() -> None:
    """Wave 4.2: läuft auf jedem Login, räumt abgelaufene Pending-
    Deletions ab bevor der eigentliche Login-Check kommt. Importiert
    main.purge_due_user_data lazy — main.py importiert dieses Modul,
    Zirkularität auf top-level vermeiden."""
    from main import purge_due_user_data
    settings = get_settings()
    try:
        purge_due_user_data(Path(settings.data_root))
    except Exception as e:
        print(f"login-time purge failed: {e}")

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


class _SignupCreds(BaseModel):
    email: EmailStr
    password: str
    # Plan 4.3: Signup nur mit gültigem Einladungs-Code möglich,
    # solange settings.signup_enabled nicht generell offen ist.
    invite_code: str | None = None


class _AuthResponse(BaseModel):
    token: str
    user: dict


@router.post("/login", response_model=_AuthResponse)
@limiter.limit("5/minute;30/hour")
async def login(request: Request, background: BackgroundTasks, creds: _Creds):
    # Wave 4.2: vor dem Login fällige Hard-Deletes abräumen — wenn ein
    # User seine 30 Tage Frist erreicht hat, wird sein Account hier
    # finalisiert, und der Login schlägt korrekt mit 401 fehl.
    await asyncio.to_thread(_purge_due)

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
async def signup(request: Request, background: BackgroundTasks, creds: _SignupCreds):
    settings = get_settings()
    # Plan 4.3: zwei Pfade. settings.signup_enabled = generelle Öffnung
    # (z.B. bei Beta-Rollout). Ohne den Schalter braucht's einen
    # gültigen Invite-Code.
    invite_consumed_for: str | None = None
    if not settings.signup_enabled:
        if not creds.invite_code:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Einladungs-Code erforderlich.",
            )
        # Der Code wird HIER NOCH NICHT eingelöst — erst nach
        # erfolgreichem Create. Sonst verlieren wir bei einem
        # IntegrityError (Duplicate-Email) den Code unwiederbringlich.
        # Stattdessen: Pre-Validierung via list+filter wäre teuer →
        # wir konsumieren atomar nach dem create-Erfolg unten.
        invite_consumed_for = creds.invite_code
    try:
        user_id = await asyncio.to_thread(
            UserService.create, str(creds.email), creds.password
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    # Code jetzt einlösen. Wenn er ungültig ist, müssen wir den frisch
    # angelegten User wieder zurückrollen — sonst hätten wir einen
    # Account ohne Einladung. Atomar-`consume` filtert auch abgelaufene
    # / schon verbrauchte Codes raus.
    if invite_consumed_for is not None:
        consumed = await asyncio.to_thread(
            InviteService.consume, invite_consumed_for, user_id
        )
        if not consumed:
            await asyncio.to_thread(UserService.hard_delete, user_id)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Einladungs-Code ungültig oder bereits eingelöst.",
            )

    token = create_token(user_id, str(creds.email))
    await _first_touch_setup(user_id)
    background.add_task(_background_reconcile, user_id)
    return {"token": token, "user": {"id": user_id, "email": str(creds.email)}}


class _InviteListResponse(BaseModel):
    codes: list[dict]


@router.post("/invite")
@limiter.limit("10/hour")
async def create_invite(
    request: Request,
    payload: dict = Depends(verify_token),
):
    """Plan 4.3: erzeugt einen neuen Einladungs-Code für den Aufrufer.
    Max 10 offene pro User (siehe InviteService). Code ist 14 Tage
    gültig und einmal einlösbar."""
    code, error = await asyncio.to_thread(
        InviteService.create, payload["sub"]
    )
    if error is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=error
        )
    return {"code": code}


@router.get("/invites")
async def list_invites(payload: dict = Depends(verify_token)):
    """Alle Codes des Users (offen, eingelöst, abgelaufen).
    Für die „Freund einladen"-Tile in den Settings."""
    codes = await asyncio.to_thread(
        InviteService.list_for_user, payload["sub"]
    )
    return {"codes": codes}


class _PasswordChange(BaseModel):
    current_password: str
    new_password: str


@router.post("/password")
@limiter.limit("3/hour")
async def change_password(
    request: Request,
    req: _PasswordChange,
    payload: dict = Depends(verify_token),
):
    """Plan 4.1: Passwort ändern. Re-Auth via aktuelles Passwort
    obligatorisch — schützt gegen Token-Hijack. Rate-Limit 3/hour,
    weil Brute-Force gegen das aktuelle Passwort theoretisch denkbar
    ist (wenn jemand schon ein Token hat — dann ist's eh zu spät, aber
    defense in depth)."""
    ok, error = await asyncio.to_thread(
        UserService.change_password,
        payload["sub"],
        req.current_password,
        req.new_password,
    )
    if not ok:
        # 400 statt 401: das Token ist gültig, nur die Re-Auth oder
        # die Validierung des neuen Passworts ist gescheitert.
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error)
    return {"ok": True}


@router.get("/me")
async def me(payload: dict = Depends(verify_token)):
    user = await asyncio.to_thread(UserService.get, payload["sub"])
    if user is None:
        # Token references a user that no longer exists — treat as 401.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Unknown user"
        )
    # /me liefert jetzt pending_deletion_at mit — der Client zeigt
    # daraus den roten „dein Account wird gelöscht"-Banner.
    return {"user": user}


class _DeletionRequest(BaseModel):
    current_password: str


@router.post("/request-deletion")
@limiter.limit("2/hour")
async def request_deletion(
    request: Request,
    req: _DeletionRequest,
    payload: dict = Depends(verify_token),
):
    """Wave 4.2: Account-Soft-Delete starten. Setzt pending_deletion_at
    auf now + 30d. Re-Auth via aktuelles Passwort — schützt gegen
    Token-Hijack-Vandalismus. Bis zum Frist-Ablauf jederzeit per
    /auth/cancel-deletion aufhebbar."""
    ok, error, deletion_at = await asyncio.to_thread(
        UserService.request_deletion, payload["sub"], req.current_password
    )
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=error
        )
    return {"ok": True, "pending_deletion_at": deletion_at}


@router.post("/cancel-deletion")
async def cancel_deletion(payload: dict = Depends(verify_token)):
    """Wave 4.2: laufende Soft-Deletion abbrechen — pending_deletion_at
    wird auf NULL gesetzt. Kein Re-Auth: wer den Token besitzt und den
    Cancel-Button drückt, ist genau der den wir schützen wollen."""
    ok = await asyncio.to_thread(UserService.cancel_deletion, payload["sub"])
    return {"ok": ok}
