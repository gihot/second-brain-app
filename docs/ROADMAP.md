# Second Brain — Roadmap

> Persönliches Engineering-Log. Was haben wir gebaut, was kommt als
> nächstes, was haben wir bewusst aufgeschoben. Für mich-in-6-Monaten.
> Pitch für Außen liegt in [PITCH.md](pitch.md).

## Nordstern

Eine App, die meine Gedanken so aufnimmt wie ich sie habe (Sprache,
schnell, unterwegs) und sie zur richtigen Zeit zurückbringt — auch wenn
ich nicht mehr weiß, wie ich sie genannt habe.

Drei Versprechen:

1. **Reibungslos erfassen.** Voice + Capture-Screen, offline-first,
   keine Pflichtfelder.
2. **Semantisch finden.** „Ich weiß nicht mehr wie ich es nannte" —
   die App findet's trotzdem.
3. **Selbst auftauchen.** Alte Gedanken kommen wieder hoch, wenn sie
   relevant werden — nicht erst wenn ich danach suche.

Alles andere ist Mittel zum Zweck.

---

## Wo wir stehen (Stand: 2026-05)

**Phase 1 — Foundation** ✅ done

- Flutter-Web-PWA + FastAPI-Server über Git-Vault (GitHub).
- 5 Claude-Agents: scribe, seeker, sorter, librarian, connector.
- Offline-First-Cache (Hive) mit Pending-Writes-Queue und
  Conflict-Detection beim Sync.
- Semantische Suche via OpenAI-Embeddings + hybrid mit Keyword-Suche.
- Verwandte-Notizen über Nearest-Neighbor (kein Claude-Call pro
  Aufruf).
- Reminders mit Web-Push-Notifications.
- Server async-clean (kein Event-Loop-Blocking).
- Multi-User-ready Auth (E-Mail+Passwort, JWT, Bootstrap-User,
  Per-User-Vault unter `/data/users/<uid>/`).
- Komplett deutsch, Glass-UI, optionales Hintergrundbild.

**Was die Foundation kann, was sie noch nicht kann:**
- Sie ist *für mich* ein nutzbares Tool.
- Sie ist *nicht* sicher für einen zweiten Nutzer auf demselben Browser
  (Hive-Cache global, siehe Tech-Debt unten).
- Sie hat *kein* Selbst-Auftauchen jenseits eines hübschen Dashboard-
  Elements — das eigentliche dritte Versprechen ist Vorgartendeko.

---

## Phasen-Plan

### Phase 2 — Personal Tool reift (Now)

> Ziel: Die App fühlt sich als *mein* Werkzeug rund an. Kein neuer User-
> Druck, nur Verdichtung dessen was da ist.

- **Resurfacing-System** statt heutiger 3-Zeilen-Vitrine
  ([widgets/ambient_retrieval.dart](../lib/widgets/ambient_retrieval.dart)).
  Spaced-Intervalle, pro-Notiz-Tracking, Engagement-Loop. Eigene
  Sektion auf dem Dashboard und/oder eigener Tab.
- **Passwort ändern** in der App-UI — heute geht das nur über
  Server-DB-Edit. Trivialer Server-Endpoint + Settings-Tile.
- **Pure Logik raus aus den Screens** + Mini-Test-Suite an den
  Datenintegritäts-Stellen:
  - `note_codec_test.dart` (round-trip, Enum-Mappings)
  - Conflict-Detection in vault_provider
  - `_resurfacedNote` und `_statusLine` aus dashboard_screen in
    `lib/utils/dashboard_signals.dart` ziehen, dort testen.
- **CaptureSurface State-Machine.** Vier State-Bools (`_holdRecording`,
  `_pendingHoldCapture`, `_justSaved`, `_saving`) → ein Enum.
- **README/PITCH-Split.** Der aktuelle README ist ein Investor-Pitch.
  Umbenennen zu `docs/pitch.md`, neuer README mit „so läuft das Ding
  lokal" + Architektur-Skizze.

**Definition of Done für Phase 2:** App ist als persönliches Tool
ausgereift, Refactor-Sicherheit durch erste Tests, Resurfacing fühlt
sich wie ein echtes Feature an.

### Phase 3 — Erste echte zweite Nutzer (Next)

> Ziel: Die App darf einem zweiten Menschen in die Hand gedrückt werden,
> ohne dass etwas leakt oder kaputtgeht.

- **Hive-Cache pro User namespacen** (`notes_<user_id>` als Box-Name
  oder Sub-Directory). Heute: zweiter Login auf demselben Browser sieht
  den Cache des ersten. Bekannter Tech-Debt aus dem Auth-Plan.
- **Rate-Limit auf `/auth/login`** (z. B. `slowapi`). Brute-Force ist
  ohne Limit trivial.
- **Server-Tests** mit pytest:
  - `user_service` (bcrypt-Roundtrip, Duplikat-Email, Lookup)
  - `auth` (Token-Roundtrip, Expiry, ungültige Signatur)
  - Lifespan-Bootstrap (idempotent, Migration)
- **Minimale Telemetrie** wenn der erste Beta-Tester ankommt — nicht
  vorher. Wahrscheinlich PostHog oder Plausible (Server-side Events
  reichen).
- **Account-Verwaltungs-UI:** Account löschen, Vault-Export erzwingen
  vor Löschung.
- **Signup-Endpoint** kontrolliert öffnen (Einladungs-Code o. Ä.).

**Definition of Done für Phase 3:** Ein Freund kann die App nutzen
ohne dass ich live debuggen muss, und ich sehe, was er tut.

### Phase 4 — Produkt-Reife (Later)

> Ziel: Die App ist nicht mehr „Tool eines Einzelnen plus Freunde",
> sondern eine echte Plattform.

- **Eigene Repos pro User** statt aktuellem Single-`GITHUB_REPO`-Modell.
  Mit eigener `GitHub-App`-Integration für oauth-basierte Vault-Repos.
- **OAuth** (Google, evtl. Apple) als Login-Methode parallel zu
  E-Mail+Passwort.
- **Magic-Link** statt Passwort als Default (braucht Mail-Provider:
  Resend/Postmark).
- **Passwort-Reset** (braucht Mail-Provider — gleicher Schritt wie
  Magic-Link).
- **Refresh-Tokens** mit kurz-lebigem Access + 90-Tage-Refresh, statt
  heutigem 30-Tage-rolling-JWT.
- **Embedding-Index Migration** auf SQLite-Vec oder Qdrant — sobald
  ein User über ~10k Notizen kratzt, wird die JSON-Variante träge.
- **Mobile-Wrapper** (Capacitor) für echte iOS/Android-Apps mit
  Background-Sync.

---

## Backlog

### Now (akut, klein, freie Hand)

- [ ] README/PITCH-Split (30 min)
- [ ] `note_codec_test.dart` schreiben
- [ ] `_resurfacedNote` + `_statusLine` rausziehen + testen
- [ ] CaptureSurface State-Machine-Refactor
- [ ] Passwort-ändern-Endpoint + Settings-Tile
- [ ] Resurfacing-System (eigener Plan nötig — Server-Schema +
      Selektions-Logik + UI)

### Next (vor erstem zweiten Nutzer Pflicht)

- [ ] Hive-Cache pro User namespacen
- [ ] Rate-Limit auf /auth/login
- [ ] pytest-Setup + Server-Tests (user_service, auth, lifespan)
- [ ] Account-löschen-Flow (mit Pflicht-Export davor)
- [ ] Signup mit Einladungs-Code

### Later (Produkt-Reife)

- [ ] Eigene Repos pro User (GitHub-App)
- [ ] OAuth
- [ ] Magic-Link + Passwort-Reset (braucht Mail-Provider)
- [ ] Refresh-Tokens
- [ ] Embedding-Index → SQLite-Vec
- [ ] Mobile-Wrapper
- [ ] Telemetrie (PostHog oder vergleichbar)
- [ ] CI/CD: GitHub-Action für `flutter analyze` + `flutter test` +
      `pytest` als PR-Gate

### Maybe (Ideen die reifen)

- [ ] Wing-Sharing zwischen Usern („Hey, schau dir mein Garten-Projekt
      an")
- [ ] Public Notes / teilbare Vault-Auszüge
- [ ] Mehrsprachigkeit (heute hardcoded deutsch, Strings müssten
      extrahiert werden)
- [ ] Audio-Notizen als erste-Klasse-Citizen (nicht nur Transkription)
- [ ] Daily-Digest-Mail mit Resurfacing-Empfehlungen
- [ ] Eigenes Embedding-Modell lokal (Ollama o. Ä.) statt OpenAI

---

## Bewusst nicht auf der Roadmap

- **Multi-Workspace pro User** (mehrere Vaults pro Account) — die
  Single-Vault-Pro-User-Annahme ist tief in der Server-Architektur
  verdrahtet, und der Bedarf ist noch theoretisch.
- **Realtime-Sync zwischen mehreren Geräten** — die Pending-Writes-
  Queue + GitHub-Pull alle 5 Minuten reicht für „eine Person, mehrere
  Geräte". Realtime wäre Faktor-10-Mehraufwand.
- **Vollwertiger Editor** (WYSIWYG, Blocks, Slash-Commands) — der
  Markdown-TextField-Ansatz ist bewusst minimal. Capture-Friction ist
  wichtiger als Editor-Power.
- **AI-Agent-Marketplace** (eigene Agents schreiben) — die fünf
  bestehenden Agents reichen für die Versprechen. Mehr ist UI-Overhead.

---

## Notizen zur Roadmap selbst

- Diese Datei wird gepflegt wenn Phase 2 fertig ist, dann wieder beim
  ersten Beta-Tester, dann beim ersten externen Sign-Up. Sie ist *kein*
  living document mit täglichen Updates.
- Backlog-Häkchen pflegen ist optional — die Phasen-Beschreibung ist
  die Wahrheit.
- Wenn ein Item in „Later" plötzlich akut wird, wandert es nach „Now"
  und der Grund wird in zwei Sätzen daneben notiert.
