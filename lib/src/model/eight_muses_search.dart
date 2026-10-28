/// A tag of https://8muses.io (the site calls them genres/tags interchangeably).
///
/// `slug` is what the site uses in urls (`/tag/big-breasts`), `label` is the
/// human name shown on the cards and in the RSC payload (`Big Breasts`).
class EightMusesTag {
  final String slug;
  final String label;
  final int count;

  const EightMusesTag({
    required this.slug,
    required this.label,
    this.count = 0,
  });

  String get normalizedLabel => normalizeTagLabel(label);

  static String normalizeTagLabel(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is EightMusesTag && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;

  @override
  String toString() => 'EightMusesTag{slug: $slug, label: $label, count: $count}';
}

enum EightMusesSort { relevance, latest, popular }

extension EightMusesSortX on EightMusesSort {
  String get apiValue => switch (this) {
        EightMusesSort.relevance => 'relevance',
        EightMusesSort.latest => 'latest',
        EightMusesSort.popular => 'popular',
      };

  String get labelKey => switch (this) {
        EightMusesSort.relevance => 'bestMatch',
        EightMusesSort.latest => 'newest',
        EightMusesSort.popular => 'mostViewed',
      };
}

enum EightMusesContentType { all, manga, doujinshi, western, imageSet, artistCg, gameCg }

extension EightMusesContentTypeX on EightMusesContentType {
  String get apiValue => switch (this) {
        EightMusesContentType.all => '',
        EightMusesContentType.manga => 'manga',
        EightMusesContentType.doujinshi => 'doujinshi',
        EightMusesContentType.western => 'western',
        EightMusesContentType.imageSet => 'image-set',
        EightMusesContentType.artistCg => 'artist-cg',
        EightMusesContentType.gameCg => 'game-cg',
      };

  /// Values are site-native, so they are not translated.
  String get label => switch (this) {
        EightMusesContentType.all => 'All',
        EightMusesContentType.manga => 'Manga',
        EightMusesContentType.doujinshi => 'Doujinshi',
        EightMusesContentType.western => 'Western',
        EightMusesContentType.imageSet => 'Image Set',
        EightMusesContentType.artistCg => 'Artist CG',
        EightMusesContentType.gameCg => 'Game CG',
      };
}

enum EightMusesLanguage { all, en, ja, es, fr, ko, de, ru }

extension EightMusesLanguageX on EightMusesLanguage {
  String get apiValue => switch (this) {
        EightMusesLanguage.all => '',
        EightMusesLanguage.en => 'en',
        EightMusesLanguage.ja => 'ja',
        EightMusesLanguage.es => 'es',
        EightMusesLanguage.fr => 'fr',
        EightMusesLanguage.ko => 'ko',
        EightMusesLanguage.de => 'de',
        EightMusesLanguage.ru => 'ru',
      };

  /// Values are site-native, so they are not translated.
  String get label => switch (this) {
        EightMusesLanguage.all => 'All',
        EightMusesLanguage.en => 'English',
        EightMusesLanguage.ja => '日本語',
        EightMusesLanguage.es => 'Español',
        EightMusesLanguage.fr => 'Français',
        EightMusesLanguage.ko => '한국어',
        EightMusesLanguage.de => 'Deutsch',
        EightMusesLanguage.ru => 'Русский',
      };
}

/// Everything the 8muses page can filter by.
///
/// Execution rules:
/// - include tags present  -> the first tag drives the request (`/tag/<slug>`),
///   the remaining tags/keyword/exclusions are applied locally (the tag page
///   payload carries the genres of every gallery);
/// - otherwise keyword/type/language are sent to `/search`;
/// - otherwise the current listing (`/popular`, `/new`, `/browse`) is used.
class EightMusesSearchConfig {
  String keyword;
  final List<EightMusesTag> includeTags;
  final List<EightMusesTag> excludeTags;
  EightMusesContentType contentType;
  EightMusesLanguage language;
  EightMusesSort sort;

  EightMusesSearchConfig({
    this.keyword = '',
    List<EightMusesTag>? includeTags,
    List<EightMusesTag>? excludeTags,
    this.contentType = EightMusesContentType.all,
    this.language = EightMusesLanguage.all,
    this.sort = EightMusesSort.relevance,
  })  : includeTags = includeTags ?? <EightMusesTag>[],
        excludeTags = excludeTags ?? <EightMusesTag>[];

  bool get hasKeyword => keyword.trim().isNotEmpty;

  bool get hasTags => includeTags.isNotEmpty || excludeTags.isNotEmpty;

  /// True when the request must go to `/tag/<slug>` and be filtered locally.
  bool get isTagMode => includeTags.isNotEmpty;

  /// True when anything filters the listing (used to hide the listing tabs).
  bool get isSearching => hasKeyword || hasTags || contentType != EightMusesContentType.all || language != EightMusesLanguage.all;

  int get activeFilterCount =>
      includeTags.length +
      excludeTags.length +
      (contentType != EightMusesContentType.all ? 1 : 0) +
      (language != EightMusesLanguage.all ? 1 : 0) +
      (sort != EightMusesSort.relevance ? 1 : 0);

  EightMusesSearchConfig copy() {
    return EightMusesSearchConfig(
      keyword: keyword,
      includeTags: List<EightMusesTag>.of(includeTags),
      excludeTags: List<EightMusesTag>.of(excludeTags),
      contentType: contentType,
      language: language,
      sort: sort,
    );
  }

  void reset() {
    keyword = '';
    includeTags.clear();
    excludeTags.clear();
    contentType = EightMusesContentType.all;
    language = EightMusesLanguage.all;
    sort = EightMusesSort.relevance;
  }

  @override
  String toString() {
    return 'EightMusesSearchConfig{keyword: $keyword, include: $includeTags, exclude: $excludeTags, type: $contentType, lang: $language, sort: $sort}';
  }
}
