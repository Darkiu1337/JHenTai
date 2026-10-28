import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/eight_muses_search.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/network/eight_muses_request.dart';
import 'package:jhentai/src/pages/eight_muses/eight_muses_state.dart';
import 'package:jhentai/src/service/eight_muses_catalog_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

/// Lists https://8muses.io galleries: listings, keyword search and tag search.
///
/// The site supports one exact tag per request (`/tag/<slug>`), so the first
/// included tag drives the request and every other filter (extra tags,
/// excluded tags, keyword) is applied locally on the fetched page. Tag/artist
/// pages carry the genres of each gallery; search result pages do not, which is
/// why keyword + tags always runs in tag mode.
class EightMusesLogic extends GetxController {
  final String bodyId = 'eightMusesBodyId';
  final String searchBarId = 'eightMusesSearchBarId';

  final EightMusesState state = EightMusesState();

  /// Lets a refresh invalidate in-flight page requests.
  int _requestSerial = 0;

  @override
  void onInit() {
    super.onInit();

    state.searchFocusNode.addListener(_onFocusChanged);
    loadMore();
  }

  @override
  void onClose() {
    state.searchFocusNode.removeListener(_onFocusChanged);
    state.searchFocusNode.dispose();
    state.searchController.dispose();
    state.scrollController.dispose();
    super.onClose();
  }

  List<String> get recentSearches => eightMusesCatalogService.readRecentSearches();

  List<EightMusesTag> get popularTags => eightMusesCatalogService.tags.take(12).toList();

  bool get loadingTags => eightMusesCatalogService.loadingTags;

  bool get hasTags => eightMusesCatalogService.tags.isNotEmpty;

  void _onFocusChanged() {
    if (state.showSuggestions == state.searchFocusNode.hasFocus) {
      return;
    }

    state.showSuggestions = state.searchFocusNode.hasFocus;
    update([bodyId, searchBarId]);

    if (state.showSuggestions) {
      eightMusesCatalogService.ensureTags().then((_) => update([bodyId]));
    }
  }

  Future<void> onRefresh() => refresh();

  Future<void> changeListing(EightMusesListing listing) async {
    if (state.listing == listing && !state.config.isSearching) {
      return;
    }

    state.listing = listing;
    state.config.reset();
    state.searchController.clear();
    await refresh();
  }

  Future<void> submitKeyword(String value) async {
    final String keyword = value.trim();
    if (keyword.isEmpty) {
      await clearFilters();
      return;
    }

    state.config.keyword = keyword;
    state.searchController.text = keyword;
    state.searchFocusNode.unfocus();
    state.showSuggestions = false;

    await eightMusesCatalogService.addRecentSearch(keyword);
    await refresh();
  }

  Future<void> clearKeyword() async {
    if (!state.config.hasKeyword) {
      return;
    }

    state.config.keyword = '';
    state.searchController.clear();
    await refresh();
  }

  Future<void> toggleIncludeTag(EightMusesTag tag) async {
    if (state.config.includeTags.contains(tag)) {
      state.config.includeTags.remove(tag);
    } else {
      state.config.excludeTags.remove(tag);
      state.config.includeTags.add(tag);
    }

    _hideSuggestions();
    await refresh();
  }

  Future<void> toggleExcludeTag(EightMusesTag tag) async {
    if (state.config.excludeTags.contains(tag)) {
      state.config.excludeTags.remove(tag);
    } else {
      state.config.includeTags.remove(tag);
      state.config.excludeTags.add(tag);
    }

    _hideSuggestions();
    await refresh();
  }

  Future<void> applyConfig(EightMusesSearchConfig config) async {
    state.config.keyword = config.keyword.trim();
    state.config.includeTags
      ..clear()
      ..addAll(config.includeTags);
    state.config.excludeTags
      ..clear()
      ..addAll(config.excludeTags);
    state.config.contentType = config.contentType;
    state.config.language = config.language;
    state.config.sort = config.sort;

    _hideSuggestions();
    state.searchController.text = state.config.keyword;
    await refresh();
  }

  Future<void> clearFilters() async {
    state.config.reset();
    state.searchController.clear();
    _hideSuggestions();
    await refresh();
  }

  void _hideSuggestions() {
    if (state.searchFocusNode.hasFocus) {
      state.searchFocusNode.unfocus();
    }
    state.showSuggestions = false;
  }

  void hideSuggestions() {
    _hideSuggestions();
    update([bodyId]);
  }

  Future<void> reloadTags() async {
    await eightMusesCatalogService.ensureTags(force: true);
    update([bodyId, searchBarId]);
  }

  Future<void> setContentType(EightMusesContentType value) async {
    if (state.config.contentType == value) {
      return;
    }
    state.config.contentType = value;
    await refresh();
  }

  Future<void> setLanguage(EightMusesLanguage value) async {
    if (state.config.language == value) {
      return;
    }
    state.config.language = value;
    await refresh();
  }

  Future<void> setSort(EightMusesSort value) async {
    if (state.config.sort == value) {
      return;
    }
    state.config.sort = value;
    await refresh();
  }

  Future<void> refresh() async {
    _requestSerial++;
    state.nextPage = 1;
    state.scannedPages = 0;
    state.scannedCards = 0;
    state.galleries.clear();
    state.loadingState = LoadingState.idle;
    update([bodyId, searchBarId]);

    await loadMore();
  }

  Future<void> loadMore() async {
    if (state.loadingState == LoadingState.loading || state.loadingState == LoadingState.noMore) {
      return;
    }

    final int serial = _requestSerial;
    state.loadingState = LoadingState.loading;
    update([bodyId]);

    final int expectedPageSize = _expectedPageSize;

    try {
      /// When filtering locally a whole page can be filtered out even though the
      /// site still has matches, so keep pulling pages until something survives
      /// (bounded to avoid hammering the site).
      int attempts = 0;
      while (attempts < 6) {
        attempts++;

        final List<Gallery> raw = await _fetchPage(state.nextPage);
        if (serial != _requestSerial) {
          return;
        }

        state.nextPage += 1;
        state.scannedPages += 1;
        state.scannedCards += raw.length;

        if (raw.isEmpty) {
          state.loadingState = state.galleries.isEmpty ? LoadingState.noData : LoadingState.noMore;
          break;
        }

        final List<Gallery> filtered = state.config.isTagMode ? _applyLocalFilters(raw) : raw;
        state.galleries.addAll(filtered);

        final bool isLastPage = raw.length < expectedPageSize;
        if (filtered.isNotEmpty || !state.config.isTagMode || isLastPage) {
          state.loadingState = isLastPage ? LoadingState.noMore : LoadingState.idle;
          break;
        }
      }

      if (state.loadingState == LoadingState.loading) {
        state.loadingState = LoadingState.idle;
      }
    } on DioException catch (e) {
      log.error('Load 8muses page failed', e.error);
      state.loadingState = LoadingState.error;
      snack('refreshGalleryFailed'.tr, e.message ?? '', isShort: true);
    } catch (e, s) {
      log.error('Load 8muses page failed', e, s);
      state.loadingState = LoadingState.error;
    }

    update([bodyId]);
  }

  int get _expectedPageSize => state.config.isTagMode || !state.config.isSearching ? 48 : 24;

  Future<List<Gallery>> _fetchPage(int page) {
    final EightMusesSearchConfig config = state.config;

    if (config.isTagMode) {
      return eightMusesRequest.requestTagPage(tagSlug: config.includeTags.first.slug, page: page);
    }

    if (config.hasKeyword || config.contentType != EightMusesContentType.all || config.language != EightMusesLanguage.all) {
      return eightMusesRequest.search(config: config, page: page);
    }

    return eightMusesRequest.requestListing(listing: state.listing, page: page);
  }

  /// Applies the tags/keyword that the site request could not express.
  ///
  /// The first include tag is guaranteed by `/tag/<slug>`, so only the
  /// remaining include tags are intersected here.
  List<Gallery> _applyLocalFilters(List<Gallery> galleries) {
    final EightMusesSearchConfig config = state.config;
    final List<String> extraIncludes = config.includeTags.skip(1).map((EightMusesTag tag) => tag.normalizedLabel).toList();
    final List<String> excludes = config.excludeTags.map((EightMusesTag tag) => tag.normalizedLabel).toList();
    final List<String> tokens = config.keyword
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList();

    if (extraIncludes.isEmpty && excludes.isEmpty && tokens.isEmpty) {
      return galleries;
    }

    return galleries.where((Gallery gallery) {
      final Set<String> genres = gallery.externalTags.map(EightMusesTag.normalizeTagLabel).toSet();

      if (extraIncludes.any((String label) => !genres.contains(label))) {
        return false;
      }

      if (excludes.any(genres.contains)) {
        return false;
      }

      if (tokens.isNotEmpty) {
        final String haystack = '${gallery.title} ${gallery.uploader ?? ''}'.toLowerCase();
        if (!tokens.every(haystack.contains)) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}
