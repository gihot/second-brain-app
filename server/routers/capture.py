"""POST /capture — Scribe agent processes raw text into a titled, tagged note."""
import asyncio
from datetime import datetime, timezone
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import BaseModel

from auth import verify_token
from services.vault_service import VaultService
from services.agent_service import AgentService
from services.index_service import IndexService

router = APIRouter()

# Plan 2.1: Schwellwert für „ähnliche existieren bereits"-Hinweis im
# Save-Confirmation-Moment. Unter 0.75 cosine sind die Treffer zu
# schwach, um den User damit zu behelligen — wir wollen keinen Lärm,
# sondern echte Doppelerfassungen / nahe Nachbarn anzeigen.
_SIMILAR_THRESHOLD = 0.75
_SIMILAR_LIMIT = 3


class CaptureRequest(BaseModel):
    text: str
    note_id: str | None = None  # Client-generated UUID for idempotency


class SimilarNote(BaseModel):
    note_id: str
    title: str
    similarity: float


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
    # Plan 2.1: optionale Nachbarn der gerade gespeicherten Notiz —
    # leer wenn Embedding-Index aus, wenn nichts über dem Schwellwert
    # liegt, oder bei Index-Fehlern (defensive). Client zeigt sie als
    # optionale „↗ N ähnliche Gedanken existieren"-Zeile.
    similar_notes: list[SimilarNote] = []


@router.post("", response_model=CaptureResponse)
async def capture(
    req: CaptureRequest,
    background: BackgroundTasks,
    payload: dict = Depends(verify_token),
):
    if not req.text.strip():
        raise HTTPException(status_code=422, detail="Text cannot be empty")

    import uuid
    note_id = req.note_id or str(uuid.uuid4())
    user_id = payload["sub"]

    # Run Scribe agent to generate title + tags
    now_utc = datetime.now(timezone.utc)
    agent = AgentService.shared()
    result = await agent.run(
        "scribe",
        req.text,
        context={
            "note_id": note_id,
            "today_utc": now_utc.strftime("%Y-%m-%d"),
            "now_utc": now_utc.strftime("%Y-%m-%dT%H:%M:%S"),
        },
        user_id=user_id,
        endpoint="capture",
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

    vault = VaultService.for_user(user_id)
    file_path = await asyncio.to_thread(
        vault.write_note,
        note_id, title, req.text, tags, para,
        hall,
        suggested_wing or None,
        thought_type,
        remind_at,
    )

    # Push to GitHub in background (non-blocking)
    background.add_task(vault.git_commit_and_push, f"capture: {title[:60]}")

    # Plan 2.1: Top-K Nachbarn der gerade gespeicherten Notiz. Der Index
    # wurde durch vault.write_note bereits aktualisiert (synchron im
    # to_thread). related_notes schließt note_id selbst aus. Defensive:
    # Index-Fehler dürfen den Capture niemals brechen — auf [] fallen.
    similar_notes: list[SimilarNote] = []
    try:
        raw = await asyncio.to_thread(
            IndexService.for_user(user_id).related_notes,
            note_id,
            _SIMILAR_LIMIT,
        )
        similar_notes = [
            SimilarNote(
                note_id=r["note_id"],
                title=r["title"],
                similarity=r["similarity"],
            )
            for r in raw
            if r.get("similarity", 0) >= _SIMILAR_THRESHOLD
        ]
    except Exception as e:
        print(f"similar_notes lookup skipped for {note_id}: {e}")

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
        similar_notes=similar_notes,
    )


def _fallback_title(text: str) -> str:
    first_line = text.split("\n")[0].strip()
    if len(first_line) <= 60:
        return first_line or "Untitled"
    return " ".join(first_line.split()[:8]) + "..."
