import '../../data/models/user.dart';
import '../../data/models/permission.dart';

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
  String toString() => 'SecurityException: $message (Action: $action, Resource: $resourceName)';
}

class SecurityManager {
  static final SecurityManager _instance = SecurityManager._internal();
  factory SecurityManager() => _instance;
  SecurityManager._internal();

  /// Vérification d'accès stricte multi-tenant et matrice Rôle -> Permission.
  /// Renvoie `true` si l'accès est valide.
  /// Renvoie `false` et/ou lève une alerte d'accès si violation.
  bool canExecute({
    required User user,
    required String targetOrganizationId,
    required AppPermission requiredPermission,
    required String actionName,
    required String resourceName,
    void Function(String action, String details)? onViolationLogged,
  }) {
    // 1. Contrôle Multi-Tenant : L'utilisateur doit appartenir à l'organisation ciblée (ou être SuperAdmin)
    final bool isSuperAdmin = user.role.id == 'role_super_admin';
    final bool isSameOrg = user.organizationId == targetOrganizationId;

    if (!isSuperAdmin && !isSameOrg) {
      final details = 'Tentative de violation multi-tenant par ${user.email} (Org: ${user.organizationId}) sur ressource Org: $targetOrganizationId [$resourceName]';
      onViolationLogged?.call('UNAUTHORIZED_MULTI_TENANT_ACCESS', details);
      return false;
    }

    // 2. Contrôle de la matrice Rôle -> AppPermission
    final bool hasPerm = user.role.hasPermission(requiredPermission);
    if (!hasPerm) {
      final details = 'Accès refusé pour ${user.fullName} (${user.role.name}) sur $actionName de [$resourceName]. Permission requise : ${requiredPermission.code}';
      onViolationLogged?.call('UNAUTHORIZED_ACCESS_ATTEMPT', details);
      return false;
    }

    return true;
  }

  /// Exécute une action sensible uniquement si la validation de sécurité est réussie.
  /// Si la validation échoue, déclenche la journalisation et lève une [SecurityException].
  void enforceAction({
    required User user,
    required String targetOrganizationId,
    required AppPermission requiredPermission,
    required String actionName,
    required String resourceName,
    required void Function() action,
    required void Function(String action, String details) onViolationLogged,
  }) {
    final allowed = canExecute(
      user: user,
      targetOrganizationId: targetOrganizationId,
      requiredPermission: requiredPermission,
      actionName: actionName,
      resourceName: resourceName,
      onViolationLogged: onViolationLogged,
    );

    if (!allowed) {
      throw SecurityException(
        message: 'Action $actionName sur $resourceName non autorisée pour le rôle ${user.role.name}.',
        action: actionName,
        resourceName: resourceName,
      );
    }

    action();
  }
}
