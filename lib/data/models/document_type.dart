class DocumentType {
  final String id;
  final String organizationId;
  final String name;
  final String extensionAllowed;
  final String description;
  final int retentionYears;
  final String retentionAction; // 'archive', 'destroy', 'review'
  final int warningDaysBeforeExpiration;

  const DocumentType({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.extensionAllowed,
    required this.description,
    this.retentionYears = 5,
    this.retentionAction = 'archive',
    this.warningDaysBeforeExpiration = 30,
  });

  DocumentType copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? extensionAllowed,
    String? description,
    int? retentionYears,
    String? retentionAction,
    int? warningDaysBeforeExpiration,
  }) {
    return DocumentType(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      extensionAllowed: extensionAllowed ?? this.extensionAllowed,
      description: description ?? this.description,
      retentionYears: retentionYears ?? this.retentionYears,
      retentionAction: retentionAction ?? this.retentionAction,
      warningDaysBeforeExpiration: warningDaysBeforeExpiration ?? this.warningDaysBeforeExpiration,
    );
  }
}
