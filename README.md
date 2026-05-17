# Second Brain — Pitch Deck

> **Dein aktives externes Gedächtnis.**
> Ein Gedanke ist in 3 Sekunden sicher gespeichert — und taucht wieder auf, wenn er relevant wird.

*Working Title — Branding offen. Investoren-Deck, Stand: Mai 2026.*
*Felder in `[…]` sind vor dem Pitch mit echten Zahlen/Namen zu füllen.*

---

## 1 · Vision

**Die meisten Tools verwalten Wissen. Wir lassen dich denken.**

Notion, Obsidian, Evernote sind Datenbanken — sie verlangen Disziplin:
Ordner, Tags, Struktur. Second Brain ist kein Wissens-Archiv, sondern ein
**aktives externes Gedächtnis**: Du wirfst einen Gedanken rein, das System
erinnert sich mit dir.

> „Such nach deinem Wissen." → **„Dein Wissen taucht auf, wenn es zählt."**

---

## 2 · Problem

Menschen haben den ganzen Tag Gedanken — Ideen, Aufgaben, Erinnerungen —
und **verlieren sie**. Zwei konkrete Reibungspunkte:

- **Capture-Friktion.** Bestehende Tools brauchen Setup: In welchen Ordner?
  Welcher Tag? Welches Projekt? In den 5 Sekunden Zögern ist der Gedanke weg.
- **Retrieval-Versagen.** Selbst was gespeichert wurde, wird nie wiedergefunden —
  weil man nicht mehr weiß, *wie* man es genannt hat.

Folge: Notiz-Apps werden zu Friedhöfen. Der Nutzer kapituliert und vertraut
wieder dem eigenen, überlasteten Kopf.

**Zielgruppe spürt das täglich:** Wissensarbeiter, Studierende, Selbstständige,
Handwerks- & Meister-Profis mit vielen parallelen Verpflichtungen, sowie
neurodivergente Nutzer (ADHS), für die externe Entlastung kein Luxus ist.

---

## 3 · Lösung

**Second Brain — radikal einfaches Capture, intelligentes Wiederfinden.**

1. **3-Sekunden-Capture.** Tippen oder — Voice-First — Mic halten, sprechen,
   loslassen. Fertig. **Keine Ordner, keine Tags, keine Organisation.**
2. **KI ordnet im Hintergrund.** Jeder Gedanke wird automatisch klassifiziert:
   Aufgabe? Erinnerung? Idee? Kontext, Zeitbezug, Projekt — ohne Zutun.
3. **Ambient Retrieval.** Das Dashboard *bedient* keine Suche — es lässt
   Wissen *auftauchen*: „Vor 2 Wochen dachtest du über X nach", „Das passt
   zu 3 älteren Gedanken".
4. **Semantische Suche & KI-Dialog**, wenn der Nutzer aktiv fragt —
   „Frag dein Gehirn".

Produktivität ist **Seiteneffekt**, nicht Ziel: „Samstag Holz kaufen" wird
automatisch zur terminierten Aufgabe — ohne dass der Nutzer ein Projekt anlegt.

---

## 4 · Produkt — Status heute

**Kein Konzept — ein funktionierendes Produkt.** Live als installierbare PWA.

- ✅ 3-Sekunden-Capture inkl. Voice-First Hold-to-Talk
- ✅ KI-Agenten: Suchen · Ordnen · Verbinden (Anthropic Claude)
- ✅ Ambient Retrieval & automatische Verknüpfungen zwischen Gedanken
- ✅ Erinnerungen mit Browser-Benachrichtigungen
- ✅ Offline-first — funktioniert ohne Netz, synct automatisch nach
- ✅ Daten als reines Markdown im eigenen Git-Vault des Nutzers

**Tech-Stack:** Flutter (Web/PWA, eine Codebase für alle Plattformen),
FastAPI-Backend, Anthropic Claude für KI, Git-basierter Markdown-Vault.
Schlank, portabel, kein Vendor-Lock-in.

---

## 5 · Markt & Zielgruppe

**Kategorie:** Personal Knowledge Management (PKM) + KI-Produktivität —
einer der am schnellsten wachsenden Software-Bereiche.

- **Referenzpunkte:** Notion (zuletzt ~10 Mrd. $ bewertet), Obsidian,
  Evernote, sowie KI-native Newcomer (Mem, Reflect, Granola).
- **TAM/SAM/SOM:** `[mit recherchierten Zahlen füllen — z. B. PKM-Software
  global, deutschsprachiger Erstmarkt, realistisch erreichbare Nutzer Jahr 1–3]`.

**Primäre Zielgruppe (Beachhead):**
- Selbstständige & Handwerks-/Meister-Profis mit vielen parallelen Baustellen
- Studierende in Prüfungsphasen
- Neurodivergente Nutzer (ADHS) — externe Entlastung als Kernbedürfnis

Diese Gruppen haben den höchsten Leidensdruck und die geringste Toleranz
für Organisations-Overhead — perfekter Einstiegsmarkt.

---

## 6 · USP — Warum wir gewinnen

| | Notion / Obsidian | Apple Notes / Keep | **Second Brain** |
|---|---|---|---|
| Capture-Friktion | hoch (Struktur nötig) | niedrig | **minimal (3 Sek, Voice)** |
| Wiederfinden | manuelle Suche/Tags | schwache Suche | **Ambient + semantisch** |
| Organisation | Nutzer-Disziplin | keine | **KI übernimmt** |
| Datenhoheit | proprietär | proprietär | **eigener Git-Vault, Markdown** |
| Mentales Modell | Datenbank | Zettelkasten | **lebendes Gedächtnis** |

**Kern-USP:** Wir sind das einzige Tool, das *gleichzeitig* die Capture-Hürde
auf nahezu null senkt **und** das Wiederfinden aktiv übernimmt — ohne dem
Nutzer Arbeit aufzubürden. Daten gehören dem Nutzer (offenes Markdown).

---

## 7 · Business Model

**Freemium-Abo, B2C-first.**

- **Free** — begrenzte Captures/Monat, Basis-Retrieval, lokale Nutzung.
  Niedrigste Einstiegshürde, PWA = kein App-Store nötig.
- **Pro — `[~5–9 €]` / Monat** — unbegrenzte KI-Klassifizierung, semantische
  Suche, Cross-Device-Sync, Voice, Erinnerungen.
- **Bring-Your-Own-Key (Option)** — Power-User hinterlegen eigenen
  KI-API-Key → senkt unsere variablen Kosten, erhöht Marge.

**Spätere Erlöslinien:** Team-/B2B-Tarife, Lifetime-Lizenz als Launch-Angebot.

**Unit Economics:** Hauptkostenblock sind KI-Inferenz-Calls — durch Caching,
On-Device-Vorfilterung und das BYO-Key-Modell deckelbar. `[Ziel-Marge,
CAC/LTV nach erster Kohorte einsetzen]`.

---

## 8 · Marketing & Vertrieb

**Founder-led, Community-getrieben, null Install-Friktion (PWA).**

- **Warteliste + öffentliches Bauen.** Build-in-Public auf X/LinkedIn/
  YouTube — die Produktphilosophie ist selbst erzählenswert.
- **Community-Einstieg.** PKM-, Produktivitäts- und ADHS-Communities
  (Reddit, Discord) — dort sitzt der akute Leidensdruck.
- **Beta mit Power-Usern** der Beachhead-Gruppe → Testimonials, Iteration,
  Mundpropaganda.
- **PWA-Vorteil:** Link teilen → in 2 Sekunden installiert, kein App-Store-
  Review, kein 30-%-Cut.
- **Content-SEO** auf „Gedanken festhalten", „Zweites Gehirn", „Notiz-App
  ohne Ordner".

**Erste 100/1.000 Nutzer:** Warteliste → Beta-Kohorte → Community-Launch.
`[konkrete Kanal-Ziele & Zeitachse einsetzen]`.

---

## 9 · Team

**[Dein Name] — Founder & Builder**
`[Kurzprofil: Hintergrund, warum du dieses Problem verstehst — z. B. selbst
betroffen, technisch + systemisch denkend, hast das Produkt eigenständig
bis zum funktionsfähigen Stand gebaut.]`

Warum dieses Team das Richtige ist: Das Produkt existiert bereits als
lauffähige App — gebaut mit echter Nutzer-Empathie für die Zielgruppe.
Vision und Umsetzung kommen aus einer Hand.

**Geplante Schlüssel-Rollen (mit Funding):**
`[z. B. KI/Backend-Engineer, Growth/Marketing — auflisten was fehlt.]`

> *Ehrlich halten: Investoren wissen, dass Solo-Gründer existieren. Wichtig
> ist zu zeigen, wen du als Nächstes holst und warum.*

---

## 10 · Roadmap

**Heute:** Funktionsfähige PWA — Capture, KI-Agenten, Ambient Retrieval,
Erinnerungen, Offline-Sync.

- **Q`[x]` — Semantisches Retrieval.** Embedding-Index für echte Bedeutungs-
  Suche („ich weiß nicht mehr wie ich's nannte").
- **Q`[x]` — Multi-User & Public Launch.** Accounts, Auth, Mandantenfähigkeit;
  öffentlicher Launch der Beachhead-Zielgruppe.
- **Q`[x]` — Native Mobile Apps** (iOS/Android aus derselben Flutter-Codebase).
- **Q`[x]` — Team-/B2B-Tarife.**

---

## 11 · Finanzen & Ask

**Wir raisen `[Betrag]` (Pre-Seed / Seed) für `[x]` Monate Runway.**

**Mittelverwendung:**
- `[~%]` Produkt & Engineering — semantisches Retrieval, Multi-User, Mobile
- `[~%]` KI-/Infrastruktur-Kosten während des Wachstums
- `[~%]` Marketing & Community / erste Nutzer-Kohorten
- `[~%]` Operatives / Puffer

**Meilensteine bis zur nächsten Runde:**
`[z. B. X zahlende Nutzer, Y % Retention nach 4 Wochen, Z € MRR.]`

---

## Kontakt

`[Name · E-Mail · Demo-Link (gihot.github.io/second-brain-app) · Kalender-Link]`

---

<sub>Dieses Deck ersetzt die frühere technische README. Entwickler-Setup-
Hinweise siehe `server/DEPLOY.md` und Code-Kommentare.</sub>
