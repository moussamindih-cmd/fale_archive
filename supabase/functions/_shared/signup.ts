// ═══════════════════════════════════════════════════════════════════════════
// _shared/signup.ts — Règles d'inscription communes aux deux points d'entrée
//
// Ces constantes ont un jumeau côté Dart (`lib/models/signup_rules.dart`).
// Le serveur fait foi : le client ne pré-valide que pour éviter un aller-retour.
// ═══════════════════════════════════════════════════════════════════════════

/// Domaines de messagerie grand public — une entreprise ne s'inscrit pas avec.
/// Liste reprise de `register_screen.dart:322` où elle était codée en dur, et
/// où elle n'était appliquée que par le formulaire : tout appel direct à l'API
/// la contournait.
export const FREE_EMAIL_DOMAINS: ReadonlySet<string> = new Set([
  'gmail.com', 'yahoo.com', 'yahoo.fr', 'hotmail.com',
  'hotmail.fr', 'outlook.com', 'outlook.fr', 'live.com',
  'live.fr', 'icloud.com', 'me.com', 'mac.com',
  'msn.com', 'aol.com', 'orange.fr', 'free.fr',
  'sfr.fr', 'bbox.fr', 'laposte.net', 'ymail.com',
]);

/// Rôles qu'un administrateur peut attribuer. `superAdmin` en est absent :
/// il traverse les organisations et reste réservé à la plateforme.
export const ASSIGNABLE_ROLES: ReadonlySet<string> = new Set([
  'admin', 'directeurAdministratif', 'rh', 'employe',
]);

/// Aligné sur `changePassword` (`app_state.dart:427`), qui exigeait déjà 8
/// caractères là où l'inscription se contentait de 6.
export const MIN_PASSWORD_LENGTH = 8;

/// Plafond d'utilisateurs quand l'organisation n'a aucun abonnement actif.
///
/// Le contrôle de quota vivait côté client (`app_state.dart:339`) et retombait
/// sur `?? 1`, ce qui interdisait tout second compte. Il ne peut de toute façon
/// plus s'y trouver : l'employé s'inscrit sans être connecté.
export const FREE_TIER_MAX_USERS = 5;

export function normalizeEmail(raw: unknown): string {
  return typeof raw === 'string' ? raw.trim().toLowerCase() : '';
}

export function domainOf(email: string): string {
  const at = email.lastIndexOf('@');
  return at === -1 ? '' : email.slice(at + 1);
}

/// Validation volontairement simple : la vraie preuve d'existence d'une adresse
/// est le mail de confirmation, pas une expression régulière.
export function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export interface FieldError {
  code: string;
  message: string;
}

export function checkPassword(password: unknown): FieldError | null {
  if (typeof password !== 'string' || password.length < MIN_PASSWORD_LENGTH) {
    return {
      code: 'WEAK_PASSWORD',
      message: `Le mot de passe doit comporter au moins ${MIN_PASSWORD_LENGTH} caractères.`,
    };
  }
  return null;
}

export function checkFullName(fullName: unknown): FieldError | null {
  if (typeof fullName !== 'string' || fullName.trim().length < 2) {
    return { code: 'INVALID_NAME', message: 'Le nom complet est obligatoire.' };
  }
  return null;
}

/// Nombre d'utilisateurs actifs autorisés pour cette organisation.
///
/// Lit `active_subscriptions` (20260822000200_subscription_objects.sql), qui
/// porte déjà `max_users` et la période de grâce. Sans abonnement actif, on
/// retombe sur l'offre gratuite plutôt que de bloquer l'organisation.
// deno-lint-ignore no-explicit-any
export async function maxUsersFor(
  serviceClient: any,
  organizationId: string,
): Promise<number> {
  const { data } = await serviceClient
    .from('active_subscriptions')
    .select('max_users')
    .eq('organization_id', organizationId)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  return (data?.max_users as number | undefined) ?? FREE_TIER_MAX_USERS;
}
