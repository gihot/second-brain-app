"""GET /discovery/daily — Daily insight card for the dashboard.

Returns the single most interesting connection between recent notes.
The user can wisch-weg the suggestion (POST /discovery/dismiss); the
pair then stays out of rotation for 14 days.
"""
import re
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from auth import verify_token
from services.agent_service import AgentService
from services.paused_pairs_service import PausedPairsService
from services.vault_service import VaultService

router = APIRouter()

# In-memory cache, keyed per user (single-user vault: ~one entry).
_cache: dict[str, dict] = {}


@router.get("/daily")
async def daily_discovery(payload: dict = Depends(verify_token)):
    """Return a connection insight between recent notes, cached 24h per user.

    If the top-ranked connection is in the user's "paused"-list, the
    next-best is tried, and so on. Empty connection → empty card.
    """
    user_id = payload["sub"]
    cached = _cache.get(user_id)
    if cached and datetime.now(timezone.utc) - cached["at"] < timedelta(hours=24):
        return cached["data"]

    vault = VaultService.for_user(user_id)
    notes = vault.get_all_notes(limit=10)

    result: dict = {
        "connection": None,
        "cached_at": datetime.now(timezone.utc).isoformat(),
    }

    if len(notes) >= 2:
        note_a = notes[0]
        note_a_id = note_a.get("id", "")
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
            response = await agent.run(
                "connector", message, context=context, user_id=user_id
            )
            metadata = response.get("metadata", {})
            connections = metadata.get("connections", [])

            # Walk down the ranked list, skip pairs the user dismissed.
            for candidate_conn in connections:
                connected_path = candidate_conn.get("file_path", "")
                connected_note = next(
                    (n for n in notes if n.get("file_path", "") == connected_path),
                    None,
                )
                note_b_id = (
                    connected_note.get("id", "") if connected_note else connected_path
                )
                if PausedPairsService.is_paused(user_id, note_a_id, note_b_id):
                    continue

                note_b_title = (
                    connected_note.get("title", connected_path)
                    if connected_note
                    else _path_to_title(connected_path)
                )
                result["connection"] = {
                    "note_a_id": note_a_id,
                    "note_a_title": note_a.get("title", ""),
                    "note_b_id": note_b_id,
                    "note_b_title": note_b_title,
                    "explanation": candidate_conn.get("explanation", ""),
                    "connection_type": candidate_conn.get("connection_type", "related"),
                }
                break
        except Exception:
            pass  # Fail silently — dashboard still works with local insights

    _cache[user_id] = {"data": result, "at": datetime.now(timezone.utc)}
    return result


@router.post("/invalidate")
async def invalidate_cache(payload: dict = Depends(verify_token)):
    """Force-refresh on next request (e.g. after major vault changes)."""
    _cache.pop(payload["sub"], None)
    return {"invalidated": True}


class _DismissRequest(BaseModel):
    note_a_id: str
    note_b_id: str


@router.post("/dismiss")
async def dismiss_connection(
    req: _DismissRequest,
    payload: dict = Depends(verify_token),
):
    """Pause this connection-pair for 14 days. The card disappears
    immediately on the client; the server will skip the pair in the
    next /discovery/daily round."""
    user_id = payload["sub"]
    PausedPairsService.pause(user_id, req.note_a_id, req.note_b_id, days=14)
    # Drop the cached connection so the next /daily call re-computes.
    _cache.pop(user_id, None)
    return {"paused": True}


def _path_to_title(file_path: str) -> str:
    name = file_path.split("/")[-1].replace(".md", "")
    return re.sub(r"[-_]+", " ", name).title()
