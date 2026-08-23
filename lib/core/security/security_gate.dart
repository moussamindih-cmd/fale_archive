import '../../models/employee.dart';
import '../../models/fale_permission.dart';

/// Refus d'exécution d'une action sensible.
class SecurityException implements Exception {
  final String message;
  final String action;
  final String resourceName;

  const SecurityException({
    required this.message,
    required this.action,
    required this.resourceName,
  });

  @override
  String toString() =>
      'SecurityException: $message (action: $action, ressource: $resourceName)';
}

/// Motif du refus, pour distinguer une erreur de cloisonnement d'un simple
/// manque de droit — les deux n'ont pas la même gravité dans le journal.
enum SecurityViolation {
  /// Tentative d'accès à une ressource d'une autre organisation.
  crossTenant('UNAUTHORIZED_MULTI_TENANT_ACCESS'),

  /// Droit manquant sur une ressource de sa propre organisation.
  missingPermission('UNAUTHORIZED_ACCESS_ATTEMPT'),

  /// Aucun utilisateur authentifié.
  notAuthenticated('UNAUTHENTICATED_ACCESS_ATTEMPT');

  final String code;
  const SecurityViolation(this.code);
}

/// Garde centrale des actions sensibles côté client.
///
/// **Ceci n'est pas la frontière de sécurité.** La frontière réelle, ce sont
/// les politiques RLS de Supabase : un client modifié peut contourner tout ce
/// qui suit. Cette garde sert à deux choses — n'afficher que des actions
/// réellement exécutables, et produire une trace exploitable quand une action
/// interdite est tentée.
///
/// Toute règle écrite ici doit avoir son équivalent en base.
class SecurityGate {
  static final SecurityGate _instance = SecurityGate._internal();
  factory SecurityGate() => _instance;
  SecurityGate._internal();

  static SecurityGate get instance => _instance;

  /// Appelé à chaque refus. Branché sur le journal d'audit au démarrage.
  void Function(SecurityViolation violation, String details)? onViolation;

  /// Vérifie le cloisonnement par organisation puis la matrice rôle → droit.
  ///
  /// [targetOrganizationId] est l'organisation **de la ressource visée**, pas
  /// celle de l'utilisateur : c'est la comparaison des deux qui fait le
  /// cloisonnement. Le laisser à `null` saute ce contrôle, à réserver aux
  /// ressources non rattachées à un tenant.
  bool canExecute({
    required Employee? user,
    String? targetOrganizationId,
    required FalePermission requiredPermission,
    required String actionName,
    required String resourceName,
  }) {
    if (user == null) {
      _report(
        SecurityViolation.notAuthenticated,
        'Tentative de $actionName sur [$resourceName] sans session active.',
      );
      return false;
    }

    // 1. Cloisonnement multi-entreprises (§5.5.1).
    if (targetOrganizationId != null &&
        !user.role.isCrossTenant &&
        user.organizationId != targetOrganizationId) {
      _report(
        SecurityViolation.crossTenant,
        'Violation de cloisonnement par ${user.email} '
        '(org ${user.organizationId}) sur une ressource de '
        'l\'org $targetOrganizationId [$resourceName].',
      );
      return false;
    }

    // 2. Matrice rôle → droit (§5.5.2).
    if (!user.role.hasPermission(requiredPermission)) {
      _report(
        SecurityViolation.missingPermission,
        'Accès refusé à ${user.fullName} (${user.role.name}) pour $actionName '
        'sur [$resourceName]. Droit requis : ${requiredPermission.code}.',
      );
      return false;
    }

    return true;
  }

  /// Exécute [action] si et seulement si l'accès est accordé, sinon journalise
  /// et lève une [SecurityException].
  T enforce<T>({
    required Employee? user,
    String? targetOrganizationId,
    required FalePermission requiredPermission,
    required String actionName,
    required String resourceName,
    required T Function() action,
  }) {
    final allowed = canExecute(
      user: user,
      targetOrganizationId: targetOrganizationId,
      requiredPermission: requiredPermission,
      actionName: actionName,
      resourceName: resourceName,
    );

    if (!allowed) {
      throw SecurityException(
        message: 'Action « $actionName » non autorisée sur $resourceName.',
        action: actionName,
        resourceName: resourceName,
      );
    }

    return action();
  }

  void _report(SecurityViolation violation, String details) {
    onViolation?.call(violation, details);
  }
}
