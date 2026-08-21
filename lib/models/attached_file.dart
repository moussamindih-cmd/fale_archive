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

  const AttachedFile({
    required this.name,
    required this.extension,
    required this.sizeBytes,
    this.bytes,
    this.isScanned = false,
    this.storagePath,
  });

  AttachedFile copyWith({
    String? name,
    String? extension,
    int? sizeBytes,
    List<int>? bytes,
    bool? isScanned,
    String? storagePath,
  }) {
    return AttachedFile(
      name: name ?? this.name,
      extension: extension ?? this.extension,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      bytes: bytes ?? this.bytes,
      isScanned: isScanned ?? this.isScanned,
      storagePath: storagePath ?? this.storagePath,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'extension': extension,
    'sizeBytes': sizeBytes,
    'isScanned': isScanned,
    'storagePath': storagePath,
  };

  factory AttachedFile.fromJson(Map<String, dynamic> json) {
    return AttachedFile(
      name: json['name'] as String,
      extension: json['extension'] as String,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      isScanned: json['isScanned'] as bool? ?? false,
      storagePath: json['storagePath'] as String?,
    );
  }

  // Taille lisible par l'humain
  String get readableSize {
    if (sizeBytes < 1024) return '$sizeBytes o';
    if (sizeBytes < 1024 * 1024)
      return '${(sizeBytes / 1024).toStringAsFixed(1)} Ko';
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
