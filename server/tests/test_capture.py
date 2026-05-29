"""J3 (Plan v2): Integrationstest für den Capture-Flow.

Ruft die capture-Endpoint-Funktion direkt auf (nicht via TestClient —
umgeht Rate-Limiter + Lifespan, die hier nichts beitragen). Mockt
Anthropic (Scribe) + OpenAI (Embedding). Prüft die komplette Response-
Shape inkl. similar_notes und dass eine token_usage-Zeile geschrieben
wurde.
"""
import asyncio

import pytest
from fastapi import BackgroundTasks

from routers.capture import CaptureRequest, capture
from services.token_usage_service import TokenUsageService
from services.vault_service import VaultService


def _call_capture(text, note_id=None, user_id="u1"):
    req = CaptureRequest(text=text, note_id=note_id)
    bg = BackgroundTasks()
    payload = {"sub": user_id, "email": "u1@test.de"}
    return asyncio.run(capture(req, bg, payload))


def test_capture_returns_full_shape(temp_vault, mock_anthropic, mock_openai):
    resp = _call_capture("ein neuer Gedanke", note_id="n1")
    assert resp.note_id == "n1"
    assert resp.title == "Mock Title"      # vom mock_anthropic-Stub
    assert resp.tags == ["test"]
    assert resp.hall == "discovery"
    assert resp.para == "00-Inbox"
    assert resp.file_path.endswith(".md")
    # similar_notes ist eine Liste (leer bei erster Notiz — kein Nachbar)
    assert isinstance(resp.similar_notes, list)


def test_capture_writes_note_to_vault(temp_vault, mock_anthropic, mock_openai):
    resp = _call_capture("merk dir das", note_id="n1")
    vault = VaultService.for_user("u1")
    full = vault.vault_path / resp.file_path
    assert full.exists()


def test_capture_records_token_usage(temp_vault, mock_anthropic, mock_openai):
    _call_capture("track meine tokens", note_id="n1")
    summary = TokenUsageService.summary(days=1)
    # mindestens der Anthropic-Scribe-Call ist verbucht
    assert summary["totals"]["calls"] >= 1
    agents = {row["agent"] for row in summary["by_agent"]}
    assert "scribe" in agents


def test_capture_surfaces_similar_after_second_note(
    temp_vault, mock_anthropic, mock_openai
):
    # mock_openai gibt input[i] → vector [i+1,...]. Beide Notizen kriegen
    # bei separaten Single-Embeds jeweils [1,0,0,0,0] → identische
    # Vektoren → cosine 1.0 → über dem 0.75-Schwellwert.
    _call_capture("erste notiz", note_id="n1")
    resp2 = _call_capture("zweite notiz", note_id="n2")
    # n2 sollte n1 als ähnlich sehen (gleicher Mock-Vektor)
    assert len(resp2.similar_notes) >= 1
    assert resp2.similar_notes[0].note_id == "n1"


def test_capture_rejects_empty_text(temp_vault, mock_anthropic, mock_openai):
    from fastapi import HTTPException
    with pytest.raises(HTTPException) as exc:
        _call_capture("   ", note_id="n1")
    assert exc.value.status_code == 422
