"""J3 (Plan v2): Tests für IndexService — das Embedding-Index.

Nutzt mock_openai (deterministische Vektoren: input[i] → [i+1,0,0,0,0]).
index_note → related_notes Round-trip, Hash-Determinismus,
Persist-Reload-Zyklus.
"""
import pytest

from services.index_service import IndexService


@pytest.fixture
def index(temp_vault, mock_openai):
    return IndexService.for_user("u1")


def _meta(note_id, title="T", content="body", tags=None):
    return {
        "id": note_id,
        "file_path": f"00-Inbox/{note_id}.md",
        "title": title,
        "content": content,
        "tags": tags or [],
    }


def test_index_note_stores_vector(index):
    index.index_note(_meta("n1"))
    assert "n1" in index._index["notes"]
    assert index._index["notes"]["n1"]["vector"] == [1.0, 0.0, 0.0, 0.0, 0.0]


def test_index_note_skips_when_hash_unchanged(index):
    index.index_note(_meta("n1", content="same"))
    first_vector = index._index["notes"]["n1"]["vector"]
    # zweiter Aufruf mit gleichem Inhalt → kein Re-Embed (Hash gleich)
    index.index_note(_meta("n1", content="same"))
    assert index._index["notes"]["n1"]["vector"] == first_vector


def test_hash_is_deterministic(index):
    h1 = IndexService._hash("Titel", "Inhalt", ["a", "b"])
    h2 = IndexService._hash("Titel", "Inhalt", ["a", "b"])
    h3 = IndexService._hash("Titel", "Anders", ["a", "b"])
    assert h1 == h2
    assert h1 != h3


def test_related_notes_excludes_self(index):
    index.index_note(_meta("n1"))
    index.index_note(_meta("n2"))
    index.index_note(_meta("n3"))
    related = index.related_notes("n1", limit=5)
    ids = {r["note_id"] for r in related}
    assert "n1" not in ids
    assert ids == {"n2", "n3"}


def test_related_notes_returns_similarity_and_title(index):
    index.index_note(_meta("n1", title="First"))
    index.index_note(_meta("n2", title="Second"))
    related = index.related_notes("n1", limit=5)
    assert len(related) == 1
    assert related[0]["title"] == "Second"
    assert "similarity" in related[0]
    assert isinstance(related[0]["similarity"], float)


def test_index_survives_persist_reload(index):
    index.index_note(_meta("n1"))
    index.index_note(_meta("n2"))
    # Neue Instanz (simuliert Server-Restart): lädt vom Disk.
    IndexService._instances.clear()
    reloaded = IndexService.for_user("u1")
    assert "n1" in reloaded._index["notes"]
    assert "n2" in reloaded._index["notes"]


def test_remove_note_drops_entry(index):
    index.index_note(_meta("n1"))
    assert "n1" in index._index["notes"]
    index.remove_note("00-Inbox/n1.md")
    assert "n1" not in index._index["notes"]


def test_semantic_search_returns_file_paths(index):
    index.index_note(_meta("n1"))
    index.index_note(_meta("n2"))
    paths = index.semantic_search("query", limit=5)
    assert all(p.endswith(".md") for p in paths)
    assert len(paths) == 2


def test_disabled_index_is_noop(temp_vault, monkeypatch):
    """Ohne OpenAI-Key ist alles no-op, search fällt auf keyword zurück."""
    from config import Settings, get_settings
    monkeypatch.setattr(Settings, "openai_api_key", "", raising=False)
    get_settings.cache_clear()
    IndexService._instances.clear()

    svc = IndexService.for_user("u1")
    assert svc.enabled is False
    svc.index_note(_meta("n1"))  # no-op, kein Crash
    assert svc.related_notes("n1", limit=5) == []
    # hybrid_search fällt auf keyword_results zurück, mit score angereichert
    kw = [{"file_path": "a.md", "id": "n1"}]
    result = svc.hybrid_search("q", kw, limit=5)
    assert len(result) == 1
    assert "score" in result[0]
