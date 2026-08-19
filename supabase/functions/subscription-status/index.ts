// ═══════════════════════════════════════════════════════════════════════════
// subscription-status/index.ts
// GET — Retourne l'état complet de l'abonnement d'une organisation
// Auth : JWT (tout utilisateur authentifié de l'org)
// ═══════════════════════════════════════════════════════════════════════════

import { verifyAuth, getServiceClient, jsonResponse, corsHeaders } from '../_shared/auth.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() });
  }

  try {
    const auth = await verifyAuth(req, false);
    const serviceClient = getServiceClient();

    // Abonnement actif (via la vue)
    const { data: active } = await serviceClient
      .from('active_subscriptions')
      .select('*')
      .eq('organization_id', auth.organizationId)
      .maybeSingle();

    // Déclencher l'expiration automatique si nécessaire
    await serviceClient.rpc('expire_overdue_subscriptions');

    return jsonResponse({
      is_active: !!active,
      active_subscription: active,
      organization_id: auth.organizationId,
    });

  } catch (err) {
    if (err instanceof Response) return err;
    console.error('[subscription-status]', err);
    return jsonResponse({ error: 'Erreur interne' }, 500);
  }
});
