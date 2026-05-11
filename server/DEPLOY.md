# Server Deployment

Single source of truth: any platform that runs Docker with a persistent
volume can host this server. The Dockerfile takes its build context from
the `server/` directory (NOT repo root). All runtime state lives in a
single volume mounted at `/data`.

## Required environment variables

| Var | Purpose |
|---|---|
| `GITHUB_TOKEN` | PAT with `repo` scope — server pushes vault commits with this |
| `GITHUB_REPO` | `<user>/<repo>` of the vault repo (e.g. `gihot/brain-vault`) |
| `ANTHROPIC_API_KEY` | For Scribe / Connector / Seeker / Sorter agents |
| `JWT_SECRET` | Random 32-byte hex, used to sign session tokens |
| `VAULT_PATH` | Where to clone the vault — **must be on the persistent volume** (e.g. `/data/vault`) |
| `PORT` | Defaults to 8000; many platforms inject this automatically |

> **Why persistent:** the server clones `GITHUB_REPO` into `VAULT_PATH`
> on first boot, then pushes/pulls there. If the directory disappears
> (container restart on ephemeral filesystem), the next boot re-clones —
> safe but slow. Persistent volume avoids the re-clone and keeps any
> uncommitted-but-staged state.

## Health check
`GET /health` — used by both Fly.io and Railway configs.

---

## Fly.io (recommended)

Config lives in [`fly.toml`](fly.toml). See the comment block at the top
of that file for first-time setup steps. Subsequent deploys: `flyctl deploy`.

**Volume sizing:** 1 GB is plenty for the vault repo + git history at
hobby scale. Bump if your vault grows past a few hundred MB of markdown.

**Cost:** Hobby tier — `auto_stop_machines = "stop"` makes the machine
suspend after idle, costs typically $0–3/month.

## Render

Render has no native persistent disk on the free tier — you need a paid
"Disk Add-on" for the vault clone to survive restarts.

Setup outline:
1. New Web Service → "Build from Repo" → point to this repo
2. Root Directory: `server`, Dockerfile path: `Dockerfile`
3. Add Disk → mount path `/data`, size 1 GB
4. Add env vars from the table above with `VAULT_PATH=/data/vault`
5. Health Check Path: `/health`

## Coolify (self-hosted)

If you have a VPS or a home server running Coolify:
1. New Resource → Docker Compose
2. Use a compose file like:
   ```yaml
   services:
     api:
       build:
         context: ./server
       ports:
         - "8000:8000"
       volumes:
         - vault:/data
       environment:
         VAULT_PATH: /data/vault
         GITHUB_TOKEN: ${GITHUB_TOKEN}
         GITHUB_REPO: ${GITHUB_REPO}
         ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
         JWT_SECRET: ${JWT_SECRET}
   volumes:
     vault: {}
   ```
3. Set the env vars in Coolify's UI, deploy.

## Local docker (debugging)

```bash
docker build -t second-brain-server ./server
docker run --rm -p 8000:8000 \
  -v "$(pwd)/data:/data" \
  -e VAULT_PATH=/data/vault \
  -e GITHUB_TOKEN=ghp_... \
  -e GITHUB_REPO=gihot/brain-vault \
  -e ANTHROPIC_API_KEY=sk-ant-... \
  -e JWT_SECRET=$(openssl rand -hex 32) \
  second-brain-server
```

Test: `curl http://localhost:8000/health` should return 200.

---

## After deploy

1. Note the public URL (e.g. `https://second-brain-server.fly.dev`).
2. In the Flutter app: **Settings → CONNECTION → API Server** → paste URL.
3. Same screen → **API Token** → paste a token if your server uses auth
   (see `server/auth.py` for the scheme).
4. **Verbindung testen** in the same section confirms the server is reachable.
5. **Pending Writes** tile shows queued edits — if non-zero, tap →
   **Alle erneut versuchen** to flush them.

## Migration from Railway
1. Deploy to the new platform per the steps above.
2. Set the same `GITHUB_TOKEN` and `GITHUB_REPO` so it clones the same
   vault.
3. Switch the app's API URL → done. No data migration needed; the vault
   repo on GitHub is the source of truth.
4. (Optional) Delete the dead Railway service.
