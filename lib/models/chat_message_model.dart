import 'package:hive/hive.dart';

part 'chat_message_model.g.dart';

@HiveType(typeId: 4)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String role; // 'user' | 'agent'

  @HiveField(2)
  final String content;

  @HiveField(3)
  final String agentName; // seeker | librarian | connector

  @HiveField(4)
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.agentName,
    required this.timestamp,
  });
}
