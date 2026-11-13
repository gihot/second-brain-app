"""Reminder delivery preferences and scheduler entry point."""
import asyncio
import secrets
import smtplib

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel

from auth import verify_token
from config import get_settings
from rate_limit import limiter
from services.reminder_service import ReminderService
from services.user_service import UserService

router = APIRouter()


class ReminderSettings(BaseModel):
    email_enabled: bool


def _active_user(user_id: str) -> dict:
    user = UserService.get(user_id)
    if not user or user.get("pending_deletion_at"):
        raise HTTPException(status_code=403, detail="Active account required")
    return user


def _settings(user_id: str) -> dict:
    return {
        "email_available": ReminderService.email_available(),
        "email_enabled": ReminderService.email_enabled(user_id),
    }


@router.get("/settings")
def get_reminder_settings(payload: dict = Depends(verify_token)):
    _active_user(payload["sub"])
    return _settings(payload["sub"])


@router.put("/settings")
def put_reminder_settings(req: ReminderSettings, payload: dict = Depends(verify_token)):
    _active_user(payload["sub"])
    if req.email_enabled and not ReminderService.email_available():
        raise HTTPException(status_code=503, detail="Email is not configured")
    ReminderService.set_email(payload["sub"], req.email_enabled)
    return _settings(payload["sub"])


@router.post("/test-email")
@limiter.limit("3/hour")
async def test_reminder_email(request: Request, payload: dict = Depends(verify_token)):
    user = _active_user(payload["sub"])
    if not ReminderService.email_available() or not ReminderService.email_enabled(user["id"]):
        raise HTTPException(status_code=409, detail="Email reminders are disabled")
    try:
        await asyncio.to_thread(ReminderService.send_email, user["email"], "Das ist eine Test-Erinnerung.")
    except (OSError, smtplib.SMTPException):
        raise HTTPException(status_code=502, detail="Email could not be sent") from None
    return {"sent": True}


@router.post("/dispatch")
@limiter.limit("12/minute")
async def dispatch_reminders(request: Request, x_cron_secret: str = Header(default="")):
    secret = get_settings().cron_secret
    if not secret or not secrets.compare_digest(x_cron_secret.encode(), secret.encode()):
        raise HTTPException(status_code=403, detail="Invalid scheduler credentials")
    return {"sent": await asyncio.to_thread(ReminderService.send_due)}
