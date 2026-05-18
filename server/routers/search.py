"""GET /search — Seeker agent: local full-text + optional AI semantic ranking."""
from fastapi import APIRouter, Query

from services.vault_service import VaultService
from services.index_service import IndexService

router = APIRouter()


@router.get("")
async def search(
    q: str = Query(..., min_length=1),
    limit: int = Query(20, ge=1, le=50),
    wing: str | None = Query(None),
    hall: str | None = Query(None),
):
    vault = VaultService.instance()
    kw = vault.search(q, limit=limit)
    results = IndexService.instance().hybrid_search(q, kw, limit)

    # Apply Wing + Hall filters (layered retrieval)
    if wing:
        results = [r for r in results if r.get("wing") == wing]
    if hall:
        results = [r for r in results if r.get("hall") == hall]

    return {"query": q, "results": results, "count": len(results)}
