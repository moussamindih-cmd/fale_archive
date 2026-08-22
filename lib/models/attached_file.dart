// Représente un fichier joint à une archive journalière ou tout autre module
class AttachedFile {
  final String name; // Nom du fichier (ex: rapport.pdf)
  final String extension; // Extension en minuscules (pdf, docx, xlsx, png...)
  final int sizeBytes; // Taille en octets
  final List<int>?
  bytes; // Données brutes (en mémoire, avant upload ou après téléchargement)
  final bool isScanned; // true si obtenu via le scanner de documents
  final String?
  storagePath; // Chemin dans le bucket Supabase Storage une fois uploadé
  final DateTime?
  removedAt; // Date de retrait d'un dossier — corbeille au niveau document

  const AttachedFile({
    required this.name,
    required this.extension,
    required this.sizeBytes,
    this.bytes,
    this.isScanned = false,
    this.storagePath,
    this.removedAt,
  });

  /// true si ce document a été retiré d'un dossier (candidat/logistique)
  /// mais conservé en corbeille — récupérable via [CandidatesState.restoreDocument]
  /// ou [LogisticsState.restoreDocument].
  bool get isRemoved => removedAt != null;

  AttachedFile copyWith({
    String? name,
    String? extension,
    int? sizeBytes,
    List<int>? bytes,
    bool? isScanned,
    String? storagePath,
    DateTime? removedAt,
    bool clearRemovedAt = false,
  }) {
    return AttachedFile(
      name: name ?? this.name,
      extension: extension ?? this.extension,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      bytes: bytes ?? this.bytes,
      isScanned: isScanned ?? this.isScanned,
      storagePath: storagePath ?? this.storagePath,
      removedAt: clearRemovedAt ? null : (removedAt ?? this.removedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'extension': extension,
    'sizeBytes': sizeBytes,
    'isScanned': isScanned,
    'storagePath': storagePath,
    'removedAt': removedAt?.toIso8601String(),
  };

  factory AttachedFile.fromJson(Map<String, dynamic> json) {
    return AttachedFile(
      name: json['name'] as String,
      extension: json['extension'] as String,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      isScanned: json['isScanned'] as bool? ?? false,
      storagePath: json['storagePath'] as String?,
      removedAt: json['removedAt'] != null
          ? DateTime.parse(json['removedAt'] as String)
          : null,
    );
  }

  /// Règles de validation appliquées à tout fichier avant upload — source
  /// unique de vérité, référencée par le sélecteur de fichiers, le scanner
  /// et le service d'upload (défense en profondeur).
  static const int maxSizeBytes = 15 * 1024 * 1024; // 15 Mo
  static const List<String> allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'zip',
    'rar',
  ];

  /// Message d'erreur si ce fichier ne respecte pas les règles d'upload
  /// (type ou taille), ou `null` s'il est valide.
  String? get validationError {
    if (!allowedExtensions.contains(extension.toLowerCase())) {
      return '$name : type de fichier non autorisé (.$extension)';
    }
    if (sizeBytes > maxSizeBytes) {
      final maxMb = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
      return '$name : fichier trop volumineux (max $maxMb Mo)';
    }
    return null;
  }

  bool get isValid => validationError == null;

  // Taille lisible par l'humain
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

  // Type de document selon l'extension
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
