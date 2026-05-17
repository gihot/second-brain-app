import 'package:flutter/foundation.dart';
import '../services/cache_service.dart';

/// User-controllable glass-card aesthetics. Persisted in the meta box.
///
/// - [fillOpacity] controls the darkness of the glass surface (overrides the
///   default `BrainColors.glassCardFill` alpha).
/// - [tintOpacity] controls how strongly the hall color shines through the
///   glass.
class GlassSettingsProvider with ChangeNotifier {
  static const _fillKey = 'glass_fill_opacity_v1';
  static const _tintKey = 'glass_tint_opacity_v1';

  // Calmer defaults — content over atmosphere. Sliders let users raise it.
  static const double defaultFillOpacity = 0.22;
  static const double defaultTintOpacity = 0.10;

  static const double minFillOpacity = 0.10;
  static const double maxFillOpacity = 0.60;
  static const double minTintOpacity = 0.00;
  static const double maxTintOpacity = 0.40;

  double _fillOpacity = defaultFillOpacity;
  double _tintOpacity = defaultTintOpacity;

  double get fillOpacity => _fillOpacity;
  double get tintOpacity => _tintOpacity;

  /// Reads persisted values after CacheService init. Idempotent.
  Future<void> init() async {
    await CacheService.instance.init();
    final m = CacheService.instance;
    final f = m.getDouble(_fillKey);
    final t = m.getDouble(_tintKey);
    if (f != null) _fillOpacity = f.clamp(minFillOpacity, maxFillOpacity);
    if (t != null) _tintOpacity = t.clamp(minTintOpacity, maxTintOpacity);
    notifyListeners();
  }

  Future<void> setFillOpacity(double v) async {
    _fillOpacity = v.clamp(minFillOpacity, maxFillOpacity);
    await CacheService.instance.setDouble(_fillKey, _fillOpacity);
    notifyListeners();
  }

  Future<void> setTintOpacity(double v) async {
    _tintOpacity = v.clamp(minTintOpacity, maxTintOpacity);
    await CacheService.instance.setDouble(_tintKey, _tintOpacity);
    notifyListeners();
  }
}
