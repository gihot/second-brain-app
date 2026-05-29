"""J3 (Plan v2): Tests für VaultService — die zentrale File-I/O-Schicht.

Round-trips (write → read → update → move), Frontmatter-Stabilität,
Path-Traversal-Schutz. Kein Git (temp_vault setzt github_repo="" →
_git_commit no-op't, weil kein .git existiert). Kein OpenAI nötig für
die reinen File-Operationen — index_note schluckt Fehler intern, aber
mit mock_openai bleibt's sauber.
"""
import pytest

from services.frontmatter import parse_frontmatter
from services.vault_service import VaultService


@pytest.fixture
def vault(temp_vault, mock_openai):
    """VaultService für einen Test-User. mock_openai damit der
    index_note-Hook nicht gegen echtes OpenAI läuft."""
    return VaultService.for_user("u1")


def test_write_note_creates_file_with_frontmatter(vault):
    rel = vault.write_note(
        "n1", "Mein Titel", "Der Inhalt", ["tag1", "tag2"],
        para="00-Inbox", hall="discovery",
    )
    assert rel.endswith(".md")
    full = vault.vault_path / rel
    assert full.exists()

    meta = parse_frontmatter(full, vault.vault_path)
    assert meta["id"] == "n1"
    assert meta["title"] == "Mein Titel"
    assert meta["hall"] == "discovery"
    assert meta["content"] == "Der Inhalt"


def test_write_note_roundtrips_through_get_all(vault):
    vault.write_note("n1", "Erste", "Inhalt eins", ["a"])
    vault.write_note("n2", "Zweite", "Inhalt zwei", ["b"])
    notes = vault.get_all_notes()
    ids = {n["id"] for n in notes}
    assert ids == {"n1", "n2"}


def test_update_note_preserves_frontmatter_parsability(vault):
    rel = vault.write_note("n1", "Titel", "Body", ["a"])
    new_rel = vault.update_note(
        rel, title="Neuer Titel", content="Neuer Body", tags=["x", "y"],
    )
    meta = parse_frontmatter(vault.vault_path / new_rel, vault.vault_path)
    assert meta is not None  # bleibt parsbar
    assert meta["title"] == "Neuer Titel"
    assert meta["content"] == "Neuer Body"
    assert meta["id"] == "n1"  # id bleibt stabil


def test_update_note_keeps_unchanged_fields(vault):
    rel = vault.write_note(
        "n1", "Titel", "Body", ["a"], hall="fact", wing="my-wing",
    )
    new_rel = vault.update_note(rel, content="Anderer Body")
    meta = parse_frontmatter(vault.vault_path / new_rel, vault.vault_path)
    # hall + wing dürfen durch ein content-only-Update nicht verloren gehen
    assert meta["hall"] == "fact"
    assert meta["wing"] == "my-wing"
    assert meta["content"] == "Anderer Body"


def test_update_note_moves_file_on_para_change(vault):
    rel = vault.write_note("n1", "Titel", "Body", ["a"], para="00-Inbox")
    assert "00-Inbox" in rel
    new_rel = vault.update_note(rel, para="03-Resources")
    assert "03-Resources" in new_rel
    # alte Datei ist weg, neue existiert
    assert not (vault.vault_path / rel).exists()
    assert (vault.vault_path / new_rel).exists()


def test_move_note_updates_status_and_para(vault):
    rel = vault.write_note("n1", "Titel", "Body", ["a"], para="00-Inbox")
    new_rel = vault.move_note(rel, "01-Projects", "processed")
    meta = parse_frontmatter(vault.vault_path / new_rel, vault.vault_path)
    assert meta["para"] == "01-Projects"
    assert meta["status"] == "processed"


def test_delete_note_removes_file(vault):
    rel = vault.write_note("n1", "Titel", "Body", ["a"])
    assert (vault.vault_path / rel).exists()
    vault.delete_note(rel)
    assert not (vault.vault_path / rel).exists()


def test_safe_path_rejects_traversal(vault):
    vault.write_note("n1", "Titel", "Body", ["a"])  # ensures vault dir exists
    with pytest.raises(ValueError):
        vault._safe_path("../../etc/passwd")


def test_search_finds_by_token(vault):
    vault.write_note("n1", "GraphQL Notizen", "über das n+1 problem", ["api"])
    vault.write_note("n2", "Kochrezept", "Nudeln mit Sauce", ["food"])
    results = vault.search("graphql")
    assert len(results) >= 1
    assert results[0]["id"] == "n1"


def test_rename_wing_updates_all_matching(vault):
    vault.write_note("n1", "A", "x", ["t"], wing="old-wing")
    vault.write_note("n2", "B", "y", ["t"], wing="old-wing")
    vault.write_note("n3", "C", "z", ["t"], wing="other")
    count = vault.rename_wing("old-wing", "New Wing")
    assert count == 2
    wings = {w["wing"]: w["count"] for w in vault.get_wings()}
    assert "new-wing" in wings
    assert wings["new-wing"] == 2
