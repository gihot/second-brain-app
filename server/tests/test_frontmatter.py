"""Tests for the shared YAML-frontmatter parser."""
from services.frontmatter import parse_frontmatter, serialize_frontmatter


def _write(path, text):
    path.write_text(text, encoding="utf-8")


def test_parses_basic_block(tmp_path):
    f = tmp_path / "note.md"
    _write(f, """---
id: abc
title: Hello
tags: ["a", "b"]
---

Body here.
""")
    meta = parse_frontmatter(f, tmp_path)
    assert meta is not None
    assert meta["id"] == "abc"
    assert meta["title"] == "Hello"
    assert meta["tags"] == '["a", "b"]'  # parser returns raw string
    assert meta["content"] == "Body here."
    assert meta["file_path"] == "note.md"


def test_returns_none_without_frontmatter(tmp_path):
    f = tmp_path / "plain.md"
    _write(f, "Just a body, no frontmatter at the top.\n")
    assert parse_frontmatter(f, tmp_path) is None


def test_returns_none_on_missing_file(tmp_path):
    f = tmp_path / "ghost.md"
    assert parse_frontmatter(f, tmp_path) is None


def test_multiline_body_preserved(tmp_path):
    f = tmp_path / "long.md"
    _write(f, """---
id: x
title: Long
---

Line one.

Line two.

Line three.
""")
    meta = parse_frontmatter(f, tmp_path)
    assert meta is not None
    assert "Line one." in meta["content"]
    assert "Line two." in meta["content"]
    assert "Line three." in meta["content"]


def test_relative_file_path_from_vault_root(tmp_path):
    sub = tmp_path / "01-Projects"
    sub.mkdir()
    f = sub / "deep.md"
    _write(f, "---\nid: x\ntitle: Deep\n---\n\nbody")
    meta = parse_frontmatter(f, tmp_path)
    assert meta is not None
    assert meta["file_path"].replace("\\", "/") == "01-Projects/deep.md"


def test_ignores_invalid_yaml_lines(tmp_path):
    f = tmp_path / "ragged.md"
    _write(f, """---
id: abc
title: Foo
this-line-has-no-colon
status: inbox
---

body""")
    meta = parse_frontmatter(f, tmp_path)
    assert meta is not None
    assert meta["id"] == "abc"
    assert meta["status"] == "inbox"
    # The line without ':' is silently skipped.
    assert "this-line-has-no-colon" not in meta


def test_serialize_roundtrip(tmp_path):
    """J6: parse → serialize → parse bleibt stabil (Werte + Reihenfolge)."""
    f = tmp_path / "note.md"
    _write(f, """---
id: abc
title: Hello World
tags: ["a", "b"]
created: 2026-01-01T09:00:00+00:00
status: inbox
---

Body text here.""")
    meta = parse_frontmatter(f, tmp_path)
    body = meta["content"]

    serialized = serialize_frontmatter(meta, body)
    f.write_text(serialized, encoding="utf-8")
    meta2 = parse_frontmatter(f, tmp_path)

    assert meta2["id"] == "abc"
    assert meta2["title"] == "Hello World"
    assert meta2["tags"] == '["a", "b"]'
    assert meta2["created"] == "2026-01-01T09:00:00+00:00"
    assert meta2["status"] == "inbox"
    assert meta2["content"] == "Body text here."


def test_serialize_skips_synthetic_keys(tmp_path):
    """file_path + content dürfen NICHT als Frontmatter-Zeilen landen."""
    meta = {
        "file_path": "00-Inbox/x.md",
        "content": "body",
        "id": "x",
        "title": "T",
    }
    out = serialize_frontmatter(meta, "body")
    assert "file_path:" not in out
    assert "content:" not in out
    assert "id: x" in out
    assert "title: T" in out
