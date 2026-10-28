import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_history_model.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/storage_service.dart';

AlreadyReadService alreadyReadService = AlreadyReadService();

/// Galleries manually marked as "already read".
///
/// The list has two roles:
///  1. it hides the gallery from the listing pages (home, search, popular,
///     watched and the 8muses source), so already seen works do not come back;
///  2. it is the source of the "Already read" page in the sidebar, where they
///     can be inspected and removed.
///
/// Works for both sources (E-H and 8muses) because a `GalleryHistoryModel`
/// already carries a [GalleryUrl] that knows its source. Stored in GetStorage
/// as a JSON array (same rationale as the local favorites: no Drift schema
/// change and no `build_runner` codegen), newest first.
class AlreadyReadService {
  static const String _storageKey = 'alreadyReadGalleries';

  /// Rows per page of the "Already read" page.
  static const int pageSize = 100;

  final RxList<GalleryHistoryModel> galleries = <GalleryHistoryModel>[].obs;

  /// gids in [galleries], for fast checks while filtering listings/cards.
  final RxSet<int> gids = <int>{}.obs;

  bool _restored = false;

  int get count => galleries.length;

  /// Loads the stored list once, before the first read from a build.
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
          final GalleryHistoryModel gallery = GalleryHistoryModel.fromJson(Map<String, dynamic>.from(entry as Map));
          galleries.add(gallery);
          gids.add(gallery.galleryUrl.gid);
        } catch (e) {
          log.error('Restore already-read entry failed', e);
        }
      }
    } catch (e) {
      log.error('Restore already-read galleries failed', e);
    }
  }

  bool contains(int gid) {
    ensureRestored();
    return gids.contains(gid);
  }

  /// Returns `true` when the gallery is marked as read after this call.
  Future<bool> toggle(GalleryHistoryModel gallery) async {
    ensureRestored();
    final bool alreadyRead = gids.contains(gallery.galleryUrl.gid);

    if (alreadyRead) {
      await remove(gallery.galleryUrl.gid);
    } else {
      await add(gallery);
    }

    return !alreadyRead;
  }

  Future<void> add(GalleryHistoryModel gallery) async {
    ensureRestored();

    galleries.removeWhere((GalleryHistoryModel e) => e.galleryUrl.gid == gallery.galleryUrl.gid);
    galleries.insert(0, gallery);
    gids.add(gallery.galleryUrl.gid);

    await _persist();
  }

  Future<void> remove(int gid) async {
    ensureRestored();
    final int length = galleries.length;
    galleries.removeWhere((GalleryHistoryModel e) => e.galleryUrl.gid == gid);

    if (galleries.length != length) {
      gids.remove(gid);
      await _persist();
    }
  }

  Future<void> clear() async {
    ensureRestored();
    galleries.clear();
    gids.clear();
    await _persist();
  }

  int getPageCount() {
    ensureRestored();
    return galleries.isEmpty ? 0 : (galleries.length - 1) ~/ pageSize + 1;
  }

  List<GalleryHistoryModel> getByPageIndex(int pageIndex) {
    ensureRestored();
    return galleries.skip(pageIndex * pageSize).take(pageSize).toList();
  }

  Future<void> _persist() {
    return storageService.write(_storageKey, jsonEncode(galleries.toList()));
  }
}
