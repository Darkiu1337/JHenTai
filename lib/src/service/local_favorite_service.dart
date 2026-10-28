import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/storage_service.dart';

LocalFavoriteService localFavoriteService = LocalFavoriteService();

/// Local (offline) favorites of the external 8muses source.
///
/// Deliberately separate from the E-H favorites ([FavoriteSetting]): those are
/// 10 online slots that require login, while this is a local bookmark list that
/// works without an account.
///
/// The list lives in [storageService] (GetStorage) as a JSON array of
/// `Gallery` snapshots instead of a Drift table, so no database schema change
/// (and no `build_runner` codegen) is needed. It is small and always loaded as
/// a whole, and it stays out of the cloud-sync surface on purpose.
class LocalFavoriteService {
  static const String _storageKey = 'localFavorites';

  /// Newest first.
  final RxList<Gallery> favorites = <Gallery>[].obs;

  bool _restored = false;

  /// Loads the stored list once. Call it before reading [favorites] from a
  /// widget build, so [contains] never mutates the observable during a build.
  void ensureRestored() {
    if (_restored) {
      return;
    }
    _restored = true;

    try {
      final String? raw = storageService.read<String>(_storageKey);
      if (raw == null || raw.isEmpty) {
        return;
      }

      final List<dynamic> decoded = jsonDecode(raw) as List;
      for (final dynamic entry in decoded) {
        try {
          favorites.add(Gallery.fromJson(Map<String, dynamic>.from(entry as Map)));
        } catch (e) {
          log.error('Restore local favorite entry failed', e);
        }
      }
    } catch (e) {
      log.error('Restore local favorites failed', e);
    }
  }

  bool contains(int gid) {
    ensureRestored();
    return favorites.any((Gallery gallery) => gallery.gid == gid);
  }

  Gallery? find(int gid) {
    ensureRestored();
    for (final Gallery gallery in favorites) {
      if (gallery.gid == gid) {
        return gallery;
      }
    }
    return null;
  }

  /// Returns `true` when the gallery is favorited after this call.
  Future<bool> toggle(Gallery gallery) async {
    ensureRestored();
    final bool alreadyFavorited = contains(gallery.gid);

    if (alreadyFavorited) {
      await remove(gallery.gid);
    } else {
      await add(gallery);
    }

    return !alreadyFavorited;
  }

  Future<void> add(Gallery gallery) async {
    ensureRestored();

    /// Re-adding refreshes the stored snapshot (title, cover, page count).
    favorites.removeWhere((Gallery e) => e.gid == gallery.gid);
    favorites.insert(0, gallery);

    await _persist();
  }

  Future<void> remove(int gid) async {
    ensureRestored();
    final int length = favorites.length;
    favorites.removeWhere((Gallery e) => e.gid == gid);

    if (favorites.length != length) {
      await _persist();
    }
  }

  Future<void> clear() async {
    ensureRestored();
    favorites.clear();
    await _persist();
  }

  Future<void> _persist() {
    return storageService.write(
      _storageKey,
      jsonEncode(favorites.map((Gallery gallery) => gallery.toJson()).toList()),
    );
  }
}
