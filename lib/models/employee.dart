import 'fale_permission.dart';
import 'user_role.dart';

// Employee model — représente un compte employé
class Employee {
  final String id;
  final String fullName;
  final String email;
  final String? personalEmail;
  final String? avatarUrl;
  final String password; // stocké en clair pour la démo (en prod: hashé)
  final String
  jobTitle; // Secrétaire | Comptable | Gestionnaire | Conseiller Principal | Conseiller Adjoint
  final UserRole
  role; // Rôle fonctionnel : admin, directeurAdministratif, rh, employe
  final bool isActive;
  final String organizationId;
  final DateTime createdAt;

  const Employee({
    required this.id,
    required this.fullName,
    required this.email,
    this.personalEmail,
    this.avatarUrl,
    required this.password,
    this.jobTitle = '',
    this.role = UserRole.employe,
    this.isActive = true,
    required this.organizationId,
    required this.createdAt,
  });

  // Catégorie d'archive automatique selon le poste
  String get archiveCategory {
    switch (jobTitle) {
      case 'Secrétaire':
        return 'Courriers & Correspondances du jour';
      case 'Comptable':
        return 'Pièces Comptables & Journal de Caisse';
      case 'Gestionnaire':
        return 'Dossiers Opérationnels & Rapports';
      case 'Conseiller Principal':
        return 'Avis Techniques & Expertises';
      case 'Conseiller Adjoint':
        return 'Synthèses & Notes de Projets';
      default:
        return 'Documents du jour';
    }
  }

  // Initiales pour l avatar
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.substring(0, 1).toUpperCase();
  }

  /// Vérifie si l'employé occupe un rôle de supervision (Admin, DA, RH).
  bool get isSupervisor => role.isSupervisor;

  /// Raccourci de vérification des droits — évite d'aller chercher la matrice
  /// via `employee.role.hasPermission(...)` à chaque appel dans l'UI.
  bool can(FalePermission permission) => role.hasPermission(permission);

  /// Libellé complet pour l'affichage (rôle + poste si applicable)
  String get displayRole {
    if (role == UserRole.employe && jobTitle.isNotEmpty) {
      return jobTitle;
    }
    return role.label;
  }

  /// Copie avec modifications
  Employee copyWith({
    String? id,
    String? fullName,
    String? email,
    String? personalEmail,
    String? avatarUrl,
    String? password,
    String? jobTitle,
    UserRole? role,
    bool? isActive,
    String? organizationId,
    DateTime? createdAt,
  }) {
    return Employee(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      personalEmail: personalEmail ?? this.personalEmail,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      password: password ?? this.password,
      jobTitle: jobTitle ?? this.jobTitle,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'personalEmail': personalEmail,
    'avatarUrl': avatarUrl,
    'password': password,
    'jobTitle': jobTitle,
    'role': role.name,
    'isActive': isActive,
    'organizationId': organizationId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      personalEmail: json['personalEmail'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      password: json['password'] as String,
      jobTitle: json['jobTitle'] as String? ?? '',
      role: UserRole.fromName(json['role'] as String?),
      isActive: json['isActive'] as bool? ?? true,
      organizationId: json['organizationId'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
