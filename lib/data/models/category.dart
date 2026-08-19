class Category {
  final String id;
  final String organizationId;
  final String name;
  final String description;
  final String colorHex;
  final bool isActive;
  final int documentCount;

  const Category({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.description,
    required this.colorHex,
    this.isActive = true,
    required this.documentCount,
  });
}
