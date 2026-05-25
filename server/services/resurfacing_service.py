"""
ResurfacingService — persistente Gedächtnis-Spur für „Taucht wieder auf".

Wave 3 ersetzt die alte Pseudo-Zufallslogik (siehe lib/utils/dashboard_signals.dart
`resurfacedNote`) durch eine echte Score-basierte Auswahl mit per-Notiz-Tracking.

**Produkt-Prinzipien (aus der Resurfacing-Spec):**
- Ruhig statt fordernd — niemals mehr als ein paar Karten, kein Badge.
- Kontext > Chronologie — nicht „hier ist etwas Altes", sondern „könnte
  gerade wieder relevant für dich sein".
- Überraschung ist wertvoll — bewusster `random_jitter` im Score gegen
  sterile Vorhersagbarkeit.
- Lernen ohne Arbeit — Signal ist „geöffnet" (nicht Like/Rating).
  Mark-Engaged → 30-Tage-Pause, damit dieselbe Notiz nicht morgen
  wieder hochkommt.

**Score-Formel (v1, intentional einfach):**
    age_factor       = ältere Notizen werden relevanter (capped bei ~60d)
    gap_factor       = lange nicht mehr gezeigt → höherer Score
    low_interaction  = nie gezeigt? +1 Bonus (gibt Vergessenes eine Chance)
    times_shown_pen  = -0.2 je Vor-Zeigung (Anti-Wiederholung)
    pause_killswitch = pause_until > now → komplett raus
    random_jitter    = ±0.5 (Überraschung, verhindert deterministische Reihen)

Tabelle lebt in derselben `auth.db` wie users + paused_pairs — Persistence
bleibt trivial. Stdlib sqlite3, kein ORM.
"""
from __future__ import annotations

import math
import random
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional


# Pause-Dauer nach „geöffnet"-Signal. Plan-Doc nannte 30d, deckt sich mit
# der Resurfacing-Spec („nicht morgen wieder die gleiche Notiz") — lange
# genug, dass die Notiz wirklich aus dem Kopf raus ist, kurz genug, dass
# sie irgendwann wieder auftauchen kann.
_ENGAGED_PAUSE_DAYS = 30

# Notizen unter 7 Tagen sind noch „frisch im Kopf" — kein Resurface.
# Stimmt mit der bisherigen Pseudo-Zufall-Logik überein.
_MIN_AGE_DAYS = 7


class ResurfacingService:
    _db_path: Optional[Path] = None

    @classmethod
    def init(cls, db_path: Path) -> None:
        cls._db_path = db_path
        db_path.parent.mkdir(parents=True, exist_ok=True)
        with cls._conn() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS resurfacings (
                    user_id         TEXT NOT NULL,
                    note_id         TEXT NOT NULL,
                    last_shown_at   TEXT,
                    times_shown     INTEGER NOT NULL DEFAULT 0,
                    last_engaged_at TEXT,
                    pause_until     TEXT,
                    PRIMARY KEY (user_id, note_id)
                )
                """
            )

    @classmethod
    def _conn(cls) -> sqlite3.Connection:
        if cls._db_path is None:
            raise RuntimeError("ResurfacingService.init() was not called")
        conn = sqlite3.connect(cls._db_path)
        conn.row_factory = sqlite3.Row
        return conn

    # ── Selektion ─────────────────────────────────────────────────────────────

    @classmethod
    def select_today(
        cls,
        user_id: str,
        candidates: list[dict],
        limit: int = 3,
        now: Optional[datetime] = None,
    ) -> list[dict]:
        """Wählt bis zu `limit` Notizen für das heutige Resurface aus.

        `candidates` ist eine Liste Notiz-Dicts mit mindestens `id` und
        `created_at` (ISO-8601). Aufrufer ist typischerweise der Router,
        der vault.get_all_notes() durchreicht.

        Schreibt **nicht** in die DB — `mark_shown` ist ein eigener
        Aufruf, damit ein Read-Only-Preview/Debug möglich bleibt.
        """
        t = now or datetime.now(timezone.utc)
        states = cls._load_states(user_id)

        scored: list[tuple[float, dict]] = []
        for note in candidates:
            note_id = note.get("id")
            if not note_id:
                continue
            # Frontmatter speichert „created", einige ältere/externe Pfade
            # liefern „created_at" — beide tolerieren.
            created = _parse_iso(note.get("created") or note.get("created_at"))
            if created is None:
                continue
            age_days = (t - created).total_seconds() / 86400
            if age_days < _MIN_AGE_DAYS:
                continue

            state = states.get(note_id)
            if state and _is_paused(state, t):
                continue

            score = _compute_score(age_days, state, t)
            scored.append((score, note))

        scored.sort(key=lambda x: x[0], reverse=True)
        return [note for _, note in scored[:limit]]

    @classmethod
    def _load_states(cls, user_id: str) -> dict[str, sqlite3.Row]:
        with cls._conn() as conn:
            rows = conn.execute(
                "SELECT * FROM resurfacings WHERE user_id = ?",
                (user_id,),
            ).fetchall()
        return {r["note_id"]: r for r in rows}

    # ── Tracking ──────────────────────────────────────────────────────────────

    @classmethod
    def mark_shown(cls, user_id: str, note_ids: list[str]) -> None:
        """Upsert: last_shown_at = now, times_shown += 1."""
        if not note_ids:
            return
        now_iso = datetime.now(timezone.utc).isoformat()
        with cls._conn() as conn:
            for note_id in note_ids:
                conn.execute(
                    """
                    INSERT INTO resurfacings (user_id, note_id, last_shown_at, times_shown)
                    VALUES (?, ?, ?, 1)
                    ON CONFLICT(user_id, note_id) DO UPDATE SET
                        last_shown_at = excluded.last_shown_at,
                        times_shown   = times_shown + 1
                    """,
                    (user_id, note_id, now_iso),
                )

    @classmethod
    def mark_engaged(cls, user_id: str, note_id: str) -> None:
        """Notiz wurde aus dem Resurface-Vorschlag geöffnet → 30-Tage-
        Pause. Signal: „hat den Zweck erfüllt, jetzt eine Weile Ruhe".
        """
        now = datetime.now(timezone.utc)
        pause = (now + timedelta(days=_ENGAGED_PAUSE_DAYS)).isoformat()
        with cls._conn() as conn:
            conn.execute(
                """
                INSERT INTO resurfacings (
                    user_id, note_id, last_engaged_at, pause_until, times_shown
                ) VALUES (?, ?, ?, ?, 0)
                ON CONFLICT(user_id, note_id) DO UPDATE SET
                    last_engaged_at = excluded.last_engaged_at,
                    pause_until     = excluded.pause_until
                """,
                (user_id, note_id, now.isoformat(), pause),
            )

    @classmethod
    def purge_expired(cls) -> int:
        """Entfernt Zeilen, deren pause_until lange in der Vergangenheit
        liegt UND die seit >180 Tagen nicht mehr gezeigt wurden. Sparsam
        — der Großteil bleibt, das ist ja unser Gedächtnis. Nur echte
        Karteileichen werden weggeräumt."""
        cutoff = (datetime.now(timezone.utc) - timedelta(days=180)).isoformat()
        with cls._conn() as conn:
            cur = conn.execute(
                """
                DELETE FROM resurfacings
                WHERE (pause_until IS NULL OR pause_until <= ?)
                  AND (last_shown_at IS NULL OR last_shown_at <= ?)
                """,
                (cutoff, cutoff),
            )
            return cur.rowcount


# ── Helpers ───────────────────────────────────────────────────────────────────


def _parse_iso(s: Optional[str]) -> Optional[datetime]:
    if not s:
        return None
    try:
        # frontmatter created_at kann mit/ohne TZ kommen — beide tolerieren
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return None


def _is_paused(state: sqlite3.Row, now: datetime) -> bool:
    pause = state["pause_until"]
    if not pause:
        return False
    try:
        return datetime.fromisoformat(pause) > now
    except Exception:
        return False


def _compute_score(age_days: float, state: Optional[sqlite3.Row],
                   now: datetime) -> float:
    """Score-Formel (siehe Modul-Docstring). Niedrigerer Score → später."""
    # age_factor: 0 bei genau _MIN_AGE_DAYS, steigt bis 1.5 bei ~67 Tagen,
    # bleibt dann konstant. Sehr alte Notizen sind nicht *noch* relevanter.
    age_factor = min((age_days - _MIN_AGE_DAYS) / 60.0, 1.5)

    times_shown = state["times_shown"] if state else 0
    last_shown_at = _parse_iso(state["last_shown_at"]) if state else None

    # gap_factor: log1p(Tage seit letztem Zeigen). Nie gezeigt → log1p(999),
    # gestern gezeigt → log1p(1) ≈ 0.7. Dämpft die rohe Tage-Zahl, damit
    # 365 vs. 500 nicht riesig auseinanderliegen.
    if last_shown_at is None:
        gap_days = 999
    else:
        gap_days = max((now - last_shown_at).total_seconds() / 86400, 0)
    gap_factor = math.log1p(gap_days) * 0.5

    # low_interaction_bonus: nie gezeigt → +1. Gibt komplett vergessenen
    # Gedanken eine echte Chance, in den Top-3 zu landen.
    low_interaction_bonus = 1.0 if times_shown == 0 else 0.0

    # times_shown_penalty: jede vorherige Anzeige drückt den Score.
    # Reagiert träge — 5 Anzeigen = -1.0, das ist ein deutlicher Dämpfer
    # aber kein Killswitch (`pause_until` ist der Killswitch).
    times_shown_penalty = -0.2 * times_shown

    # random_jitter: ±0.5 — bewusst breit. Resurfacing-Spec verlangt
    # „leichte Überraschung", damit das System nicht zur sterilen Liste
    # wird. Determinismus pro Tag wäre möglich (seeded random) — bewusst
    # nicht gemacht, weil der User die Karten innerhalb eines Tages eh
    # nur einmal sieht (Provider cached).
    random_jitter = (random.random() - 0.5) * 1.0

    return (
        age_factor
        + gap_factor
        + low_interaction_bonus
        + times_shown_penalty
        + random_jitter
    )
