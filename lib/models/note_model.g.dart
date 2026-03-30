// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 0;

  @override
  Note read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Note(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      tags: (fields[3] as List).cast<String>(),
      created: fields[4] as DateTime,
      modified: fields[5] as DateTime,
      status: fields[6] as NoteStatus,
      para: fields[7] as ParaCategory,
      filePath: fields[8] as String?,
      linkedNoteIds: (fields[9] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.tags)
      ..writeByte(4)
      ..write(obj.created)
      ..writeByte(5)
      ..write(obj.modified)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.para)
      ..writeByte(8)
      ..write(obj.filePath)
      ..writeByte(9)
      ..write(obj.linkedNoteIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NoteStatusAdapter extends TypeAdapter<NoteStatus> {
  @override
  final int typeId = 1;

  @override
  NoteStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NoteStatus.inbox;
      case 1:
        return NoteStatus.processed;
      case 2:
        return NoteStatus.archived;
      default:
        return NoteStatus.inbox;
    }
  }

  @override
  void write(BinaryWriter writer, NoteStatus obj) {
    switch (obj) {
      case NoteStatus.inbox:
        writer.writeByte(0);
        break;
      case NoteStatus.processed:
        writer.writeByte(1);
        break;
      case NoteStatus.archived:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ParaCategoryAdapter extends TypeAdapter<ParaCategory> {
  @override
  final int typeId = 2;

  @override
  ParaCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ParaCategory.inbox;
      case 1:
        return ParaCategory.projects;
      case 2:
        return ParaCategory.areas;
      case 3:
        return ParaCategory.resources;
      case 4:
        return ParaCategory.archive;
      default:
        return ParaCategory.inbox;
    }
  }

  @override
  void write(BinaryWriter writer, ParaCategory obj) {
    switch (obj) {
      case ParaCategory.inbox:
        writer.writeByte(0);
        break;
      case ParaCategory.projects:
        writer.writeByte(1);
        break;
      case ParaCategory.areas:
        writer.writeByte(2);
        break;
      case ParaCategory.resources:
        writer.writeByte(3);
        break;
      case ParaCategory.archive:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParaCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
