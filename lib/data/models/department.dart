class Department {
  final String id;
  final String organizationId;
  final String name;
  final String code;
  final String description;
  final int userCount;
  final DateTime createdAt;

  const Department({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.code,
    required this.description,
    required this.userCount,
    required this.createdAt,
  });
}
