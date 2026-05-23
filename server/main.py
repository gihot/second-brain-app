"""
Second Brain Cloud Bridge
FastAPI server that connects the Flutter app to the Git vault and Claude AI agents.
"""
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from config import get_settings
from rate_limit import limiter
from routers import agent, auth, capture, discovery, inbox, search, vault
from services.user_service import UserService


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: init the user DB and optionally bootstrap the first user.
    settings = get_settings()
    data_root = Path(settings.data_root)
    UserService.init(data_root / "auth.db")

    if (
        UserService.count() == 0
        and settings.bootstrap_email
        and settings.bootstrap_password
    ):
        try:
            uid = UserService.create(
                settings.bootstrap_email, settings.bootstrap_password
            )
            print(f"Bootstrap user created: {settings.bootstrap_email} ({uid})")

            # Migrate any legacy single-vault under the new user namespace.
            legacy_vault = Path(settings.vault_path)            # e.g. /data/vault
            new_vault = data_root / "users" / uid / "vault"
            if legacy_vault.exists() and not new_vault.exists():
                new_vault.parent.mkdir(parents=True, exist_ok=True)
                legacy_vault.rename(new_vault)
                print(f"Migrated legacy vault → {new_vault}")

            legacy_index = data_root / "embedding_index.json"
            new_index = data_root / "users" / uid / "embedding_index.json"
            if legacy_index.exists() and not new_index.exists():
                new_index.parent.mkdir(parents=True, exist_ok=True)
                legacy_index.rename(new_index)
                print(f"Migrated legacy index → {new_index}")
        except Exception as e:
            # Loud-fail in the logs, but don't take the server down — the
            # operator can fix env vars + restart.
            print(f"Bootstrap failed: {e}")

    yield
    # Shutdown: nothing to clean up.


app = FastAPI(
    title="Second Brain Cloud Bridge",
    version="0.2.0",
    lifespan=lifespan,
)

# slowapi: shared limiter instance lives in rate_limit.py so routers can
# decorate their handlers. Exception handler turns RateLimitExceeded into
# HTTP 429.
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Auth is Authorization-Header based, not cookies — credentials are not needed.
# Explicit origin list avoids the spec-illegal "*" + credentials combination.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://gihot.github.io",  # GitHub Pages deploy
    ],
    allow_origin_regex=r"^http://localhost(:\d+)?$",  # local `flutter run`
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Auth router — login/signup are open by design; /me uses verify_token
# internally as a per-handler dependency.
app.include_router(auth.router, prefix="/auth", tags=["auth"])

# Data routers — each handler pulls verify_token + extracts user_id from
# the payload itself. No router-level dependency to avoid the empty-payload
# pattern of the previous setup.
app.include_router(capture.router, prefix="/capture", tags=["capture"])
app.include_router(search.router, prefix="/search", tags=["search"])
app.include_router(inbox.router, prefix="/inbox", tags=["inbox"])
app.include_router(vault.router, prefix="/vault", tags=["vault"])
app.include_router(agent.router, prefix="/agent", tags=["agent"])
app.include_router(discovery.router, prefix="/discovery", tags=["discovery"])


@app.get("/health")
async def health():
    return {"status": "ok", "version": "0.2.0"}
