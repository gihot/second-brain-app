"""
Second Brain Cloud Bridge
FastAPI server that connects the Flutter app to the Git vault and Claude AI agents.
"""
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from auth import verify_token
from routers import capture, search, inbox, vault, agent, discovery


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: clone/pull vault on boot
    from services.vault_service import VaultService
    from services.identity_service import IdentityService
    vault = VaultService.instance()
    await vault.ensure_vault()
    IdentityService.init(vault._vault)
    yield
    # Shutdown: nothing to clean up


app = FastAPI(
    title="Second Brain Cloud Bridge",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount routers — all protected by JWT
app.include_router(capture.router, prefix="/capture", tags=["capture"], dependencies=[Depends(verify_token)])
app.include_router(search.router, prefix="/search", tags=["search"], dependencies=[Depends(verify_token)])
app.include_router(inbox.router, prefix="/inbox", tags=["inbox"], dependencies=[Depends(verify_token)])
app.include_router(vault.router, prefix="/vault", tags=["vault"], dependencies=[Depends(verify_token)])
app.include_router(agent.router, prefix="/agent", tags=["agent"], dependencies=[Depends(verify_token)])
app.include_router(discovery.router, prefix="/discovery", tags=["discovery"], dependencies=[Depends(verify_token)])


@app.get("/health")
async def health():
    return {"status": "ok", "version": "0.1.0"}
