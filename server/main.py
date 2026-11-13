"""
Second Brain Cloud Bridge
FastAPI server that connects the Flutter app to the Git vault and Claude AI agents.
"""
import shutil
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from config import get_settings
from rate_limit import limiter
from routers import (
    admin, agent, auth, capture, discovery, inbox, push, reminders, resurfacing,
    search, vault,
)
from services.index_service import IndexService
from services.invite_service import InviteService
from services.paused_pairs_service import PausedPairsService
from services.push_service import PushService
from services.reminder_service import ReminderService
from services.resurfacing_service import ResurfacingService
from services.token_usage_service import TokenUsageService
from services.user_service import UserService


def purge_due_user_data(data_root: Path) -> int:
    """Wave 4.2: läuft beim Server-Start UND auf jedem Login. Findet
    User mit abgelaufenem pending_deletion_at und entfernt **alles**:
    - paused_pairs, resurfacings, token_usage (per service-method)
    - embedding-Index + vault-Verzeichnis (Dateisystem)
    - users-Row (zuletzt — damit die Auth ihn nicht mehr findet)

    Idempotent + defensive: Fehler bei einem Teil dürfen die anderen
    nicht blockieren. Returns die Anzahl gelöschter User.
    """
    due = UserService.get_due_deletions()
    for uid in due:
        for fn in (
            lambda: PausedPairsService.delete_user_data(uid),
            lambda: ResurfacingService.delete_user_data(uid),
            lambda: TokenUsageService.delete_user_data(uid),
            lambda: InviteService.delete_user_data(uid),
            lambda: PushService.delete_user_data(uid),
            lambda: ReminderService.delete_user_data(uid),
        ):
            try:
                fn()
            except Exception as e:
                print(f"purge step failed for {uid}: {e}")
        # Filesystem-Cleanup: data_root/users/<uid>/ enthält vault +
        # embedding_index.json + ggf. identity.md.
        user_dir = data_root / "users" / uid
        try:
            if user_dir.exists():
                shutil.rmtree(user_dir, ignore_errors=True)
        except Exception as e:
            print(f"vault dir removal failed for {uid}: {e}")
        try:
            IndexService.forget_user(uid)
        except Exception as e:
            print(f"index cache eviction failed for {uid}: {e}")
        try:
            UserService.hard_delete(uid)
            print(f"hard-deleted user {uid}")
        except Exception as e:
            print(f"hard delete failed for {uid}: {e}")
    return len(due)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: init the user DB and optionally bootstrap the first user.
    settings = get_settings()
    data_root = Path(settings.data_root)
    UserService.init(data_root / "auth.db")
    PausedPairsService.init(data_root / "auth.db")
    ResurfacingService.init(data_root / "auth.db")
    TokenUsageService.init(data_root / "auth.db")
    InviteService.init(data_root / "auth.db")
    PushService.init(data_root / "auth.db")
    ReminderService.init(data_root / "auth.db")

    # Wave 4.2: Einmal beim Server-Start fällige Hard-Deletes abräumen.
    # Lazy-Variante in /auth/login behandelt den „nie wieder Server-
    # Neustart"-Fall, dieser Hook fängt User die nie wieder einloggen.
    try:
        n = purge_due_user_data(data_root)
        if n:
            print(f"startup: hard-deleted {n} expired user(s)")
    except Exception as e:
        print(f"startup hard-delete sweep failed: {e}")

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
        # J8: `null`-Origin (file://) wieder entfernt. Das Usage-Dashboard
        # wird jetzt same-origin unter GET /admin/dashboard ausgeliefert.
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
app.include_router(resurfacing.router, prefix="/resurfacing", tags=["resurfacing"])
app.include_router(admin.router, prefix="/admin", tags=["admin"])
app.include_router(push.router, prefix="/push", tags=["push"])
app.include_router(reminders.router, prefix="/reminders", tags=["reminders"])


@app.get("/health")
async def health():
    return {"status": "ok", "version": "0.2.0"}
