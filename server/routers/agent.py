"""POST /agent/{name} — Run any agent directly (for future Chat screen)."""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from services.agent_service import AgentService

router = APIRouter()


class AgentRequest(BaseModel):
    message: str
    context: dict | None = None


@router.post("/{name}")
async def run_agent(name: str, req: AgentRequest):
    allowed = {"scribe", "seeker", "sorter", "librarian", "connector"}
    if name not in allowed:
        raise HTTPException(status_code=404, detail=f"Agent '{name}' not found")

    agent = AgentService()
    try:
        result = await agent.run(name, req.message, req.context)
        return result
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"Agent '{name}' not configured")
