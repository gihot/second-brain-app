import 'package:hive/hive.dart';

part 'note_model.g.dart';

@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  List<String> tags;

  @HiveField(4)
  final DateTime created;

  @HiveField(5)
  DateTime modified;

  @HiveField(6)
  NoteStatus status;

  @HiveField(7)
  ParaCategory para;

  @HiveField(8)
  String? filePath; // relative path in vault

  @HiveField(9)
  List<String> linkedNoteIds; // forward links

  @HiveField(10)
  MemoryHall hall;

  @HiveField(11)
  String? wing; // normalized kebab-case, e.g. "urban-arcanum"

  @HiveField(12)
  ThoughtType thoughtType;

  @HiveField(13)
  String? remindAt; // ISO-8601, only set when thoughtType == reminder

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    required this.created,
    required this.modified,
    this.status = NoteStatus.inbox,
    this.para = ParaCategory.inbox,
    this.filePath,
    this.linkedNoteIds = const [],
    this.hall = MemoryHall.unclassified,
    this.wing,
    this.thoughtType = ThoughtType.standard,
    this.remindAt,
  });

  Note copyWith({
    String? title,
    String? content,
    List<String>? tags,
    DateTime? modified,
    NoteStatus? status,
    ParaCategory? para,
    String? filePath,
    List<String>? linkedNoteIds,
    MemoryHall? hall,
    String? wing,
    bool clearWing = false,
    ThoughtType? thoughtType,
    String? remindAt,
    bool clearRemindAt = false,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      created: created,
      modified: modified ?? this.modified,
      status: status ?? this.status,
      para: para ?? this.para,
      filePath: filePath ?? this.filePath,
      linkedNoteIds: linkedNoteIds ?? this.linkedNoteIds,
      hall: hall ?? this.hall,
      wing: clearWing ? null : (wing ?? this.wing),
      thoughtType: thoughtType ?? this.thoughtType,
      remindAt: clearRemindAt ? null : (remindAt ?? this.remindAt),
    );
  }

  String get relativeTime {
    final diff = DateTime.now().difference(modified);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  String get excerpt {
    final cleaned = content
        .replaceAll(RegExp(r'^---.*?---\s*', dotAll: true), '') // strip frontmatter
        .replaceAll(RegExp(r'#{1,6}\s'), '') // strip headings
        .replaceAll(RegExp(r'\*{1,2}(.*?)\*{1,2}'), r'$1') // strip bold/italic
        .trim();
    return cleaned.length > 120 ? '${cleaned.substring(0, 120)}...' : cleaned;
  }
}

@HiveType(typeId: 1)
enum NoteStatus {
  @HiveField(0)
  inbox,
  @HiveField(1)
  processed,
  @HiveField(2)
  archived,
}

@HiveType(typeId: 2)
enum ParaCategory {
  @HiveField(0)
  inbox,
  @HiveField(1)
  projects,
  @HiveField(2)
  areas,
  @HiveField(3)
  resources,
  @HiveField(4)
  archive,
}

@HiveType(typeId: 7)
enum ThoughtType {
  @HiveField(0)
  standard,
  @HiveField(1)
  reminder,
  @HiveField(2)
  question,
  @HiveField(3)
  idea,
}

@HiveType(typeId: 6)
enum MemoryHall {
  @HiveField(0)
  fact,
  @HiveField(1)
  event,
  @HiveField(2)
  discovery,
  @HiveField(3)
  preference,
  @HiveField(4)
  advice,
  @HiveField(5)
  unclassified,
}
