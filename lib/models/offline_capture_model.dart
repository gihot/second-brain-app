import 'package:hive/hive.dart';

part 'offline_capture_model.g.dart';

/// A capture queued locally while offline. Synced when connection returns.
@HiveType(typeId: 3)
class OfflineCapture extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String text;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  bool synced;

  OfflineCapture({
    required this.id,
    required this.text,
    required this.createdAt,
    this.synced = false,
  });
}
