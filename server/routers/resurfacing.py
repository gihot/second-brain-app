"""
GET /resurfacing/today — bis zu N Notizen für „Taucht wieder auf".
POST /resurfacing/{note_id}/engaged — Open-Signal, löst 30-Tage-Pause aus.

Wave 3 R1+R2: ersetzt den lokalen Pseudo-Zufall (dashboard_signals.dart
`resurfacedNote`) durch persistentes Gedächtnis mit Score-basierter
Auswahl. Siehe services/resurfacing_service.py für die Score-Formel.
"""
import asyncio

from fastapi import APIRouter, Depends, Query

from auth import verify_token
from services.resurfacing_service import ResurfacingService
from services.vault_service import VaultService

router = APIRouter()


@router.get("/today")
async def today(
    limit: int = Query(3, ge=1, le=10),
    payload: dict = Depends(verify_token),
):
    """Wählt bis zu `limit` Notizen aus, markiert sie als gezeigt und
    liefert sie zurück. Resurfacing-Spec: 1–3 hochwertige Kandidaten,
    Dashboard bleibt ruhig — Default 3, hartes Cap bei 10.

    Antwortet immer mit einer (möglicherweise leeren) Liste — der Client
    fällt nie über ein None.
    """
    user_id = payload["sub"]
    vault = VaultService.for_user(user_id)

    candidates = await asyncio.to_thread(vault.get_all_notes, 1000)
    picked = await asyncio.to_thread(
        ResurfacingService.select_today, user_id, candidates, limit
    )

    # mark_shown ist Teil des Read-Pfads — der Client zeigt das, was wir
    # zurückgeben. Wenn der User den Tab nie öffnet, läuft auch das
    # Tracking nicht hoch (was korrekt ist: was er nicht sieht, zählt
    # nicht als „gezeigt").
    if picked:
        await asyncio.to_thread(
            ResurfacingService.mark_shown,
            user_id,
            [n["id"] for n in picked if "id" in n],
        )

    return {"notes": picked, "count": len(picked)}


@router.post("/{note_id}/engaged")
async def engaged(
    note_id: str,
    payload: dict = Depends(verify_token),
):
    """User hat die Resurface-Karte geöffnet. Signal: „hat seinen Zweck
    erfüllt" → 30 Tage Pause für diese Notiz."""
    await asyncio.to_thread(
        ResurfacingService.mark_engaged, payload["sub"], note_id
    )
    return {"ok": True}
