class PetNewsItem {
  const PetNewsItem({
    required this.species,
    required this.title,
    required this.extract,
    required this.sourceUrl,
    this.imageUrl,
    this.publishedAt,
  });

  final String species;
  final String title;
  final String extract;
  final String sourceUrl;
  final String? imageUrl;

  /// From the feed's `pubDate` — null if the feed didn't provide one, in
  /// which case recency-sorting treats this item as oldest rather than
  /// guessing.
  final DateTime? publishedAt;
}
