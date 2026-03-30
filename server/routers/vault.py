"""GET /vault/status — Librarian agent reports vault statistics."""
from fastapi import APIRouter

from services.vault_service import VaultService

router = APIRouter()


@router.get("/status")
async def vault_status():
    vault = VaultService.instance()
    return vault.get_status()


@router.get("/notes")
async def get_all_notes(limit: int = 200):
    """Return all notes from the vault for client-side sync."""
    vault = VaultService.instance()
    notes = vault.get_all_notes(limit=limit)
    return {"notes": notes}


@router.post("/sync")
async def sync_vault():
    """Pull latest changes from GitHub."""
    vault = VaultService.instance()
    await vault.ensure_vault()
    return {"message": "Vault synced"}
