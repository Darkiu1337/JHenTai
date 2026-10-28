/// Metadata of an 8muses gallery, as far as the site exposes it.
class EightMusesDetail {
  final int id;
  final String title;
  final String author;
  final int pageCount;
  final double rating;
  final String description;

  /// Free-form genres. The site usually only says "Image Set" or "Manga", so
  /// this is often a single item (or empty).
  final List<String> genres;

  /// `yyyy-MM-dd HH:mm`, derived from the site's relative "updated" field.
  final String publishTime;

  const EightMusesDetail({
    required this.id,
    required this.title,
    required this.author,
    required this.pageCount,
    required this.rating,
    required this.description,
    required this.genres,
    required this.publishTime,
  });

  @override
  String toString() {
    return 'EightMusesDetail{id: $id, title: $title, author: $author, pageCount: $pageCount, rating: $rating, genres: $genres}';
  }
}
