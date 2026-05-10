import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cache_service.dart';

/// Holds the optional user-chosen background image. Persists in Hive.
///
/// Picker is capped at 2000px / 80% quality so images stored in IndexedDB
/// stay reasonable (typically <500KB after compression).
class BackgroundProvider with ChangeNotifier {
  Uint8List? _bytes;
  bool _picking = false;

  Uint8List? get bytes => _bytes;
  bool get hasImage => _bytes != null;
  bool get picking => _picking;

  BackgroundProvider();

  /// Reads persisted bytes after CacheService has finished init. Idempotent.
  Future<void> init() async {
    await CacheService.instance.init();
    _bytes = CacheService.instance.getBackgroundImage();
    notifyListeners();
  }

  Future<void> pick() async {
    if (_picking) return;
    _picking = true;
    notifyListeners();
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 80,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      _bytes = bytes;
      await CacheService.instance.setBackgroundImage(bytes);
      notifyListeners();
    } finally {
      _picking = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    _bytes = null;
    await CacheService.instance.setBackgroundImage(null);
    notifyListeners();
  }
}
