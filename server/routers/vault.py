"""Vault routes: status, full read, sync, and per-note write/delete."""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from services.vault_service import VaultService
from services.identity_service import IdentityService

router = APIRouter()


class NoteUpdateRequest(BaseModel):
    file_path: str
    title: str | None = None
    content: str | None = None
    tags: list[str] | None = None
    status: str | None = None
    para: str | None = None
    hall: str | None = None
    wing: str | None = None


class NoteDeleteRequest(BaseModel):
    file_path: str


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


@router.put("/notes")
async def update_note(req: NoteUpdateRequest):
    """Update an existing note's frontmatter and/or content."""
    vault = VaultService.instance()
    try:
        new_path = vault.update_note(
            req.file_path,
            title=req.title,
            content=req.content,
            tags=req.tags,
            status=req.status,
            para=req.para,
            hall=req.hall,
            wing=req.wing,
        )
        return {"file_path": new_path}
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/notes")
async def delete_note(req: NoteDeleteRequest):
    """Permanently delete a note from the vault."""
    vault = VaultService.instance()
    try:
        vault.delete_note(req.file_path)
        return {"deleted": req.file_path}
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/wings")
async def get_wings():
    """Return all distinct wings with counts."""
    vault = VaultService.instance()
    return {"wings": vault.get_wings()}


class WingRenameRequest(BaseModel):
    old_wing: str
    new_wing: str


@router.put("/wings/rename")
async def rename_wing(req: WingRenameRequest):
    """Rename a wing across all notes."""
    vault = VaultService.instance()
    count = vault.rename_wing(req.old_wing, req.new_wing)
    return {"updated": count, "new_wing": req.new_wing}


@router.post("/sync")
async def sync_vault():
    """Pull latest changes from GitHub."""
    vault = VaultService.instance()
    await vault.ensure_vault()
    return {"message": "Vault synced"}


@router.get("/identity")
async def get_identity():
    """Return the current identity.md content."""
    return {"content": IdentityService.instance().get()}


class IdentityUpdateRequest(BaseModel):
    content: str


@router.put("/identity")
async def update_identity(req: IdentityUpdateRequest):
    """Update identity.md (max 800 chars)."""
    IdentityService.instance().update(req.content)
    return {"content": req.content.strip()[:800]}
