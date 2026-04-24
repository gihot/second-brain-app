"""GET /discovery/daily — Daily insight card for the dashboard.

Returns the single most interesting connection between recent notes.
Cached in-memory for 24h (single-user server, no per-user keying needed).
Local insights (reminders, related note, tag pattern) are computed
client-side from VaultProvider to keep latency low.
"""
import re
from datetime import datetime, timedelta

from fastapi import APIRouter

from services.vault_service import VaultService
from services.agent_service import AgentService

router = APIRouter()

# In-memory 24h cache
_cache: dict = {"data": None, "at": None}


@router.get("/daily")
async def daily_discovery():
    """Return a connection insight between recent notes, cached 24h."""
    if _cache["at"] and datetime.utcnow() - _cache["at"] < timedelta(hours=24):
        return _cache["data"]

    vault = VaultService.instance()
    notes = vault.get_all_notes(limit=10)

    result: dict = {
        "connection": None,
        "cached_at": datetime.utcnow().isoformat(),
    }

    if len(notes) >= 2:
        note_a = notes[0]
        candidates = notes[1:5]

        message = (
            f"Find the single most meaningful connection for this note:\n\n"
            f"Title: {note_a.get('title', '')}\n"
            f"Content: {(note_a.get('content', '') or '')[:400]}"
        )
        context = {
            "notes": [
                {
                    "title": n.get("title", ""),
                    "file_path": n.get("file_path", ""),
                    "content": (n.get("content", "") or "")[:200],
                }
                for n in candidates
            ],
            "response_format": "json",
        }

        try:
            agent = AgentService()
            response = await agent.run("connector", message, context=context)
            metadata = response.get("metadata", {})
            connections = metadata.get("connections", [])

            if connections:
                best = connections[0]
                connected_path = best.get("file_path", "")
                connected_note = next(
                    (n for n in notes if n.get("file_path", "") == connected_path),
                    None,
                )
                note_b_title = (
                    connected_note.get("title", connected_path)
                    if connected_note
                    else _path_to_title(connected_path)
                )
                result["connection"] = {
                    "note_a_title": note_a.get("title", ""),
                    "note_b_title": note_b_title,
                    "explanation": best.get("explanation", ""),
                    "connection_type": best.get("connection_type", "related"),
                }
        except Exception:
            pass  # Fail silently — dashboard still works with local insights

    _cache["data"] = result
    _cache["at"] = datetime.utcnow()
    return result


@router.post("/invalidate")
async def invalidate_cache():
    """Force-refresh on next request (e.g. after major vault changes)."""
    _cache["at"] = None
    return {"invalidated": True}


def _path_to_title(file_path: str) -> str:
    name = file_path.split("/")[-1].replace(".md", "")
    return re.sub(r"[-_]+", " ", name).title()
