"""Vault routes: status, full read, sync, and per-note write/delete."""
import asyncio

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from auth import verify_token
from services.identity_service import IdentityService
from services.index_service import IndexService
from services.vault_service import VaultService

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
    thought_type: str | None = None
    remind_at: str | None = None


class NoteDeleteRequest(BaseModel):
    file_path: str


@router.get("/status")
async def vault_status(payload: dict = Depends(verify_token)):
    vault = VaultService.for_user(payload["sub"])
    return vault.get_status()


@router.get("/notes")
async def get_all_notes(
    limit: int = 200,
    payload: dict = Depends(verify_token),
):
    """Return all notes from the vault for client-side sync."""
    vault = VaultService.for_user(payload["sub"])
    notes = vault.get_all_notes(limit=limit)
    return {"notes": notes}


@router.put("/notes")
async def update_note(
    req: NoteUpdateRequest,
    payload: dict = Depends(verify_token),
):
    """Update an existing note's frontmatter and/or content."""
    vault = VaultService.for_user(payload["sub"])
    try:
        new_path = await asyncio.to_thread(
            vault.update_note,
            req.file_path,
            title=req.title,
            content=req.content,
            tags=req.tags,
            status=req.status,
            para=req.para,
            hall=req.hall,
            wing=req.wing,
            thought_type=req.thought_type,
            remind_at=req.remind_at,
        )
        return {"file_path": new_path}
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/notes")
async def delete_note(
    req: NoteDeleteRequest,
    payload: dict = Depends(verify_token),
):
    """Permanently delete a note from the vault."""
    vault = VaultService.for_user(payload["sub"])
    try:
        await asyncio.to_thread(vault.delete_note, req.file_path)
        return {"deleted": req.file_path}
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/wings")
async def get_wings(payload: dict = Depends(verify_token)):
    """Return all distinct wings with counts."""
    vault = VaultService.for_user(payload["sub"])
    return {"wings": vault.get_wings()}


class WingRenameRequest(BaseModel):
    old_wing: str
    new_wing: str


@router.put("/wings/rename")
async def rename_wing(
    req: WingRenameRequest,
    payload: dict = Depends(verify_token),
):
    """Rename a wing across all notes."""
    vault = VaultService.for_user(payload["sub"])
    count = vault.rename_wing(req.old_wing, req.new_wing)
    return {"updated": count, "new_wing": req.new_wing}


@router.get("/related/{note_id}")
async def related_notes(
    note_id: str,
    limit: int = 5,
    payload: dict = Depends(verify_token),
):
    """Embedding-based nearest-neighbor lookup for a single note.

    Returns up to `limit` other notes ranked by cosine similarity. Empty
    list when the embedding index is disabled (no OPENAI_API_KEY) or the
    note isn't indexed yet — never raises.
    """
    related = await asyncio.to_thread(
        IndexService.for_user(payload["sub"]).related_notes, note_id, limit
    )
    return {"related": related}


@router.post("/sync")
async def sync_vault(payload: dict = Depends(verify_token)):
    """Pull latest changes from GitHub."""
    vault = VaultService.for_user(payload["sub"])
    await vault.ensure_vault()
    return {"message": "Vault synced"}


@router.get("/identity")
async def get_identity(payload: dict = Depends(verify_token)):
    """Return the current identity.md content."""
    return {"content": IdentityService.for_user(payload["sub"]).get()}


class IdentityUpdateRequest(BaseModel):
    content: str


@router.put("/identity")
async def update_identity(
    req: IdentityUpdateRequest,
    payload: dict = Depends(verify_token),
):
    """Update identity.md (max 800 chars)."""
    IdentityService.for_user(payload["sub"]).update(req.content)
    return {"content": req.content.strip()[:800]}
