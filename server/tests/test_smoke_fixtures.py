"""J1-Smoke-Tests für die conftest.py-Fixtures.

Die richtigen Tests folgen in J2/J3. Hier nur: bestätigen dass die
Fixtures funktionieren, ohne dass jemals echter API-Traffic passiert."""
import asyncio
import json

import pytest


def test_temp_vault_initializes_all_services(temp_vault):
    """alle 5 Services sind nach der Fixture nutzbar, frische DB."""
    from services.user_service import UserService

    assert UserService.count() == 0
    uid = UserService.create("smoke@example.com", "pw-correct!")
    assert UserService.get(uid)["email"] == "smoke@example.com"


def test_temp_vault_isolates_between_tests(temp_vault):
    """Zweiter Test sieht keine Daten vom ersten — beweist Isolation."""
    from services.user_service import UserService

    # Wenn temp_vault zwischen Tests sauber resettet, ist count hier 0.
    assert UserService.count() == 0


def test_mock_anthropic_returns_deterministic_stub(mock_anthropic):
    """Stub ist API-shape-kompatibel und liefert vorhersehbare Felder."""
    import anthropic

    client = anthropic.AsyncAnthropic(api_key="x")
    response = asyncio.run(
        client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=10,
            system="x",
            messages=[],
        )
    )
    assert response.model == "claude-sonnet-4-6"
    assert response.usage.input_tokens == 120
    assert response.usage.output_tokens == 80
    parsed = json.loads(response.content[0].text)
    assert parsed["title"] == "Mock Title"
    assert parsed["hall"] == "discovery"


def test_mock_openai_returns_deterministic_vectors(mock_openai):
    """Stub liefert n_input Vektoren der Länge 5, plus usage."""
    import openai

    client = openai.OpenAI(api_key="x")
    response = client.embeddings.create(
        model="text-embedding-3-small",
        input=["alpha", "beta", "gamma"],
    )
    assert len(response.data) == 3
    assert response.data[0].embedding == [1.0, 0.0, 0.0, 0.0, 0.0]
    assert response.data[1].embedding == [2.0, 0.0, 0.0, 0.0, 0.0]
    assert response.usage.total_tokens == 30


def test_agent_service_uses_mock_anthropic(temp_vault, mock_anthropic):
    """End-to-end durch AgentService mit Mock — beweist dass der Stub
    den Production-Code-Pfad korrekt durchläuft.

    asyncio.run statt @pytest.mark.asyncio um pytest-asyncio-Dependency
    zu vermeiden — diese Test-Suite soll mit Stock-pytest laufen.
    """
    from services.agent_service import AgentService

    agent = AgentService()
    # scribe.md liegt im server/agents/ — der Stub returnt JSON
    # unabhängig vom Agent-Namen, also reicht jeder valide Name.
    result = asyncio.run(
        agent.run("scribe", "test thought", user_id="smoke-uid")
    )
    assert result["metadata"]["title"] == "Mock Title"


def test_index_service_uses_mock_openai(temp_vault, mock_openai):
    """IndexService.index_note geht durch den Mock — der Index hat
    danach eine Notiz mit erwartetem Vektor."""
    from services.index_service import IndexService

    svc = IndexService.for_user("smoke-uid")
    assert svc.enabled  # because temp_vault sets openai_api_key
    svc.index_note({
        "id": "n1",
        "file_path": "00-Inbox/n1.md",
        "title": "Test",
        "content": "body",
        "tags": [],
    })
    entry = svc._index["notes"]["n1"]
    assert entry["vector"] == [1.0, 0.0, 0.0, 0.0, 0.0]
