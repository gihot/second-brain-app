"""
GET /admin/usage — Token-Verbrauch-Aggregation für das Dashboard.

Bewusst auf verify_token statt eigener Admin-Rolle: solange es nur einen
echten User gibt, ist „eingeloggt" = „du". Wenn das in Wave 4/5 zur
Multi-User-Phase übergeht, kommt hier eine Rollen-Prüfung dazu.
"""
import asyncio
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse

from auth import verify_token
from services.token_usage_service import TokenUsageService

router = APIRouter()

# server/static/usage_dashboard.html — J8: same-origin ausgeliefert,
# damit das Dashboard kein CORS-`null`-Loch mehr braucht.
_STATIC_DIR = Path(__file__).parent.parent / "static"


@router.get("/usage")
async def usage(
    days: int = Query(30, ge=1, le=365),
    payload: dict = Depends(verify_token),
):
    """Aggregierter Token-Verbrauch der letzten `days` Tage. Schnitte:
    by_day, by_model, by_agent, by_endpoint, by_user + Totals.
    Kosten in USD, basierend auf Preisen zum Record-Zeitpunkt."""
    return await asyncio.to_thread(TokenUsageService.summary, days)


@router.get("/dashboard")
async def dashboard():
    """J8 (Plan v2): liefert das Token-Usage-Dashboard same-origin aus.

    Bewusst KEIN verify_token hier — die HTML selbst enthält keine
    Daten, sie holt sie via /admin/usage (das verify_token verlangt).
    Same-Origin macht das `null`-CORS-Loch überflüssig: der Browser
    sendet den echten Origin, der Bearer-Token-Header schützt die API.
    """
    html = _STATIC_DIR / "usage_dashboard.html"
    if not html.exists():
        raise HTTPException(status_code=404, detail="Dashboard not deployed")
    return FileResponse(html, media_type="text/html")
