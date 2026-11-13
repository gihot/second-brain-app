# second-brain-app

Persönliche Notiz-App mit Voice-Capture, KI-Klassifizierung und semantischer
Suche. Flutter-Web-PWA + FastAPI-Backend, Notizen als Markdown in einem
GitHub-Vault.

---

## Lokal starten

### Voraussetzungen

- Flutter SDK ≥ 3.x (`flutter doctor` sollte grün sein)
- Python 3.11+
- Ein GitHub-Repo als Vault + GitHub PAT mit `repo`-Scope
- Anthropic API Key (für KI-Agenten)

### Server

```bash
cd server
pip install -r requirements.txt
```

`.env` im `server/`-Verzeichnis anlegen (Pflicht-Variablen):

```
GITHUB_TOKEN=ghp_...
GITHUB_REPO=<user>/<vault-repo>
ANTHROPIC_API_KEY=sk-ant-...
JWT_SECRET=<32-byte-hex>
VAULT_PATH=/tmp/vault
```

```bash
uvicorn main:app --reload --env-file .env
# → http://localhost:8000
```

### Flutter-Web

```bash
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8000
```

---

## Architektur

```
Flutter Web/PWA
    │
    │  REST + JWT
    ▼
FastAPI (server/)
    ├── Git-Vault (GitHub) — Markdown-Notizen, gepusht als Commits
    ├── 5 Claude-Agenten: scribe · seeker · sorter · librarian · connector
    ├── OpenAI-Embeddings — semantische Suche (optional, ohne Key nur Keyword)
    └── SQLite auth.db — User, Sessions, Token-Usage, Resurfacing-Tracking
    
Flutter-Cache
    └── Hive (offline-first, per-User-namespaced) — Notizen, Pending-Writes-Queue
```

**Datenfluss Capture:**
1. Flutter → `POST /capture` mit Text (+ optionalem `remindAt`)
2. Scribe-Agent klassifiziert (Titel, Tags, PARA, ThoughtType)
3. Datei als Markdown in Vault-Repo geschrieben, Git-Push im Hintergrund
4. Response mit `note_id`, `file_path`, semantisch ähnlichen Notizen

---

## Tests

```bash
# Flutter
flutter test

# Server
cd server && pytest tests/
```

---

## Docs

| Datei | Inhalt |
|-------|--------|
| `server/DEPLOY.md` | Fly.io / Railway / Render Deployment-Setup |
| `docs/pitch.md` | Produktvision + Investoren-Deck |
| `docs/ROADMAP.md` | Feature-Roadmap + Tech-Debt-Backlog |
| `docs/PLAN.md` | Aktueller Implementierungsplan |
