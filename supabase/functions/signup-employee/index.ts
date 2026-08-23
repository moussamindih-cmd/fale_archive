// ═══════════════════════════════════════════════════════════════════════════
// signup-employee — Inscription d'un employé, sous réserve d'autorisation
//
// Le cœur de la règle : l'adresse professionnelle saisie est confrontée à
// `allowed_employee_emails`, la liste tenue par l'administrateur de l'entreprise.
// Absente de la liste, aucun compte n'est créé.
//
// Le rôle, le poste et l'organisation sont lus SUR LA LIGNE DE LA LISTE — jamais
// dans le corps de la requête. Les accepter du client laisserait n'importe qui
// se déclarer administrateur.
// ═══════════════════════════════════════════════════════════════════════════

import { getServiceClient, jsonResponse, corsHeaders } from '../_shared/auth.ts';
import {
  checkFullName,
  checkPassword,
  isValidEmail,
  maxUsersFor,
  normalizeEmail,
} from '../_shared/signup.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ code: 'METHOD_NOT_ALLOWED', error: 'Méthode non autorisée.' }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ code: 'BAD_REQUEST', error: 'Requête illisible.' }, 400);
  }

  const email = normalizeEmail(body.email);
  const personalEmail = normalizeEmail(body.personalEmail);
  const fullName = typeof body.fullName === 'string' ? body.fullName.trim() : '';
  const password = body.password;

  if (!isValidEmail(email)) {
    return jsonResponse({ code: 'INVALID_EMAIL', error: 'Email professionnel invalide.' }, 400);
  }

  const nameError = checkFullName(fullName);
  if (nameError) return jsonResponse({ code: nameError.code, error: nameError.message }, 400);

  const passwordError = checkPassword(password);
  if (passwordError) return jsonResponse({ code: passwordError.code, error: passwordError.message }, 400);

  let service;
  try {
    service = getServiceClient();
  } catch (e) {
    // Défaut de configuration du projet, pas de la requête. Le remonter tel
    // quel : déguisé en « création impossible », il envoyait chercher la panne
    // du mauvais côté. Le message ne nomme que des variables d'environnement,
    // jamais leur valeur.
    return jsonResponse({
      code: 'SERVICE_KEY_MISSING',
      error: e instanceof Error ? e.message : String(e),
    }, 500);
  }

  // ─── Confrontation à la liste d'autorisation ───────────────────────────
  // `eq` et non `ilike` : dans un motif LIKE, `_` vaut « un caractère
  // quelconque » et `%` « n'importe quoi ». Une adresse autorisée
  // `bob_smith@acme.test` aurait donc laissé s'inscrire `bobXsmith@acme.test`.
  // Toutes les écritures normalisent l'adresse en minuscules, la comparaison
  // exacte est donc à la fois sûre et suffisante.
  const { data: allowed } = await service
    .from('allowed_employee_emails')
    .select('id, organization_id, role, job_title, full_name, status')
    .eq('email', email)
    .maybeSingle();

  if (!allowed || allowed.status === 'revoked') {
    return jsonResponse({
      code: 'EMAIL_NOT_ALLOWED',
      error: "Cette adresse ne figure pas dans la liste des employés autorisés par votre entreprise. Contactez votre administrateur.",
    }, 403);
  }

  if (allowed.status === 'registered') {
    return jsonResponse({
      code: 'ALREADY_REGISTERED',
      error: 'Un compte existe déjà pour cette adresse. Connectez-vous ou réinitialisez votre mot de passe.',
    }, 409);
  }

  const organizationId = allowed.organization_id as string;

  // Ceinture et bretelles : la liste peut avoir été remplie avant qu'un compte
  // soit créé autrement (reprise de données, script). On ne veut pas d'un
  // second compte sur la même adresse.
  const { data: existingEmployee } = await service
    .from('employees')
    .select('id')
    .eq('email', email)
    .maybeSingle();

  if (existingEmployee) {
    await service
      .from('allowed_employee_emails')
      .update({ status: 'registered', claimed_by: existingEmployee.id })
      .eq('id', allowed.id);
    return jsonResponse({
      code: 'ALREADY_REGISTERED',
      error: 'Un compte existe déjà pour cette adresse. Connectez-vous ou réinitialisez votre mot de passe.',
    }, 409);
  }

  // ─── Quota ─────────────────────────────────────────────────────────────
  // Ce contrôle vivait côté client (`app_state.dart:339`) et ne s'exécutait que
  // si un admin était connecté. L'employé s'inscrivant seul, il doit être ici.
  const maxUsers = await maxUsersFor(service, organizationId);
  const { count } = await service
    .from('employees')
    .select('id', { count: 'exact', head: true })
    .eq('organization_id', organizationId)
    .eq('is_active', true);

  if (maxUsers < 9999 && (count ?? 0) >= maxUsers) {
    return jsonResponse({
      code: 'QUOTA_REACHED',
      error: "Le nombre de comptes autorisés par l'abonnement de votre entreprise est atteint. Contactez votre administrateur.",
    }, 409);
  }

  // ─── Création ──────────────────────────────────────────────────────────
  const { data: created, error: createError } = await service.auth.admin.createUser({
    email,
    password: password as string,
    email_confirm: false,
    user_metadata: { full_name: fullName },
  });

  if (createError || !created?.user) {
    const message = createError?.message ?? '';
    if (message.includes('already registered') || message.includes('already been registered')) {
      return jsonResponse({
        code: 'ALREADY_REGISTERED',
        error: 'Un compte existe déjà pour cette adresse. Connectez-vous ou réinitialisez votre mot de passe.',
      }, 409);
    }
    return jsonResponse({ code: 'AUTH_CREATE_FAILED', error: 'Création du compte impossible.' }, 500);
  }

  const userId = created.user.id;

  // Le rôle et le poste viennent de la liste, pas de la requête.
  const { error: employeeError } = await service.from('employees').insert({
    id: userId,
    organization_id: organizationId,
    full_name: fullName,
    email,
    personal_email: personalEmail || null,
    password_hash: '',
    job_title: (allowed.job_title as string | null) ?? '',
    role: allowed.role as string,
    is_active: true,
  });

  if (employeeError) {
    // Sans ce nettoyage, l'adresse resterait prise par un compte Auth sans
    // profil : la liste la dirait « en attente » et toute nouvelle tentative
    // échouerait sur « déjà enregistré ».
    try {
      await service.auth.admin.deleteUser(userId);
    } catch {
      console.error('signup-employee: nettoyage du compte Auth impossible', userId);
    }
    return jsonResponse({ code: 'PROFILE_CREATE_FAILED', error: 'Création du profil impossible.' }, 500);
  }

  await service
    .from('allowed_employee_emails')
    .update({
      status: 'registered',
      claimed_by: userId,
      claimed_at: new Date().toISOString(),
    })
    .eq('id', allowed.id);

  return jsonResponse({
    ok: true,
    organizationId,
    role: allowed.role,
    needsEmailConfirmation: true,
  }, 201);
});
