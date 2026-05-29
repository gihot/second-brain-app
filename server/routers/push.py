"""
Web-Push-Endpoints (Notifications-Phase 1).

- GET  /push/vapid-public-key  → Client holt den Application-Server-Key
- POST /push/subscribe         → Browser-Subscription speichern
- POST /push/unsubscribe       → Subscription löschen
- POST /push/test              → Test-Notification an den eigenen User
                                  (zur iOS-Geräte-Validierung)
"""
import asyncio

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from auth import verify_token
from services.push_service import PushService

router = APIRouter()


@router.get("/vapid-public-key")
async def vapid_public_key():
    """Öffentlicher VAPID-Key fürs Client-`applicationServerKey`.
    Kein Auth nötig — der Public-Key ist nicht geheim."""
    if not PushService.enabled():
        raise HTTPException(status_code=503, detail="Push nicht konfiguriert")
    return {"public_key": PushService.public_key()}


class SubscribeRequest(BaseModel):
    # PushSubscription-JSON des Browsers
    endpoint: str
    keys: dict


@router.post("/subscribe")
async def subscribe(
    req: SubscribeRequest,
    payload: dict = Depends(verify_token),
):
    try:
        await asyncio.to_thread(
            PushService.save_subscription,
            payload["sub"],
            {"endpoint": req.endpoint, "keys": req.keys},
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"ok": True}


class UnsubscribeRequest(BaseModel):
    endpoint: str


@router.post("/unsubscribe")
async def unsubscribe(
    req: UnsubscribeRequest,
    payload: dict = Depends(verify_token),
):
    await asyncio.to_thread(
        PushService.remove_subscription, payload["sub"], req.endpoint
    )
    return {"ok": True}


@router.post("/test")
async def test_push(payload: dict = Depends(verify_token)):
    """Sendet eine Test-Notification an alle Geräte des Users.
    Zentral für die iOS-Geräte-Validierung (Phase 1): PWA installieren,
    Notifications erlauben, hier auslösen, prüfen ob sie ankommt."""
    sent = await asyncio.to_thread(
        PushService.send_to_user,
        payload["sub"],
        "Second Brain",
        "Test-Notification — wenn du das siehst, funktioniert Push. 🎉",
    )
    return {"sent": sent}
