class PetNewsItem {
  const PetNewsItem({
    required this.species,
    required this.title,
    required this.extract,
    required this.sourceUrl,
    this.imageUrl,
  });

  final String species;
  final String title;
  final String extract;
  final String sourceUrl;
  final String? imageUrl;
}
