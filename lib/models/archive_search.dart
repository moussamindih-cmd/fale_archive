/// Une ligne de résultat de recherche d'archives (§5.1.3).
///
/// Volontairement plus légère qu'une [DailyArchive] : la recherche ne
/// rapatrie pas les pièces jointes, seulement de quoi afficher la liste.
/// Le détail est chargé à l'ouverture.
class ArchiveSearchResult {
  final String id;
  final String title;
  final String summary;
  final String category;
  final String employeeName;
  final DateTime archiveDate;
  final int documentCount;
  final List<String> keywords;

  /// Pertinence calculée par PostgreSQL. Vaut 0 quand la recherche ne
  /// porte que sur des filtres, sans terme textuel.
  final double rank;

  /// Nombre total de résultats correspondant aux critères, toutes pages
  /// confondues — calculé par une fonction de fenêtrage côté serveur.
  final int totalCount;

  const ArchiveSearchResult({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.employeeName,
    required this.archiveDate,
    required this.documentCount,
    required this.keywords,
    required this.rank,
    required this.totalCount,
  });

  factory ArchiveSearchResult.fromJson(Map<String, dynamic> json) {
    return ArchiveSearchResult(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      category: json['category'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      archiveDate: DateTime.parse(json['archive_date'] as String),
      documentCount: (json['document_count'] as num?)?.toInt() ?? 0,
      keywords: (json['keywords'] as List?)?.cast<String>() ?? const [],
      rank: (json['rank'] as num?)?.toDouble() ?? 0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Une page de résultats, avec de quoi piloter la pagination.
class ArchiveSearchPage {
  final List<ArchiveSearchResult> results;
  final int totalCount;
  final int offset;
  final int limit;

  const ArchiveSearchPage({
    required this.results,
    required this.totalCount,
    required this.offset,
    required this.limit,
  });

  const ArchiveSearchPage.empty()
      : results = const [],
        totalCount = 0,
        offset = 0,
        limit = 50;

  bool get hasMore => offset + results.length < totalCount;
  int get nextOffset => offset + limit;
  bool get isEmpty => results.isEmpty;
}
