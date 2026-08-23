// ═══════════════════════════════════════════════════════════════════════════
// signup-company — Inscription d'une entreprise et de son administrateur
//
// Étape 1 du parcours : l'email entreprise. Étape 2, obligatoire : le compte
// administrateur. Les deux arrivent ensemble ici.
//
// Pourquoi une fonction Edge : `20260822000000_rbac_rls.sql` n'a laissé aucune
// politique d'INSERT sur `organizations`, et `employees_insert` exige
// `has_role('superAdmin','admin')` — qu'un inscrit sans fiche employé ne peut
// satisfaire. Le service_role n'est pas soumis à la RLS ; c'est le seul chemin.
// ═══════════════════════════════════════════════════════════════════════════

import { getServiceClient, jsonResponse, corsHeaders } from '../_shared/auth.ts';
import {
  FREE_EMAIL_DOMAINS,
  checkFullName,
  checkPassword,
  domainOf,
  isValidEmail,
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

  const companyName = typeof body.companyName === 'string' ? body.companyName.trim() : '';
  const companyEmail = normalizeEmail(body.companyEmail);
  const adminEmail = normalizeEmail(body.adminEmail);
  const adminPersonalEmail = normalizeEmail(body.adminPersonalEmail);
  const adminFullName = typeof body.adminFullName === 'string' ? body.adminFullName.trim() : '';
  const password = body.password;

  // ─── Validation ────────────────────────────────────────────────────────
  if (companyName.length < 2) {
    return jsonResponse({ code: 'INVALID_COMPANY_NAME', error: "Le nom de l'entreprise est obligatoire." }, 400);
  }
  if (!isValidEmail(companyEmail)) {
    return jsonResponse({ code: 'INVALID_COMPANY_EMAIL', error: "L'email de l'entreprise est invalide." }, 400);
  }
  if (!isValidEmail(adminEmail)) {
    return jsonResponse({ code: 'INVALID_ADMIN_EMAIL', error: "L'email de l'administrateur est invalide." }, 400);
  }

  const nameError = checkFullName(adminFullName);
  if (nameError) return jsonResponse({ code: nameError.code, error: nameError.message }, 400);

  const passwordError = checkPassword(password);
  if (passwordError) return jsonResponse({ code: passwordError.code, error: passwordError.message }, 400);

  const companyDomain = domainOf(companyEmail);
  if (FREE_EMAIL_DOMAINS.has(companyDomain)) {
    return jsonResponse({
      code: 'FREE_EMAIL_DOMAIN',
      error: "Veuillez utiliser l'adresse professionnelle de votre entreprise, pas une messagerie grand public.",
    }, 400);
  }

  // La preuve de contrôle du domaine tient à ceci : l'administrateur doit être
  // joignable sur le domaine de l'entreprise, et son adresse est confirmée par
  // le mail que GoTrue lui envoie. Sans cette règle, n'importe qui déclarerait
  // « acme.com » et en réserverait la liste d'autorisation.
  if (domainOf(adminEmail) !== companyDomain) {
    return jsonResponse({
      code: 'ADMIN_DOMAIN_MISMATCH',
      error: `L'email de l'administrateur doit être sur le domaine @${companyDomain}.`,
    }, 400);
  }

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

  // ─── Unicité ───────────────────────────────────────────────────────────
  const { data: existingOrg } = await service
    .from('organizations')
    .select('id')
    .eq('email_domain', companyDomain)
    .maybeSingle();

  if (existingOrg) {
    return jsonResponse({
      code: 'COMPANY_ALREADY_REGISTERED',
      error: "Cette entreprise est déjà inscrite. Demandez à votre administrateur de vous ajouter à la liste des employés autorisés.",
    }, 409);
  }

  // `eq` et non `ilike` : `_` et `%` sont des jokers dans un motif LIKE, et
  // les adresses en contiennent couramment. Les écritures normalisent en
  // minuscules, la comparaison exacte suffit.
  const { data: existingEmployee } = await service
    .from('employees')
    .select('id')
    .eq('email', adminEmail)
    .maybeSingle();

  if (existingEmployee) {
    return jsonResponse({ code: 'EMAIL_TAKEN', error: 'Un compte avec cet email existe déjà.' }, 409);
  }

  // ─── Création ──────────────────────────────────────────────────────────
  // `email_confirm: false` laisse le compte non confirmé : c'est cette
  // confirmation qui vaut preuve de contrôle du domaine. Le client enchaîne
  // avec `auth.resend({type:'signup'})` — `admin.createUser` n'envoie pas de mail.
  const { data: created, error: createError } = await service.auth.admin.createUser({
    email: adminEmail,
    password: password as string,
    email_confirm: false,
    user_metadata: { full_name: adminFullName },
  });

  if (createError || !created?.user) {
    const message = createError?.message ?? '';
    if (message.includes('already registered') || message.includes('already been registered')) {
      return jsonResponse({ code: 'EMAIL_TAKEN', error: 'Un compte avec cet email existe déjà.' }, 409);
    }
    return jsonResponse({ code: 'AUTH_CREATE_FAILED', error: 'Création du compte impossible.' }, 500);
  }

  const userId = created.user.id;

  // GoTrue et Postgres ne partagent pas de transaction : toute erreur au-delà
  // de ce point doit défaire le compte Auth, sinon l'adresse reste prise par un
  // compte orphelin que plus rien ne peut réclamer.
  const rollback = async () => {
    try {
      await service.auth.admin.deleteUser(userId);
    } catch {
      // Le compte Auth reste orphelin — journalisé, mais on ne masque pas
      // l'erreur d'origine derrière l'échec du nettoyage.
      console.error('signup-company: nettoyage du compte Auth impossible', userId);
    }
  };

  const { data: org, error: orgError } = await service
    .from('organizations')
    .insert({
      name: companyName,
      company_email: companyEmail,
      email_domain: companyDomain,
      admin_id: userId,
    })
    .select('id')
    .single();

  if (orgError || !org) {
    await rollback();
    return jsonResponse({ code: 'ORG_CREATE_FAILED', error: "Création de l'entreprise impossible." }, 500);
  }

  const { error: employeeError } = await service.from('employees').insert({
    id: userId,
    organization_id: org.id,
    full_name: adminFullName,
    email: adminEmail,
    personal_email: adminPersonalEmail || null,
    password_hash: '',
    job_title: '',
    role: 'admin',
    is_active: true,
  });

  if (employeeError) {
    await service.from('organizations').delete().eq('id', org.id);
    await rollback();
    return jsonResponse({ code: 'PROFILE_CREATE_FAILED', error: 'Création du profil administrateur impossible.' }, 500);
  }

  return jsonResponse({
    ok: true,
    organizationId: org.id,
    needsEmailConfirmation: true,
  }, 201);
});
