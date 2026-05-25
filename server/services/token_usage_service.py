"""
TokenUsageService — logt LLM-Token-Verbrauch pro Aufruf.

Sammelt jede Anthropic- und OpenAI-Antwort (input_tokens, output_tokens,
model) und persistiert sie zusammen mit User, Agent, Endpoint und einer
geschätzten Kosten-Summe in USD.

Preise sind beim Record-Zeitpunkt eingefroren, damit Preisänderungen die
historische Auswertung nicht verzerren. Modell-Preise liegen in
_MODEL_PRICES als (input_per_1m, output_per_1m). Unbekannte Modelle
werden mit 0$ verbucht und in der UI als „unbekannt" markiert.

Tabelle in derselben auth.db wie users/paused_pairs/resurfacings.
Stdlib sqlite3, kein ORM.
"""
from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


# (input_$_per_1M, output_$_per_1M). Stand Januar 2026. Müssen nur
# aktualisiert werden, wenn Anthropic/OpenAI die Preise ändern — alte
# Records behalten ihren gespeicherten Cost.
_MODEL_PRICES: dict[str, tuple[float, float]] = {
    # Anthropic Claude 4.x — Output ist Embedding-frei, daher das
    # zweite Tupel-Element relevant.
    "claude-opus-4":   (15.0, 75.0),
    "claude-sonnet-4": (3.0,  15.0),
    "claude-haiku-4":  (1.0,  5.0),
    # OpenAI Embeddings — kein Output, daher (in, 0).
    "text-embedding-3-small": (0.02, 0.0),
    "text-embedding-3-large": (0.13, 0.0),
}


def _price_for(model: str) -> tuple[float, float]:
    """Findet den passenden Preis per Prefix-Match. claude-opus-4-7 →
    claude-opus-4, etc. Unbekannte Modelle → (0, 0)."""
    for prefix, prices in _MODEL_PRICES.items():
        if model.startswith(prefix):
            return prices
    return (0.0, 0.0)


def _cost(model: str, input_tokens: int, output_tokens: int) -> float:
    in_price, out_price = _price_for(model)
    return (input_tokens * in_price + output_tokens * out_price) / 1_000_000


class TokenUsageService:
    _db_path: Optional[Path] = None

    @classmethod
    def init(cls, db_path: Path) -> None:
        cls._db_path = db_path
        db_path.parent.mkdir(parents=True, exist_ok=True)
        with cls._conn() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS token_usage (
                    id            INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp     TEXT NOT NULL,
                    user_id       TEXT,
                    provider      TEXT NOT NULL,
                    model         TEXT NOT NULL,
                    agent         TEXT,
                    endpoint      TEXT,
                    input_tokens  INTEGER NOT NULL,
                    output_tokens INTEGER NOT NULL DEFAULT 0,
                    cost_usd      REAL NOT NULL DEFAULT 0
                )
                """
            )
            # Index für die häufigsten Filter (per-day, per-user).
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_usage_timestamp "
                "ON token_usage(timestamp)"
            )

    @classmethod
    def _conn(cls) -> sqlite3.Connection:
        if cls._db_path is None:
            raise RuntimeError("TokenUsageService.init() was not called")
        conn = sqlite3.connect(cls._db_path)
        conn.row_factory = sqlite3.Row
        return conn

    @classmethod
    def record(
        cls,
        provider: str,
        model: str,
        input_tokens: int,
        output_tokens: int = 0,
        user_id: Optional[str] = None,
        agent: Optional[str] = None,
        endpoint: Optional[str] = None,
    ) -> None:
        """Schreibt einen Usage-Eintrag. Defensive — Fehler dürfen den
        eigentlichen LLM-Aufruf niemals brechen, daher try/except außen
        bei den Callern (agent_service / index_service)."""
        if cls._db_path is None:
            return  # init nicht gelaufen → silent skip (z.B. in Unit-Tests)
        cost = _cost(model, input_tokens, output_tokens)
        now_iso = datetime.now(timezone.utc).isoformat()
        with cls._conn() as conn:
            conn.execute(
                """
                INSERT INTO token_usage (
                    timestamp, user_id, provider, model, agent, endpoint,
                    input_tokens, output_tokens, cost_usd
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (now_iso, user_id, provider, model, agent, endpoint,
                 input_tokens, output_tokens, cost),
            )

    @classmethod
    def summary(cls, days: int = 30) -> dict:
        """Aggregierter Verbrauch der letzten `days` Tage in vier Schnitten:
        - by_day:      pro Tag (für Zeitreihen-Charts)
        - by_model:    pro Modell (Anthropic-vs-OpenAI-Verteilung)
        - by_agent:    pro Agent (welcher Agent ist teuer?)
        - by_endpoint: pro Endpoint (welcher Flow ist teuer?)
        - by_user:     pro User (Multi-User-Phase)
        - totals:      Gesamtsumme

        Alles als plain dicts/lists → direkt JSON-serialisierbar.
        """
        if cls._db_path is None:
            return _empty_summary(days)

        from datetime import timedelta
        cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()

        with cls._conn() as conn:
            by_day = [
                {
                    "day": r["day"],
                    "input_tokens": r["input_tokens"],
                    "output_tokens": r["output_tokens"],
                    "cost_usd": r["cost_usd"],
                    "calls": r["calls"],
                }
                for r in conn.execute(
                    """
                    SELECT substr(timestamp, 1, 10) AS day,
                           SUM(input_tokens)   AS input_tokens,
                           SUM(output_tokens)  AS output_tokens,
                           SUM(cost_usd)       AS cost_usd,
                           COUNT(*)            AS calls
                    FROM token_usage
                    WHERE timestamp >= ?
                    GROUP BY day
                    ORDER BY day
                    """,
                    (cutoff,),
                ).fetchall()
            ]

            def _grouped(column: str) -> list[dict]:
                return [
                    {
                        column: r[column] or "unknown",
                        "input_tokens": r["input_tokens"],
                        "output_tokens": r["output_tokens"],
                        "cost_usd": r["cost_usd"],
                        "calls": r["calls"],
                    }
                    for r in conn.execute(
                        f"""
                        SELECT {column},
                               SUM(input_tokens)  AS input_tokens,
                               SUM(output_tokens) AS output_tokens,
                               SUM(cost_usd)      AS cost_usd,
                               COUNT(*)           AS calls
                        FROM token_usage
                        WHERE timestamp >= ?
                        GROUP BY {column}
                        ORDER BY cost_usd DESC
                        """,
                        (cutoff,),
                    ).fetchall()
                ]

            by_model = _grouped("model")
            by_agent = _grouped("agent")
            by_endpoint = _grouped("endpoint")
            by_user = _grouped("user_id")

            totals_row = conn.execute(
                """
                SELECT COALESCE(SUM(input_tokens), 0)  AS input_tokens,
                       COALESCE(SUM(output_tokens), 0) AS output_tokens,
                       COALESCE(SUM(cost_usd), 0)      AS cost_usd,
                       COUNT(*)                        AS calls
                FROM token_usage
                WHERE timestamp >= ?
                """,
                (cutoff,),
            ).fetchone()

        return {
            "days": days,
            "totals": {
                "input_tokens": totals_row["input_tokens"],
                "output_tokens": totals_row["output_tokens"],
                "cost_usd": totals_row["cost_usd"],
                "calls": totals_row["calls"],
            },
            "by_day": by_day,
            "by_model": by_model,
            "by_agent": by_agent,
            "by_endpoint": by_endpoint,
            "by_user": by_user,
        }


def _empty_summary(days: int) -> dict:
    return {
        "days": days,
        "totals": {"input_tokens": 0, "output_tokens": 0,
                   "cost_usd": 0.0, "calls": 0},
        "by_day": [], "by_model": [], "by_agent": [],
        "by_endpoint": [], "by_user": [],
    }
