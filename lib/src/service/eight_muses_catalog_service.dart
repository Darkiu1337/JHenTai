import 'dart:convert';

import 'package:jhentai/src/model/eight_muses_search.dart';
import 'package:jhentai/src/network/eight_muses_request.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/storage_service.dart';

EightMusesCatalogService eightMusesCatalogService = EightMusesCatalogService();

/// Caches the site's tag directory and the page's recent searches.
///
/// Both live in [storageService] (GetStorage) instead of the local_config table
/// so no new [ConfigEnum] value (and no cloud-sync surface) is needed.
class EightMusesCatalogService {
  static const String _tagsKey = 'eightMusesTags';
  static const String _tagsFetchedAtKey = 'eightMusesTagsFetchedAt';
  static const String _recentSearchesKey = 'eightMusesRecentSearches';
  static const int _maxRecentSearches = 20;
  static const Duration _tagsMaxAge = Duration(days: 7);

  final List<EightMusesTag> tags = <EightMusesTag>[];

  bool loadingTags = false;
  String? tagsError;

  bool _restored = false;
  DateTime? _tagsFetchedAt;

  /// Loads `/genres` once (cached for [_tagsMaxAge]).
  Future<void> ensureTags({bool force = false}) async {
    if (loadingTags) {
      return;
    }

    _restore();

    final bool isFresh = _tagsFetchedAt != null && DateTime.now().difference(_tagsFetchedAt!) < _tagsMaxAge;
    if (!force && tags.isNotEmpty && isFresh) {
      return;
    }

    loadingTags = true;
    tagsError = null;
    try {
      final List<EightMusesTag> fetched = await eightMusesRequest.requestTags();
      if (fetched.isNotEmpty) {
        tags
          ..clear()
          ..addAll(fetched);
        _tagsFetchedAt = DateTime.now();
        _persist();
      }
    } catch (e, s) {
      tagsError = e.toString();
      log.error('Load 8muses tags failed', e, s);
    } finally {
      loadingTags = false;
    }
  }

  List<String> readRecentSearches() {
    _restore();
    final String? raw = storageService.read<String>(_recentSearchesKey);
    if (raw == null || raw.isEmpty) {
      return <String>[];
    }

    try {
      return (jsonDecode(raw) as List).map((dynamic e) => e.toString()).toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> addRecentSearch(String keyword) async {
    final String normalized = keyword.trim();
    if (normalized.isEmpty) {
      return;
    }

    final List<String> recent = readRecentSearches()..removeWhere((String e) => e.toLowerCase() == normalized.toLowerCase());
    recent.insert(0, normalized);
    if (recent.length > _maxRecentSearches) {
      recent.removeRange(_maxRecentSearches, recent.length);
    }

    await storageService.write(_recentSearchesKey, jsonEncode(recent));
  }

  Future<void> clearRecentSearches() => storageService.write(_recentSearchesKey, jsonEncode(<String>[]));

  void _restore() {
    if (_restored) {
      return;
    }
    _restored = true;

    try {
      final String? rawTags = storageService.read<String>(_tagsKey);
      if (rawTags != null && rawTags.isNotEmpty && tags.isEmpty) {
        final List<dynamic> decoded = jsonDecode(rawTags) as List;
        tags.addAll(
          decoded.map(
            (dynamic e) => EightMusesTag(
              slug: e['slug'].toString(),
              label: e['label'].toString(),
              count: int.tryParse(e['count'].toString()) ?? 0,
            ),
          ),
        );
      }

      final int? fetchedAtMillis = storageService.read<int>(_tagsFetchedAtKey);
      if (fetchedAtMillis != null) {
        _tagsFetchedAt = DateTime.fromMillisecondsSinceEpoch(fetchedAtMillis);
      }
    } catch (e) {
      log.error('Restore 8muses tags failed', e);
    }
  }

  void _persist() {
    storageService.write(
      _tagsKey,
      jsonEncode(tags.map((EightMusesTag tag) => <String, dynamic>{'slug': tag.slug, 'label': tag.label, 'count': tag.count}).toList()),
    );
    storageService.write(_tagsFetchedAtKey, DateTime.now().millisecondsSinceEpoch);
  }
}
