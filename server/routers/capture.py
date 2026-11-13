"""POST /capture — Scribe agent processes raw text into a titled, tagged note."""
import asyncio
import json
from datetime import datetime, timedelta, timezone
from uuid import uuid4
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import AwareDatetime, BaseModel, Field

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
    note_id: str | None = Field(default=None, pattern=r"^[A-Za-z0-9_-]{1,128}$")
    # Minuten-Offset der User-Zeitzone (z.B. 120 für CEST). Damit löst
    # Scribe „heute Abend" in LOKALER Zeit auf und der Server konvertiert
    # nach UTC. Default 0 (UTC) für Alt-Clients ohne das Feld.
    tz_offset_minutes: int = Field(default=0, ge=-840, le=840)
    remind_at: AwareDatetime | None = None


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

    note_id = req.note_id or str(uuid4())
    user_id = payload["sub"]
    vault = VaultService.for_user(user_id)
    if req.note_id is not None:
        existing = await asyncio.to_thread(vault.note_by_id, note_id)
        if existing is not None:
            return CaptureResponse(
                note_id=note_id,
                title=existing.get("title") or _fallback_title(req.text),
                tags=_stored_tags(existing.get("tags")),
                file_path=existing["file_path"],
                para=existing.get("para") or "00-Inbox",
                hall=existing.get("hall") or "unclassified",
                suggested_wing=existing.get("wing") or "",
                thought_type=existing.get("thought_type") or "standard",
                remind_at=existing.get("remind_at"),
            )

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
            "now_local": (now_utc + timedelta(minutes=req.tz_offset_minutes)).strftime("%Y-%m-%dT%H:%M:%S"),
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
    # Scribe liefert remind_at lokal-naiv → deterministisch nach UTC.
    remind_at = _local_remind_to_utc(meta.get("remind_at"), req.tz_offset_minutes)

    if req.remind_at is not None:
        remind_at = req.remind_at.astimezone(timezone.utc).isoformat()
        thought_type = "reminder"

    # Normalize wing: lowercase kebab-case
    if suggested_wing:
        import re
        suggested_wing = re.sub(r"[^a-z0-9]+", "-", suggested_wing.lower()).strip("-")

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


def _stored_tags(value: str | None) -> list[str]:
    if not value:
        return []
    try:
        tags = json.loads(value)
        if isinstance(tags, list):
            return [str(tag) for tag in tags]
    except ValueError:
        pass
    return [tag.strip().strip("\"'") for tag in value.strip("[]").split(",") if tag.strip()]


def _fallback_title(text: str) -> str:
    first_line = text.split("\n")[0].strip()
    if len(first_line) <= 60:
        return first_line or "Untitled"
    return " ".join(first_line.split()[:8]) + "..."


def _local_remind_to_utc(raw: str | None, tz_offset_minutes: int) -> str | None:
    """Konvertiert Scribes lokal-naive remind_at (z.B. "2026-05-30T18:00:00")
    nach UTC-ISO. Robust gegen LLM-Abweichungen:
      - bereits mit tz-Info (Z/+hh:mm) → unverändert als UTC interpretiert
      - leer/None/unparsebar → None
    """
    if not raw or not str(raw).strip():
        return None
    s = str(raw).strip()
    try:
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None
    if dt.tzinfo is not None:
        # LLM hat trotz Anweisung eine Zeitzone gesetzt — als gegeben nehmen.
        return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+00:00")
    # naiv = lokale Zeit → UTC = lokal − offset
    utc_dt = (dt - timedelta(minutes=tz_offset_minutes)).replace(tzinfo=timezone.utc)
    return utc_dt.strftime("%Y-%m-%dT%H:%M:%S+00:00")
