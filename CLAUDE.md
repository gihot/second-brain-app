# Second Brain App

## Mission

Gedanken reibungslos erfassen. Semantisch wiederfinden. Selbst auftauchen lassen.
Alles andere ist Mittel zum Zweck.

---

## Working Rules

Read `docs/PLAN.md` before doing anything. If code contradicts PLAN.md, trust the
code for current behavior and PLAN.md for intended next work. One PLAN item per
session. Do not start a second item in the same session. Do not touch files
unrelated to the current PLAN item.

---

## Destructive Action Guard

Never call or modify these paths unless the current PLAN item explicitly requires it:

- `dangerouslyClearAllNotes`
- `DELETE /auth/me`
- Any code that deletes vault files or user data
- Force-push or Git history rewrite

Soft-Delete is not yet implemented. These calls are permanent and unrecoverable.
If a destructive path must be touched: stop, explain why, wait for confirmation
before editing.

---

## Before Claiming Completion

```bash
flutter analyze && flutter test
cd server && pytest tests/
```

Both must pass before claiming the PLAN item is complete. If a command cannot run
because of environment issues, report:

- the exact command
- the exact error
- what remains unverified

Never claim tests passed unless they actually ran.

---

## Stack

- **Client:** Flutter Web/PWA, Hive (offline-first, per-user-namespaced boxes)
- **Server:** FastAPI, SQLite (`auth.db`), Git-Vault via GitHub (async push)
- **Agents:** scribe · seeker · sorter · librarian · connector (Anthropic)
- **Search:** OpenAI-Embeddings + Keyword-Hybrid
- **Auth:** Email + Password, JWT 30d, per-user vault at `/data/users/<uid>/`

---

## Likely Entry Points

```
lib/providers/vault_provider.dart      vault CRUD, sync, conflict-detection
lib/services/cache_service.dart        Hive wrapper, per-user boxes
lib/services/api_service.dart          REST client, JWT, onUnauthorized callback
lib/providers/auth_provider.dart       AuthSession, login/logout
lib/utils/dashboard_signals.dart       pure logic (resurfacedNote, statusLine)
lib/widgets/capture_surface.dart       capture state machine
lib/widgets/ambient_retrieval.dart     resurfacing UI

server/services/vault_service.py       Git-Vault, frontmatter, CRUD
server/services/index_service.py       embedding index
server/services/resurfacing_service.py resurfacing tracking
server/services/frontmatter.py         single source for frontmatter parsing
server/routers/                        FastAPI endpoints
server/tests/                          pytest
test/                                  Flutter tests
```

These paths may drift. Read the actual file before assuming its contents.

---

## Conventions

- Hive boxes: `notes_<uid>`, `capture_queue_<uid>`, `meta_<uid>`
- All endpoints use `Depends(verify_token)`, `payload["sub"]` = user_id
- Git-push runs in `BackgroundTasks` (async) — file-write is synchronous
- Frontmatter parsing: always use `server/services/frontmatter.py`, never inline

---

## Context Budget

If context feels overloaded or `/compact` fails:

- stop immediately
- summarize current state briefly
- do not start new edits
- tell the user to run `/clear`

---

## Session End (after completing a PLAN item)

1. Append to `docs/DONE.md`:

```
## YYYY-MM-DD — <item id> (<short title>)
- Built: <what was built>
- Tests: <commands run and result>
- Commit: <hash or "not committed">
```

2. Strike or remove the completed item in `docs/PLAN.md`.
3. Tell the user: "Session done. Run /clear before starting the next item."
4. Stop. Do not continue into the next PLAN item.

---

## When a New Plan Is Handed Over

1. Overwrite `docs/PLAN.md` completely. Do not append.
2. Stop. Do not inspect or edit code.
3. Tell the user: "Plan updated. Run /clear to start clean."
