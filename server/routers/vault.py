"""GET /vault/status — Librarian agent reports vault statistics."""
from fastapi import APIRouter

from services.vault_service import VaultService

router = APIRouter()


@router.get("/status")
async def vault_status():
    vault = VaultService.instance()
    return vault.get_status()


@router.post("/sync")
async def sync_vault():
    """Pull latest changes from GitHub."""
    vault = VaultService.instance()
    await vault.ensure_vault()
    return {"message": "Vault synced"}
