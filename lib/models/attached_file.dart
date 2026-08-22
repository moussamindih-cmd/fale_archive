/// Fichier joint à une archive journalière ou à tout autre module.
///
/// Les champs de traçabilité ([mimeType], [checksumSha256], [uploadedBy],
/// [uploadedAt]) sont facultatifs : les pièces déjà enregistrées dans la
/// colonne JSONB `documents` ne les portent pas et doivent rester lisibles.
class AttachedFile {
  /// Nom du fichier (ex: rapport.pdf).
  final String name;

  /// Extension en minuscules (pdf, docx, xlsx, png…).
  final String extension;

  /// Taille en octets.
  final int sizeBytes;

  /// Données brutes, en mémoire — avant envoi ou après téléchargement.
  /// Jamais sérialisées.
  final List<int>? bytes;

  /// Vrai si la pièce provient du scanner de documents.
  final bool isScanned;

  /// Chemin dans le bucket Supabase Storage une fois envoyé.
  final String? storagePath;

  /// Type MIME déclaré, utile au visualiseur et aux en-têtes de export.
  final String? mimeType;

  /// Empreinte SHA-256 du contenu — sert à détecter une altération et à
  /// éviter de créer une version identique à la précédente (§5.1.6).
  final String? checksumSha256;

  /// Identifiant de l'employé ayant déposé la pièce.
  final String? uploadedBy;

  /// Horodatage du dépôt, côté serveur.
  final DateTime? uploadedAt;

  const AttachedFile({
    required this.name,
    required this.extension,
    required this.sizeBytes,
    this.bytes,
    this.isScanned = false,
    this.storagePath,
    this.mimeType,
    this.checksumSha256,
    this.uploadedBy,
    this.uploadedAt,
  });

  AttachedFile copyWith({
    String? name,
    String? extension,
    int? sizeBytes,
    List<int>? bytes,
    bool? isScanned,
    String? storagePath,
    String? mimeType,
    String? checksumSha256,
    String? uploadedBy,
    DateTime? uploadedAt,
  }) {
    return AttachedFile(
      name: name ?? this.name,
      extension: extension ?? this.extension,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      bytes: bytes ?? this.bytes,
      isScanned: isScanned ?? this.isScanned,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
      checksumSha256: checksumSha256 ?? this.checksumSha256,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'extension': extension,
        'sizeBytes': sizeBytes,
        'isScanned': isScanned,
        'storagePath': storagePath,
        if (mimeType != null) 'mimeType': mimeType,
        if (checksumSha256 != null) 'checksumSha256': checksumSha256,
        if (uploadedBy != null) 'uploadedBy': uploadedBy,
        if (uploadedAt != null) 'uploadedAt': uploadedAt!.toIso8601String(),
      };

  factory AttachedFile.fromJson(Map<String, dynamic> json) {
    final rawUploadedAt = json['uploadedAt'] as String?;
    return AttachedFile(
      name: json['name'] as String,
      extension: json['extension'] as String,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      isScanned: json['isScanned'] as bool? ?? false,
      storagePath: json['storagePath'] as String?,
      mimeType: json['mimeType'] as String?,
      checksumSha256: json['checksumSha256'] as String?,
      uploadedBy: json['uploadedBy'] as String?,
      uploadedAt: rawUploadedAt == null ? null : DateTime.tryParse(rawUploadedAt),
    );
  }

  /// Taille lisible par l'humain.
  String get readableSize {
    if (sizeBytes < 1024) return '$sizeBytes o';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  String get formattedSize => readableSize;

  bool get isImage {
    final ext = extension.toLowerCase();
    return ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'png' ||
        ext == 'webp' ||
        ext == 'gif';
  }

  bool get isPdf => extension.toLowerCase() == 'pdf';

  /// Type de document déduit de l'extension.
  String get fileType {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
        return 'Word';
      case 'xls':
      case 'xlsx':
        return 'Excel';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'Image';
      case 'txt':
        return 'Texte';
      case 'zip':
      case 'rar':
        return 'Archive';
      default:
        return extension.toUpperCase();
    }
  }
}
