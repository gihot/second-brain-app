"""POST /agent/{name} — Run any agent with automatic vault context injection."""
import asyncio
from datetime import date
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from services.agent_service import AgentService
from services.vault_service import VaultService
from services.index_service import IndexService

router = APIRouter()


class AgentRequest(BaseModel):
    message: str
    context: dict | None = None


@router.post("/{name}")
async def run_agent(name: str, req: AgentRequest):
    allowed = {"scribe", "seeker", "sorter", "librarian", "connector"}
    if name not in allowed:
        raise HTTPException(status_code=404, detail=f"Agent '{name}' not found")

    vault = VaultService.instance()

    # Inject vault data per agent type
    vault_context: dict = {}
    if name == "seeker":
        kw = await asyncio.to_thread(vault.search, req.message, 20)
        vault_context = {
            "today": date.today().isoformat(),
            "vault_notes": await asyncio.to_thread(
                IndexService.instance().hybrid_search, req.message, kw, 20
            ),
        }
    elif name == "librarian":
        vault_context = {
            "today": date.today().isoformat(),
            "vault_status": vault.get_status(),
            "all_notes": await asyncio.to_thread(vault.get_all_notes, 200),
        }
    elif name == "connector":
        vault_context = {
            "all_notes": await asyncio.to_thread(vault.get_all_notes, 50),
        }

    # Merge: vault data first, then client context (wing/hall scope) on top
    merged = {**vault_context, **(req.context or {})}

    agent = AgentService()
    try:
        result = await agent.run(name, req.message, merged or None)
        return result
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"Agent '{name}' not configured")
