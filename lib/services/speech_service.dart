import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

// ── JS-interop shim for the experimental Web Speech API ──────────────────
// Chromium ships it as `webkitSpeechRecognition`. We only model the members
// we actually use; the rest stays untyped JS.

@JS('webkitSpeechRecognition')
extension type _SpeechRecognition._(JSObject _) implements JSObject {
  external _SpeechRecognition();
  external set lang(String v);
  external set interimResults(bool v);
  external set maxAlternatives(int v);
  external set continuous(bool v);
  external set onresult(JSFunction f);
  external set onend(JSFunction f);
  external set onerror(JSFunction f);
  external void start();
  external void stop();
}

@JS()
extension type _SpeechRecognitionEvent._(JSObject _) implements JSObject {
  external _SpeechRecognitionResultList get results;
}

@JS()
extension type _SpeechRecognitionResultList._(JSObject _) implements JSObject {
  external int get length;
  @JS('item')
  external _SpeechRecognitionResult item(int index);
}

@JS()
extension type _SpeechRecognitionResult._(JSObject _) implements JSObject {
  @JS('item')
  external _SpeechRecognitionAlternative item(int index);
}

@JS()
extension type _SpeechRecognitionAlternative._(JSObject _) implements JSObject {
  external String get transcript;
}

bool _hasSpeechRecognition() {
  try {
    return globalContext.has('webkitSpeechRecognition') ||
        globalContext.has('SpeechRecognition');
  } catch (_) {
    return false;
  }
}

/// Web Speech API wrapper using js_interop. Chromium-only (Chrome, Edge, Brave).
/// Falls back gracefully on unsupported browsers.
class SpeechService {
  static bool get isSupported {
    if (!kIsWeb) return false;
    return _hasSpeechRecognition();
  }

  _SpeechRecognition? _recognition;
  bool _listening = false;

  bool get isListening => _listening;

  void startListening({
    required void Function(String transcript) onResult,
    required void Function() onEnd,
    String lang = 'de-DE',
  }) {
    if (!kIsWeb || !isSupported) return;
    try {
      final rec = _SpeechRecognition()
        ..lang = lang
        ..interimResults = false
        ..maxAlternatives = 1
        ..continuous = false;

      rec.onresult = ((JSAny event) {
        try {
          final ev = event as _SpeechRecognitionEvent;
          final results = ev.results;
          if (results.length == 0) return;
          final first = results.item(0);
          final alt = first.item(0);
          final transcript = alt.transcript;
          if (transcript.isNotEmpty) onResult(transcript);
        } catch (_) {}
      }).toJS;

      rec.onend = ((JSAny _) {
        _listening = false;
        onEnd();
      }).toJS;

      rec.onerror = ((JSAny _) {
        _listening = false;
        onEnd();
      }).toJS;

      rec.start();
      _recognition = rec;
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
