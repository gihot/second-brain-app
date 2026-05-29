"""Shared pytest config — makes `server/` importable so tests can do
`from services.user_service import UserService` instead of fragile paths.

J1 (Plan v2): erweitert um drei Fixtures als Test-Rahmen für alles
datenschreibende. Vor J2 nutzbar.

  - `temp_vault`        — frisches data_root, alle 5 Services initialisiert
  - `mock_anthropic`    — Stub für anthropic.AsyncAnthropic, deterministische
                          Scribe-Response inkl. usage-Block
  - `mock_openai`       — Stub für openai.OpenAI, deterministische Vektoren
                          inkl. usage.total_tokens

Tests die LLM-Pfade ausüben (capture, agent, embedding) brauchen beide
Mock-Fixtures plus temp_vault.
"""
import sys
from pathlib import Path

import pytest

_ROOT = Path(__file__).resolve().parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))


# ── temp_vault ────────────────────────────────────────────────────────────────


@pytest.fixture
def temp_vault(tmp_path, monkeypatch):
    """Frisches data_root pro Test. Setzt Settings-Felder direkt (statt
    env-Vars, weil Settings die env-Vars beim Modul-Import einmal liest
    und danach cached). Initialisiert alle SQLite-Services auf eine
    Test-eigene auth.db. Räumt am Ende den Instance-Cache der per-User-
    Services, damit Tests sich nicht gegenseitig vergiften."""
    from config import Settings, get_settings
    from services.index_service import IndexService
    from services.invite_service import InviteService
    from services.paused_pairs_service import PausedPairsService
    from services.resurfacing_service import ResurfacingService
    from services.token_usage_service import TokenUsageService
    from services.user_service import UserService
    from services.vault_service import VaultService

    monkeypatch.setattr(Settings, "data_root", str(tmp_path), raising=False)
    monkeypatch.setattr(Settings, "vault_path", str(tmp_path / "vault"), raising=False)
    monkeypatch.setattr(Settings, "openai_api_key", "test-openai-key", raising=False)
    monkeypatch.setattr(Settings, "anthropic_api_key", "test-anthropic-key", raising=False)
    monkeypatch.setattr(Settings, "github_repo", "", raising=False)  # no git push
    monkeypatch.setattr(Settings, "github_token", "", raising=False)
    get_settings.cache_clear()

    db = tmp_path / "auth.db"
    UserService.init(db)
    PausedPairsService.init(db)
    ResurfacingService.init(db)
    TokenUsageService.init(db)
    InviteService.init(db)

    # Per-User-Instance-Caches resetten — alte Test-Instanzen würden
    # sonst auf alte vault-Pfade zeigen.
    VaultService._instances.clear()
    IndexService._instances.clear()

    yield tmp_path

    get_settings.cache_clear()
    VaultService._instances.clear()
    IndexService._instances.clear()


# ── mock_anthropic ────────────────────────────────────────────────────────────


class _MockAnthropicBlock:
    """Mimics anthropic.types.TextBlock."""

    type = "text"

    def __init__(self, text: str):
        self.text = text


class _MockAnthropicUsage:
    def __init__(self, input_tokens: int = 120, output_tokens: int = 80):
        self.input_tokens = input_tokens
        self.output_tokens = output_tokens


class _MockAnthropicResponse:
    """Shape-kompatibel mit anthropic.types.Message."""

    def __init__(
        self,
        text: str = '{"title": "Mock Title", "tags": ["test"], '
                    '"para": "00-Inbox", "hall": "discovery", '
                    '"thought_type": "standard", "remind_at": null, '
                    '"suggested_wing": ""}',
        model: str = "claude-sonnet-4-6",
        input_tokens: int = 120,
        output_tokens: int = 80,
    ):
        self.model = model
        self.content = [_MockAnthropicBlock(text)]
        self.usage = _MockAnthropicUsage(input_tokens, output_tokens)


class _MockAnthropicMessages:
    def __init__(self, response_factory):
        self._factory = response_factory

    async def create(self, **kwargs):
        return self._factory()


class _MockAnthropicClient:
    """Wird vom Test über mock_anthropic-Fixture konfigurierbar gemacht.
    `_response_factory` ist mutable damit Tests die Antwort gezielt
    pro Aufruf ändern können (z.B. unterschiedliche Token-Counts)."""

    _response_factory = staticmethod(_MockAnthropicResponse)

    def __init__(self, *args, **kwargs):
        self.messages = _MockAnthropicMessages(_MockAnthropicClient._response_factory)


@pytest.fixture
def mock_anthropic(monkeypatch):
    """Replaces anthropic.AsyncAnthropic mit dem Mock-Client. Tests die
    spezifische Responses brauchen, können `_MockAnthropicClient.
    _response_factory = lambda: _MockAnthropicResponse(text=...)` setzen.

    Wenn das echte `anthropic`-Modul nicht installiert ist (minimales
    Test-Env), wird ein Fake-Modul in sys.modules injiziert. So laufen
    Tests auch ohne API-SDK-Installation.
    """
    import sys
    import types

    # Per-Test fresh factory damit andere Tests nicht beeinflusst werden
    _MockAnthropicClient._response_factory = staticmethod(_MockAnthropicResponse)

    if "anthropic" in sys.modules:
        monkeypatch.setattr(sys.modules["anthropic"], "AsyncAnthropic",
                            _MockAnthropicClient)
    else:
        fake = types.ModuleType("anthropic")
        fake.AsyncAnthropic = _MockAnthropicClient
        monkeypatch.setitem(sys.modules, "anthropic", fake)
    yield _MockAnthropicClient


# ── mock_openai ───────────────────────────────────────────────────────────────


class _MockEmbedDatum:
    def __init__(self, vec):
        self.embedding = vec


class _MockEmbedUsage:
    def __init__(self, total: int):
        self.total_tokens = total


class _MockEmbedResponse:
    def __init__(self, n_inputs: int, model: str = "text-embedding-3-small"):
        self.model = model
        # Deterministisch: input[i] → vector [(i+1), 0, 0, 0, 0]. Klein
        # genug für schnelle Tests, unterscheidbar genug für Nearest-
        # Neighbor-Asserts.
        self.data = [_MockEmbedDatum([float(i + 1), 0.0, 0.0, 0.0, 0.0])
                     for i in range(n_inputs)]
        self.usage = _MockEmbedUsage(n_inputs * 10)


class _MockEmbeddings:
    def create(self, model, input):
        n = len(input) if isinstance(input, list) else 1
        return _MockEmbedResponse(n, model=model)


class _MockOpenAIClient:
    def __init__(self, *args, **kwargs):
        self.embeddings = _MockEmbeddings()


@pytest.fixture
def mock_openai(monkeypatch):
    """Replaces openai.OpenAI mit dem Mock. Setzt zusätzlich gecachte
    Client-Referenzen in bestehenden IndexService-Instanzen zurück,
    damit auch Tests die in derselben Test-Session laufen den Mock
    bekommen statt einer alten Real-Instanz.

    Wenn das echte `openai`-Modul nicht installiert ist, wird ein Fake
    in sys.modules injiziert (analog mock_anthropic).
    """
    import sys
    import types

    if "openai" in sys.modules:
        monkeypatch.setattr(sys.modules["openai"], "OpenAI", _MockOpenAIClient)
    else:
        fake = types.ModuleType("openai")
        fake.OpenAI = _MockOpenAIClient
        monkeypatch.setitem(sys.modules, "openai", fake)

    from services.index_service import IndexService
    for inst in IndexService._instances.values():
        inst._client = None
    yield _MockOpenAIClient
