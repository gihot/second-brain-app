"""GET /inbox + POST /inbox/triage — Sorter agent processes all inbox notes."""
from fastapi import APIRouter, BackgroundTasks
from pydantic import BaseModel

from services.vault_service import VaultService
from services.agent_service import AgentService

router = APIRouter()


@router.get("")
async def get_inbox():
    vault = VaultService.instance()
    notes = vault.get_inbox_notes()
    return {"notes": notes, "count": len(notes)}


class TriageRequest(BaseModel):
    note_ids: list[str] | None = None  # None = triage all inbox notes


@router.post("/triage")
async def triage(req: TriageRequest, background: BackgroundTasks):
    vault = VaultService.instance()
    inbox_notes = vault.get_inbox_notes()

    if req.note_ids:
        inbox_notes = [n for n in inbox_notes if n.get("id") in req.note_ids]

    if not inbox_notes:
        return {"triaged": 0, "message": "Inbox is already empty"}

    # Run Sorter agent for each note (batched in background)
    background.add_task(_triage_notes, inbox_notes)

    return {
        "triaged": len(inbox_notes),
        "message": f"Triage started for {len(inbox_notes)} notes",
    }


async def _triage_notes(notes: list[dict]) -> None:
    vault = VaultService.instance()
    agent = AgentService()

    for note in notes:
        try:
            result = await agent.run(
                "sorter",
                note.get("content", ""),
                context={
                    "title": note.get("title", ""),
                    "tags": note.get("tags", []),
                    "file_path": note.get("file_path", ""),
                },
            )
            meta = result.get("metadata", {})
            para = meta.get("para") or "03-Resources"
            status = meta.get("status") or "processed"

            if note.get("file_path"):
                vault.move_note(note["file_path"], para, status)
        except Exception:
            pass  # Fail silently per note, don't abort batch

    vault.git_commit_and_push("triage: AI sorted inbox notes")
