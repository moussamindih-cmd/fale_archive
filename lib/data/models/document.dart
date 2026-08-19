enum ConfidentialityLevel {
  publicLevel('Public', 'Accessible à tous'),
  internal('Interne', 'Réservé aux membres du département'),
  confidential('Confidentiel', 'Accès restreint sur autorisation'),
  strictlyConfidential('Strictement Confidentiel', 'Direction & Archiviste uniquement');

  final String label;
  final String description;

  const ConfidentialityLevel(this.label, this.description);
}

enum RetentionStatus {
  active('Actif'),
  expiringSoon('Expire bientôt'),
  expired('Expiré'),
  toDestroy('À détruire'),
  destroyed('Détruit');

  final String label;

  const RetentionStatus(this.label);
}

class DocumentItem {
  final String id;
  final String organizationId;
  final String folderId;
  final String folderName;
  final String categoryId;
  final String categoryName;
  final String documentTypeId;
  final String documentTypeName;
  final String departmentId;
  final String departmentName;
  final String createdBy;
  final String createdByName;
  final String title;
  final String reference;
  final String description;
  final String fileName;
  final String fileUrl;
  final double fileSizeMB;
  final String mimeType;
  final ConfidentialityLevel confidentiality;
  final RetentionStatus retentionStatus;
  final int retentionPeriodYears;
  final DateTime documentDate;
  final DateTime expirationDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> keywords;
  final String physicalLocationRef;
  final int version;
  final bool isArchived;

  const DocumentItem({
    required this.id,
    required this.organizationId,
    required this.folderId,
    required this.folderName,
    required this.categoryId,
    required this.categoryName,
    required this.documentTypeId,
    required this.documentTypeName,
    required this.departmentId,
    required this.departmentName,
    required this.createdBy,
    required this.createdByName,
    required this.title,
    required this.reference,
    required this.description,
    required this.fileName,
    required this.fileUrl,
    required this.fileSizeMB,
    required this.mimeType,
    required this.confidentiality,
    required this.retentionStatus,
    required this.retentionPeriodYears,
    required this.documentDate,
    required this.expirationDate,
    required this.createdAt,
    required this.updatedAt,
    required this.keywords,
    required this.physicalLocationRef,
    this.version = 1,
    this.isArchived = false,
  });

  DocumentItem copyWith({
    String? title,
    String? reference,
    String? description,
    String? folderId,
    String? folderName,
    String? categoryId,
    String? categoryName,
    String? departmentId,
    String? departmentName,
    ConfidentialityLevel? confidentiality,
    RetentionStatus? retentionStatus,
    int? version,
    bool? isArchived,
  }) {
    return DocumentItem(
      id: id,
      organizationId: organizationId,
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      documentTypeId: documentTypeId,
      documentTypeName: documentTypeName,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      createdBy: createdBy,
      createdByName: createdByName,
      title: title ?? this.title,
      reference: reference ?? this.reference,
      description: description ?? this.description,
      fileName: fileName,
      fileUrl: fileUrl,
      fileSizeMB: fileSizeMB,
      mimeType: mimeType,
      confidentiality: confidentiality ?? this.confidentiality,
      retentionStatus: retentionStatus ?? this.retentionStatus,
      retentionPeriodYears: retentionPeriodYears,
      documentDate: documentDate,
      expirationDate: expirationDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      keywords: keywords,
      physicalLocationRef: physicalLocationRef,
      version: version ?? this.version,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
