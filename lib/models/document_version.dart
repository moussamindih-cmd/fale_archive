import 'attached_file.dart';

/// Une révision d'une pièce jointe à une archive (§5.1.6).
///
/// Le modèle actuel écrase la colonne JSONB `documents` à chaque modification,
/// ce qui détruit les états antérieurs. Chaque dépôt crée désormais une ligne
/// `document_versions` immuable : le fichier reste dans le bucket, seule la
/// version courante est mise en avant.
///
/// Reflet côté Dart de la table `document_versions`.
class DocumentVersion {
  final String id;
  final String organizationId;
  final String archiveId;

  /// Numéro de révision, à partir de 1, unique par archive.
  final int versionNumber;

  final String fileName;
  final String? mimeType;
  final int sizeBytes;

  /// Empreinte du contenu — deux versions successives identiques sont un
  /// enregistrement inutile et doivent être refusées en amont.
  final String? checksumSha256;

  /// Chemin dans le bucket `documents`. Immuable : une version ne réécrit
  /// jamais le fichier d'une version antérieure.
  final String storagePath;

  /// Motif de la modification, saisi par l'utilisateur.
  final String? comment;

  final String? createdById;
  final String? createdByName;
  final DateTime createdAt;

  const DocumentVersion({
    required this.id,
    required this.organizationId,
    required this.archiveId,
    required this.versionNumber,
    required this.fileName,
    required this.storagePath,
    required this.createdAt,
    this.mimeType,
    this.sizeBytes = 0,
    this.checksumSha256,
    this.comment,
    this.createdById,
    this.createdByName,
  });

  /// Extension déduite du nom de fichier, sans le point.
  String get extension {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  String get label => 'v$versionNumber';

  /// Reconstruit une pièce jointe affichable à partir de la révision, pour
  /// réutiliser le visualiseur et les cartes de prévisualisation existants.
  AttachedFile toAttachedFile() => AttachedFile(
        name: fileName,
        extension: extension,
        sizeBytes: sizeBytes,
        storagePath: storagePath,
        mimeType: mimeType,
        checksumSha256: checksumSha256,
        uploadedBy: createdById,
        uploadedAt: createdAt,
      );

  factory DocumentVersion.fromJson(Map<String, dynamic> json) {
    return DocumentVersion(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      archiveId: json['archive_id'] as String,
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      fileName: json['file_name'] as String? ?? 'sans-nom',
      mimeType: json['mime_type'] as String?,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      checksumSha256: json['checksum_sha256'] as String?,
      storagePath: json['storage_path'] as String? ?? '',
      comment: json['comment'] as String?,
      createdById: json['created_by'] as String?,
      createdByName: json['created_by_name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organization_id': organizationId,
        'archive_id': archiveId,
        'version_number': versionNumber,
        'file_name': fileName,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'checksum_sha256': checksumSha256,
        'storage_path': storagePath,
        'comment': comment,
        'created_by': createdById,
        'created_at': createdAt.toIso8601String(),
      };
}
