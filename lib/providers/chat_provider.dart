import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message_model.dart';
import '../models/note_model.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  static const _boxName = 'chat_history';

  Box<ChatMessage>? _box;
  String _selectedAgent = 'seeker';
  bool _typing = false;
  String? _error;
  String? _wingScope;
  MemoryHall? _hallScope;

  List<ChatMessage> get messages {
    if (_box == null || !_box!.isOpen) return [];
    return _box!.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  String get selectedAgent => _selectedAgent;
  bool get typing => _typing;
  String? get error => _error;
  String? get wingScope => _wingScope;
  MemoryHall? get hallScope => _hallScope;

  void setWingScope(String? wing) {
    _wingScope = wing;
    notifyListeners();
  }

  void setHallScope(MemoryHall? hall) {
    _hallScope = hall;
    notifyListeners();
  }

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    _box = await Hive.openBox<ChatMessage>(_boxName);
    notifyListeners();
  }

  void selectAgent(String name) {
    _selectedAgent = name;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final now = DateTime.now();

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: 'user',
      content: text.trim(),
      agentName: _selectedAgent,
      timestamp: now,
    );
    await _box?.put(userMsg.id, userMsg);

    _typing = true;
    _error = null;
    notifyListeners();

    final response = await ApiService.instance.invokeAgent(
      _selectedAgent,
      text.trim(),
      context: {
        if (_wingScope != null) 'wing_scope': _wingScope,
        if (_hallScope != null) 'hall_scope': _hallScope!.name,
      },
    );

    _typing = false;

    if (response == null) {
      _error = 'Could not reach the agent. Check your connection.';
      notifyListeners();
      return;
    }

    final content =
        response['content'] as String? ?? response['metadata']?.toString() ?? '…';

    final agentMsg = ChatMessage(
      id: const Uuid().v4(),
      role: 'agent',
      content: content.trim().isEmpty ? '(no response)' : content.trim(),
      agentName: _selectedAgent,
      timestamp: DateTime.now(),
    );
    await _box?.put(agentMsg.id, agentMsg);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _box?.clear();
    notifyListeners();
  }
}
