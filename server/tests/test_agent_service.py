"""J6 (Plan v2): AgentService Shared-Singleton.

shared() liefert über mehrere Aufrufe dieselbe Instanz (= ein
wiederverwendeter anthropic-Client-Connection-Pool statt einer neuen
Instanz pro Request). reset_shared() verwirft sie (Test-Hook)."""
from services.agent_service import AgentService


def test_shared_returns_same_instance(temp_vault, mock_anthropic):
    a = AgentService.shared()
    b = AgentService.shared()
    assert a is b


def test_reset_shared_forces_new_instance(temp_vault, mock_anthropic):
    a = AgentService.shared()
    AgentService.reset_shared()
    b = AgentService.shared()
    assert a is not b


def test_constructor_still_public_for_tests(temp_vault, mock_anthropic):
    # Direkte Instanziierung bleibt möglich (Tests, Sonderfälle).
    one = AgentService()
    two = AgentService()
    assert one is not two
