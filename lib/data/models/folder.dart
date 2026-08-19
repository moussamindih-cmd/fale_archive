class Folder {
  final String id;
  final String organizationId;
  final String? parentId;
  final String name;
  final String departmentId;
  final int documentCount;
  final DateTime createdAt;

  const Folder({
    required this.id,
    required this.organizationId,
    this.parentId,
    required this.name,
    required this.departmentId,
    required this.documentCount,
    required this.createdAt,
  });
}
