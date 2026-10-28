/// A tag (or artist) of https://8muses.io.
///
/// `slug` is what the site uses in urls (`/tag/big-breasts`, `/artist/milftoon`),
/// `label` is the human name shown on the cards and in the RSC payload.
/// Artist entries reuse this type (with `count` when the directory exposes it).
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

/// Everything the 8muses page can filter by.
///
/// The site only ships meaningful data for tags, artists and sorting:
/// content type is populated for two values only (`manga`, `image-set`) and
/// every gallery is English, so those controls were dropped.
///
/// Execution rules:
/// - an artist selected    -> `/artist/<slug>` (paginated); tags and keyword
///   are applied locally (artist pages carry the genres of every gallery);
/// - include tags          -> the first tag drives `/tag/<slug>`, the remaining
///   tags/keyword/exclusions are applied locally;
/// - otherwise keyword     -> `/search` (with `sort`);
/// - otherwise             -> the current listing (`/popular`, `/new`, `/browse`).
class EightMusesSearchConfig {
  String keyword;
  final List<EightMusesTag> includeTags;
  final List<EightMusesTag> excludeTags;
  EightMusesTag? artist;
  EightMusesSort sort;

  EightMusesSearchConfig({
    this.keyword = '',
    List<EightMusesTag>? includeTags,
    List<EightMusesTag>? excludeTags,
    this.artist,
    this.sort = EightMusesSort.relevance,
  })  : includeTags = includeTags ?? <EightMusesTag>[],
        excludeTags = excludeTags ?? <EightMusesTag>[];

  bool get hasKeyword => keyword.trim().isNotEmpty;

  bool get hasTags => includeTags.isNotEmpty || excludeTags.isNotEmpty;

  bool get isArtistMode => artist != null;

  /// True when the request must go to `/tag/<slug>` and be filtered locally.
  bool get isTagMode => includeTags.isNotEmpty;

  /// True when tags/keyword are applied on top of a tag or artist listing.
  bool get isLocalFilterMode => isArtistMode || isTagMode;

  /// True when anything filters the listing (used to hide the listing tabs).
  bool get isSearching => hasKeyword || hasTags || isArtistMode;

  int get activeFilterCount =>
      includeTags.length + excludeTags.length + (artist != null ? 1 : 0) + (sort != EightMusesSort.relevance ? 1 : 0);

  EightMusesSearchConfig copy() {
    return EightMusesSearchConfig(
      keyword: keyword,
      includeTags: List<EightMusesTag>.of(includeTags),
      excludeTags: List<EightMusesTag>.of(excludeTags),
      artist: artist,
      sort: sort,
    );
  }

  void reset() {
    keyword = '';
    includeTags.clear();
    excludeTags.clear();
    artist = null;
    sort = EightMusesSort.relevance;
  }

  @override
  String toString() {
    return 'EightMusesSearchConfig{keyword: $keyword, include: $includeTags, exclude: $excludeTags, artist: $artist, sort: $sort}';
  }
}
