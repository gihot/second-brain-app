import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web Speech API wrapper using dart:html. Chromium-only (Chrome, Edge, Brave).
/// Falls back gracefully on unsupported browsers.
class SpeechService {
  static bool get isSupported {
    if (!kIsWeb) return false;
    try {
      // Check if SpeechRecognition or webkitSpeechRecognition exists on window
      return html.window.speechSynthesis != null ||
          _hasSpeechRecognition();
    } catch (_) {
      return false;
    }
  }

  static bool _hasSpeechRecognition() {
    try {
      html.SpeechRecognition();
      return true;
    } catch (_) {
      return false;
    }
  }

  html.SpeechRecognition? _recognition;
  bool _listening = false;

  bool get isListening => _listening;

  void startListening({
    required void Function(String transcript) onResult,
    required void Function() onEnd,
    String lang = 'de-DE',
  }) {
    if (!kIsWeb) return;
    try {
      _recognition = html.SpeechRecognition();
      _recognition!.lang = lang;
      _recognition!.interimResults = false;
      _recognition!.maxAlternatives = 1;
      _recognition!.continuous = false;

      _recognition!.onResult.listen((event) {
        try {
          final results = event.results;
          if (results == null || results.isEmpty) return;
          final first = results.first as html.SpeechRecognitionResult;
          final alt = first.item(0);
          final transcript = alt?.transcript ?? '';
          if (transcript.isNotEmpty) onResult(transcript);
        } catch (_) {}
      });

      _recognition!.onEnd.listen((_) {
        _listening = false;
        onEnd();
      });

      _recognition!.onError.listen((_) {
        _listening = false;
        onEnd();
      });

      _recognition!.start();
      _listening = true;
    } catch (_) {
      _listening = false;
    }
  }

  void stopListening() {
    try {
      _recognition?.stop();
    } catch (_) {}
    _listening = false;
  }

  void dispose() {
    stopListening();
    _recognition = null;
  }
}
