import 'package:flutter_test/flutter_test.dart';

import 'package:second_brain/models/note_codec.dart';
import 'package:second_brain/models/note_model.dart';

void main() {
  group('Enum ↔ server-string roundtrip', () {
    test('statusToServer / statusFromServer identity', () {
      for (final s in NoteStatus.values) {
        expect(statusFromServer(statusToServer(s)), s);
      }
    });

    test('paraToServer / paraFromServer identity', () {
      for (final p in ParaCategory.values) {
        expect(paraFromServer(paraToServer(p)), p);
      }
    });

    test('hallToServer / hallFromServer identity', () {
      for (final h in MemoryHall.values) {
        expect(hallFromServer(hallToServer(h)), h);
      }
    });

    test('thoughtTypeToServer / thoughtTypeFromServer identity', () {
      for (final t in ThoughtType.values) {
        expect(thoughtTypeFromServer(thoughtTypeToServer(t)), t);
      }
    });
  });

  group('paraFromServer tolerates server + short forms', () {
    test('folder form', () {
      expect(paraFromServer('01-Projects'), ParaCategory.projects);
      expect(paraFromServer('02-Areas'), ParaCategory.areas);
      expect(paraFromServer('03-Resources'), ParaCategory.resources);
      expect(paraFromServer('04-Archive'), ParaCategory.archive);
      expect(paraFromServer('00-Inbox'), ParaCategory.inbox);
    });

    test('short form', () {
      expect(paraFromServer('projects'), ParaCategory.projects);
      expect(paraFromServer('areas'), ParaCategory.areas);
      expect(paraFromServer('resources'), ParaCategory.resources);
      expect(paraFromServer('archive'), ParaCategory.archive);
    });

    test('case insensitivity', () {
      expect(paraFromServer('PROJECTS'), ParaCategory.projects);
      expect(paraFromServer('01-projects'), ParaCategory.projects);
    });

    test('unknown / null → inbox fallback', () {
      expect(paraFromServer(null), ParaCategory.inbox);
      expect(paraFromServer(''), ParaCategory.inbox);
      expect(paraFromServer('garbage'), ParaCategory.inbox);
    });
  });

  group('noteFromMap', () {
    test('returns null on missing id', () {
      expect(
        noteFromMap({'title': 'foo', 'content': 'bar'}),
        isNull,
      );
    });

    test('returns null on missing title', () {
      expect(
        noteFromMap({'id': 'abc', 'content': 'bar'}),
        isNull,
      );
    });

    test('returns null on empty id', () {
      expect(noteFromMap({'id': '', 'title': 'foo'}), isNull);
    });

    test('builds Note with defaults for optional fields', () {
      final n = noteFromMap({'id': 'abc', 'title': 'foo'});
      expect(n, isNotNull);
      expect(n!.id, 'abc');
      expect(n.title, 'foo');
      expect(n.content, '');
      expect(n.tags, isEmpty);
      expect(n.status, NoteStatus.inbox);
      expect(n.para, ParaCategory.inbox);
      expect(n.hall, MemoryHall.unclassified);
      expect(n.thoughtType, ThoughtType.standard);
      expect(n.wing, isNull);
      expect(n.remindAt, isNull);
    });

    test('handles tags as a real list', () {
      final n = noteFromMap({
        'id': 'abc',
        'title': 'foo',
        'tags': ['a', 'b', 'c'],
      });
      expect(n!.tags, ['a', 'b', 'c']);
    });

    test('handles tags as a stringified list (server form)', () {
      final n = noteFromMap({
        'id': 'abc',
        'title': 'foo',
        'tags': '["a", "b"]',
      });
      expect(n!.tags, ['a', 'b']);
    });

    test('treats empty wing / remind_at as null', () {
      final n = noteFromMap({
        'id': 'abc',
        'title': 'foo',
        'wing': '',
        'remind_at': '',
      });
      expect(n!.wing, isNull);
      expect(n.remindAt, isNull);
    });
  });

  group('noteToServerMap', () {
    Note _sample({String? wing, String? remindAt}) => Note(
          id: 'id-1',
          title: 'Title',
          content: 'body',
          tags: ['x', 'y'],
          created: DateTime(2026, 1, 1),
          modified: DateTime(2026, 1, 2),
          status: NoteStatus.processed,
          para: ParaCategory.projects,
          filePath: '01-Projects/Title.md',
          hall: MemoryHall.discovery,
          wing: wing,
          thoughtType: ThoughtType.idea,
          remindAt: remindAt,
        );

    test('always-present keys', () {
      final m = noteToServerMap(_sample());
      expect(m['op'], 'update');
      expect(m['file_path'], '01-Projects/Title.md');
      expect(m['title'], 'Title');
      expect(m['content'], 'body');
      expect(m['tags'], ['x', 'y']);
      expect(m['status'], 'processed');
      expect(m['para'], '01-Projects');
      expect(m['hall'], 'discovery');
      expect(m['thought_type'], 'idea');
    });

    test('omits wing/remind_at when null', () {
      final m = noteToServerMap(_sample());
      expect(m.containsKey('wing'), isFalse);
      expect(m.containsKey('remind_at'), isFalse);
    });

    test('includes wing/remind_at when set', () {
      final m = noteToServerMap(
          _sample(wing: 'urban-arcanum', remindAt: '2026-05-01T09:00:00Z'));
      expect(m['wing'], 'urban-arcanum');
      expect(m['remind_at'], '2026-05-01T09:00:00Z');
    });
  });

  group('Map → Note → Map round-trip', () {
    test('server-canonical payload survives the round-trip', () {
      final payload = {
        'id': 'abc',
        'title': 'My Note',
        'content': 'hello',
        'tags': ['a', 'b'],
        'created': '2026-01-01T10:00:00.000Z',
        'modified': '2026-01-02T11:30:00.000Z',
        'status': 'archived',
        'para': '02-Areas',
        'hall': 'preference',
        'wing': 'garten-projekt',
        'thought_type': 'reminder',
        'remind_at': '2026-06-01T08:00:00Z',
        'file_path': '02-Areas/My Note.md',
      };
      final note = noteFromMap(payload)!;
      final back = noteToServerMap(note);
      expect(back['title'], payload['title']);
      expect(back['content'], payload['content']);
      expect(back['tags'], payload['tags']);
      expect(back['status'], payload['status']);
      expect(back['para'], payload['para']);
      expect(back['hall'], payload['hall']);
      expect(back['wing'], payload['wing']);
      expect(back['thought_type'], payload['thought_type']);
      expect(back['remind_at'], payload['remind_at']);
      expect(back['file_path'], payload['file_path']);
    });
  });
}
