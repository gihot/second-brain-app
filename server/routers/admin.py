"""
GET /admin/usage — Token-Verbrauch-Aggregation für das Dashboard.

Bewusst auf verify_token statt eigener Admin-Rolle: solange es nur einen
echten User gibt, ist „eingeloggt" = „du". Wenn das in Wave 4/5 zur
Multi-User-Phase übergeht, kommt hier eine Rollen-Prüfung dazu.
"""
import asyncio

from fastapi import APIRouter, Depends, Query

from auth import verify_token
from services.token_usage_service import TokenUsageService

router = APIRouter()


@router.get("/usage")
async def usage(
    days: int = Query(30, ge=1, le=365),
    payload: dict = Depends(verify_token),
):
    """Aggregierter Token-Verbrauch der letzten `days` Tage. Schnitte:
    by_day, by_model, by_agent, by_endpoint, by_user + Totals.
    Kosten in USD, basierend auf Preisen zum Record-Zeitpunkt."""
    return await asyncio.to_thread(TokenUsageService.summary, days)
