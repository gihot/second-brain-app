"""POST /capture — Scribe agent processes raw text into a titled, tagged note."""
from fastapi import APIRouter, BackgroundTasks, HTTPException
from pydantic import BaseModel

from services.vault_service import VaultService
from services.agent_service import AgentService

router = APIRouter()


class CaptureRequest(BaseModel):
    text: str
    note_id: str | None = None  # Client-generated UUID for idempotency


class CaptureResponse(BaseModel):
    note_id: str
    title: str
    tags: list[str]
    file_path: str
    para: str
    hall: str = "unclassified"
    suggested_wing: str = ""
    thought_type: str = "standard"
    remind_at: str | None = None


@router.post("", response_model=CaptureResponse)
async def capture(req: CaptureRequest, background: BackgroundTasks):
    if not req.text.strip():
        raise HTTPException(status_code=422, detail="Text cannot be empty")

    import uuid
    note_id = req.note_id or str(uuid.uuid4())

    # Run Scribe agent to generate title + tags
    agent = AgentService()
    result = await agent.run(
        "scribe",
        req.text,
        context={"note_id": note_id},
    )

    meta = result.get("metadata", {})
    title = meta.get("title") or _fallback_title(req.text)
    tags = meta.get("tags") or []
    para = meta.get("para") or "00-Inbox"
    hall = meta.get("hall") or "unclassified"
    suggested_wing = meta.get("suggested_wing") or ""
    thought_type = meta.get("thought_type") or "standard"
    remind_at = meta.get("remind_at") or None

    # Normalize wing: lowercase kebab-case
    if suggested_wing:
        import re
        suggested_wing = re.sub(r"[^a-z0-9]+", "-", suggested_wing.lower()).strip("-")

    vault = VaultService.instance()
    file_path = vault.write_note(
        note_id, title, req.text, tags, para,
        hall=hall,
        wing=suggested_wing or None,
        thought_type=thought_type,
        remind_at=remind_at,
    )

    # Push to GitHub in background (non-blocking)
    background.add_task(vault.git_commit_and_push, f"capture: {title[:60]}")

    return CaptureResponse(
        note_id=note_id,
        title=title,
        tags=tags,
        file_path=file_path,
        para=para,
        hall=hall,
        suggested_wing=suggested_wing,
        thought_type=thought_type,
        remind_at=remind_at,
    )


def _fallback_title(text: str) -> str:
    first_line = text.split("\n")[0].strip()
    if len(first_line) <= 60:
        return first_line or "Untitled"
    return " ".join(first_line.split()[:8]) + "..."
