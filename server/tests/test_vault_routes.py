"""J4 (Plan v2): Verifiziert dass die Mutations-Endpoints den git
commit+push als BackgroundTask schedulen statt synchron zu pushen.

Ruft die Router-Funktionen direkt mit einer echten BackgroundTasks()
auf und prüft dass nach erfolgreicher Mutation genau ein Task (der
git-Push) eingereiht wurde — der File-Write selbst lief synchron.
"""
import asyncio

import pytest
from fastapi import BackgroundTasks

from routers.vault import (
    NoteDeleteRequest,
    NoteUpdateRequest,
    WingRenameRequest,
    delete_note,
    rename_wing,
    update_note,
)
from services.vault_service import VaultService


@pytest.fixture
def seeded_vault(temp_vault, mock_openai):
    """Vault mit einer Notiz, bereit für Mutation."""
    vault = VaultService.for_user("u1")
    rel = vault.write_note("n1", "Titel", "Body", ["t"], wing="old-wing")
    return vault, rel


def _payload():
    return {"sub": "u1", "email": "u1@test.de"}


def test_update_note_schedules_git_push(seeded_vault):
    vault, rel = seeded_vault
    bg = BackgroundTasks()
    req = NoteUpdateRequest(file_path=rel, title="Neu")
    result = asyncio.run(update_note(req, bg, _payload()))
    assert result["file_path"]
    # genau ein Task: der git-Push
    assert len(bg.tasks) == 1


def test_delete_note_schedules_git_push(seeded_vault):
    vault, rel = seeded_vault
    bg = BackgroundTasks()
    req = NoteDeleteRequest(file_path=rel)
    asyncio.run(delete_note(req, bg, _payload()))
    # File ist sofort weg (synchron), Push deferred
    assert not (vault.vault_path / rel).exists()
    assert len(bg.tasks) == 1


def test_rename_wing_schedules_push_only_when_changed(seeded_vault):
    vault, _ = seeded_vault
    bg = BackgroundTasks()
    req = WingRenameRequest(old_wing="old-wing", new_wing="New Wing")
    result = asyncio.run(rename_wing(req, bg, _payload()))
    assert result["updated"] == 1
    assert len(bg.tasks) == 1


def test_rename_wing_no_push_when_nothing_matched(seeded_vault):
    vault, _ = seeded_vault
    bg = BackgroundTasks()
    req = WingRenameRequest(old_wing="nonexistent", new_wing="X")
    result = asyncio.run(rename_wing(req, bg, _payload()))
    assert result["updated"] == 0
    # kein Match → kein Push geschedult
    assert len(bg.tasks) == 0
