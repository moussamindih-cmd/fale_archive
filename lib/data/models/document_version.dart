class DocumentVersion {
  final String id;
  final String documentId;
  final int versionNumber;
  final String fileName;
  final double fileSizeMB;
  final String createdBy;
  final DateTime createdAt;
  final String comment;

  const DocumentVersion({
    required this.id,
    required this.documentId,
    required this.versionNumber,
    required this.fileName,
    required this.fileSizeMB,
    required this.createdBy,
    required this.createdAt,
    required this.comment,
  });
}
