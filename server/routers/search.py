"""GET /search — Seeker agent: local full-text + optional AI semantic ranking."""
from fastapi import APIRouter, Query

from services.vault_service import VaultService

router = APIRouter()


@router.get("")
async def search(q: str = Query(..., min_length=1), limit: int = Query(20, ge=1, le=50)):
    vault = VaultService.instance()
    results = vault.search(q, limit=limit)
    return {"query": q, "results": results, "count": len(results)}
