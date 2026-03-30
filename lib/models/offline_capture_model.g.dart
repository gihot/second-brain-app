// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_capture_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineCaptureAdapter extends TypeAdapter<OfflineCapture> {
  @override
  final int typeId = 3;

  @override
  OfflineCapture read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineCapture(
      id: fields[0] as String,
      text: fields[1] as String,
      createdAt: fields[2] as DateTime,
      synced: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineCapture obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineCaptureAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
