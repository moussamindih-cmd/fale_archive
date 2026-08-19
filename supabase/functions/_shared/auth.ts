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

  const organizationId = emp?.organization_id ?? 'org-creposa-default-id';
  const role = emp?.role ?? 'employe';

  if (requireAdmin && role !== 'admin') {
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

  return expected === signatureHeader;
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

