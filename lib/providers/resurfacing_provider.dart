import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// Hält die Resurfacing-IDs der laufenden Session. Der eigentliche
/// Note-Lookup passiert im Dashboard gegen den VaultProvider — diese
/// Klasse kennt nur IDs + Engaged-Mechanik.
///
/// Wave 3 R1+R2: ersetzt den lokalen Pseudo-Zufall aus
/// `dashboard_signals.resurfacedNote`. Server entscheidet, welche
/// Notizen heute auftauchen (Score-Funktion siehe
/// `services/resurfacing_service.py`), Client zeigt sie.
///
/// **Bewusst kein Disk-Cache**: Resurfacing-Spec verlangt täglich
/// frische Auswahl, und die Server-Antwort ist klein (IDs). Wenn der
/// Server offline ist, fällt das Dashboard auf den alten Local-Helper
/// zurück (siehe `DashboardScreen.build`) — die Spec sagt explizit
/// „Dashboard darf niemals tot wirken".
class ResurfacingProvider extends ChangeNotifier {
  List<String> _noteIds = const [];
  bool _loading = false;
  bool _loadedOnce = false;
  DateTime? _loadedAt;

  List<String> get noteIds => _noteIds;
  bool get loading => _loading;
  /// True wenn die Server-Antwort ankam (auch leere Liste zählt).
  bool get loadedOnce => _loadedOnce;

  /// Erstaufruf nach Login. Idempotent — mehrfacher Aufruf während
  /// derselben Stunde tut nichts. AuthGate triggert das beim ersten
  /// erfolgreichen Token-Resolve.
  Future<void> init() async {
    if (_loadedAt != null &&
        DateTime.now().difference(_loadedAt!).inHours < 1) {
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    final ids = await ApiService.instance.getResurfacingToday(limit: 3);

    _loading = false;
    if (ids != null) {
      _noteIds = ids;
      _loadedOnce = true;
      _loadedAt = DateTime.now();
    }
    notifyListeners();
  }

  /// Optimistic remove + server-Pause. „Geöffnet"-Signal — die Karte
  /// verschwindet aus dem Dashboard, die Notiz ist 30 Tage pausiert.
  /// Server-Fehler werden verschluckt; im worst case sieht der User
  /// die Karte morgen wieder.
  Future<void> markEngaged(String noteId) async {
    if (!_noteIds.contains(noteId)) return;
    _noteIds = List<String>.from(_noteIds)..remove(noteId);
    notifyListeners();
    await ApiService.instance.markResurfacingEngaged(noteId);
  }

  /// Wird vom AuthGate beim Logout aufgerufen — sonst tragen wir die
  /// Resurface-Liste des Vor-Users in die nächste Session.
  void clear() {
    _noteIds = const [];
    _loadedOnce = false;
    _loadedAt = null;
    notifyListeners();
  }
}
