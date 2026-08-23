import 'user_role.dart';

/// Où en est une adresse pré-autorisée par l'administrateur.
enum AllowedEmailStatus {
  /// Enregistrée par l'admin, pas encore utilisée pour créer un compte.
  pending('pending', 'En attente'),

  /// Un compte a été créé avec cette adresse.
  registered('registered', 'Inscrit'),

  /// Retirée par l'admin : l'inscription est refusée.
  revoked('revoked', 'Révoqué');

  final String code;
  final String label;

  const AllowedEmailStatus(this.code, this.label);

  /// Retombe sur [revoked] — le statut le moins permissif — si la valeur lue
  /// est inconnue. Un statut illisible ne doit pas ouvrir une inscription.
  static AllowedEmailStatus fromCode(String? code) {
    for (final status in AllowedEmailStatus.values) {
      if (status.code == code) return status;
    }
    return AllowedEmailStatus.revoked;
  }
}

/// Une adresse professionnelle autorisée à créer un compte dans l'organisation.
///
/// C'est cette table que la fonction Edge `signup-employee` interroge : une
/// adresse qui n'y figure pas ne donne aucun compte. Le [role] et le [jobTitle]
/// sont fixés ici par l'administrateur et repris tels quels à l'inscription —
/// l'employé ne les choisit jamais.
class AllowedEmail {
  final String id;
  final String organizationId;
  final String email;

  /// Facultatif : saisi par l'admin pour se relire, pré-remplit le formulaire.
  final String? fullName;

  final UserRole role;
  final String jobTitle;
  final AllowedEmailStatus status;
  final String? invitedBy;
  final String? claimedBy;
  final DateTime? claimedAt;
  final DateTime createdAt;

  const AllowedEmail({
    required this.id,
    required this.organizationId,
    required this.email,
    this.fullName,
    this.role = UserRole.employe,
    this.jobTitle = '',
    this.status = AllowedEmailStatus.pending,
    this.invitedBy,
    this.claimedBy,
    this.claimedAt,
    required this.createdAt,
  });

  /// Vrai si une inscription est encore possible sur cette adresse.
  bool get isClaimable => status == AllowedEmailStatus.pending;

  /// Une entrée déjà consommée ne s'efface pas : elle se révoque, sinon le
  /// compte créé perd la trace de son autorisation.
  bool get isDeletable => status != AllowedEmailStatus.registered;

  /// Libellé rôle + poste, comme `Employee.displayRole`.
  String get displayRole {
    if (role == UserRole.employe && jobTitle.isNotEmpty) return jobTitle;
    return role.label;
  }

  AllowedEmail copyWith({
    String? fullName,
    UserRole? role,
    String? jobTitle,
    AllowedEmailStatus? status,
  }) {
    return AllowedEmail(
      id: id,
      organizationId: organizationId,
      email: email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      jobTitle: jobTitle ?? this.jobTitle,
      status: status ?? this.status,
      invitedBy: invitedBy,
      claimedBy: claimedBy,
      claimedAt: claimedAt,
      createdAt: createdAt,
    );
  }

  factory AllowedEmail.fromJson(Map<String, dynamic> json) {
    final role = UserRole.fromName(json['role'] as String?);
    return AllowedEmail(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String? ?? '',
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      // `superAdmin` est interdit par le CHECK en base, mais une ligne écrite
      // hors application ne doit pas non plus le faire remonter dans l'UI.
      role: role == UserRole.superAdmin ? UserRole.admin : role,
      jobTitle: json['job_title'] as String? ?? '',
      status: AllowedEmailStatus.fromCode(json['status'] as String?),
      invitedBy: json['invited_by'] as String?,
      claimedBy: json['claimed_by'] as String?,
      claimedAt: json['claimed_at'] == null
          ? null
          : DateTime.parse(json['claimed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
