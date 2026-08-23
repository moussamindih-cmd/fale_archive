/// Catégorie de la taxonomie documentaire d'une organisation (§5.1.2).
///
/// Remplace la catégorie jusqu'ici déduite du poste du déposant : deux
/// personnes du même poste peuvent classer différemment, et une organisation
/// doit pouvoir définir son propre plan de classement.
class ArchiveCategory {
  final String id;
  final String organizationId;

  /// Code stable, utilisé pour les correspondances et les imports.
  final String code;
  final String label;

  /// Catégorie parente, pour un plan de classement hiérarchique.
  final String? parentId;

  final bool isActive;
  final int sortOrder;

  const ArchiveCategory({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.label,
    this.parentId,
    this.isActive = true,
    this.sortOrder = 0,
  });

  bool get isRoot => parentId == null;

  factory ArchiveCategory.fromJson(Map<String, dynamic> json) {
    return ArchiveCategory(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      code: json['code'] as String,
      label: json['label'] as String,
      parentId: json['parent_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organization_id': organizationId,
        'code': code,
        'label': label,
        'parent_id': parentId,
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}
