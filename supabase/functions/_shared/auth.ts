// ═══════════════════════════════════════════════════════════════════════════
// _shared/auth.ts — Vérification JWT + résolution de l'organization_id
// ═══════════════════════════════════════════════════════════════════════════

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export function getServiceClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, // Bypass RLS
    { auth: { persistSession: false } }
  );
}

export function getAnonClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
  );
}

export interface AuthResult {
  userId: string;
  organizationId: string;
  role: string;
}

/// Vérifie le JWT et retourne l'userId + organizationId
export async function verifyAuth(
  req: Request,
  requireAdmin = false
): Promise<AuthResult> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    throw jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const token = authHeader.replace('Bearer ', '');
  const client = getAnonClient();
  const { data: { user }, error } = await client.auth.getUser(token);

  if (error || !user) {
    throw jsonResponse({ error: 'Invalid token' }, 401);
  }

  // Récupérer le profil de l'employé (organization_id + role)
  const serviceClient = getServiceClient();
  const { data: emp } = await serviceClient
    .from('employees')
    .select('organization_id, role')
    .eq('id', user.id)
    .eq('is_active', true)
    .maybeSingle();

  // Un JWT valide ne suffit pas : sans fiche employé active, il n'y a ni
  // organisation ni rôle à appliquer. Retomber sur un tenant fictif
  // réadmettait les comptes désactivés et rattachait leurs écritures à une
  // organisation inexistante — on rejette.
  if (!emp?.organization_id) {
    throw jsonResponse({ error: 'Compte inactif ou non rattaché' }, 401);
  }

  const organizationId = emp.organization_id as string;
  const role = (emp.role as string | null) ?? 'employe';

  if (requireAdmin && role !== 'admin' && role !== 'superAdmin') {
    throw jsonResponse({ error: 'Admin role required' }, 403);
  }

  return {
    userId: user.id,
    organizationId,
    role,
  };
}

/// Valide la signature HMAC du webhook CinetPay
export async function verifyWebhookSignature(
  body: string,
  signatureHeader: string | null
): Promise<boolean> {
  const secret = Deno.env.get('BACKEND_WEBHOOK_SECRET');
  if (!secret || !signatureHeader) return false;

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(body));
  const expected = Array.from(new Uint8Array(signature))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');

  return timingSafeEqual(expected, signatureHeader);
}

/// Comparaison à durée constante.
///
/// `===` s'arrête au premier caractère différent : le temps de réponse
/// renseigne alors sur le nombre de caractères corrects, ce qui permet de
/// reconstituer une signature valide octet par octet. On compare donc toujours
/// la totalité de la chaîne.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(),
    },
  });
}

export function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, apikey, x-client-info',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  };
}

