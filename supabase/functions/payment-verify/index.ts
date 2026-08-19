// ═══════════════════════════════════════════════════════════════════════════
// payment-verify/index.ts
// POST — Vérification manuelle du statut d'une transaction (polling Flutter)
// Auth : JWT (tout utilisateur authentifié de l'org)
// ═══════════════════════════════════════════════════════════════════════════

import { verifyAuth, getServiceClient, jsonResponse, corsHeaders } from '../_shared/auth.ts';
import { createPaymentProvider } from '../_shared/cinetpay.ts';
import { activateSubscription, failSubscription } from '../_shared/subscription.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() });
  }

  try {
    // 1. Authentification (pas besoin d'être admin pour vérifier son propre paiement)
    const auth = await verifyAuth(req, false);

    const body = await req.json() as { subscription_id: string };
    if (!body.subscription_id) {
      return jsonResponse({ error: 'subscription_id requis' }, 400);
    }

    const serviceClient = getServiceClient();

    // 2. Vérifier que la subscription appartient bien à l'organisation de l'utilisateur
    const { data: sub } = await serviceClient
      .from('subscriptions')
      .select('id, payment_status, transaction_reference, organization_id')
      .eq('id', body.subscription_id)
      .eq('organization_id', auth.organizationId) // Scoping par org
      .single();

    if (!sub) {
      return jsonResponse({ error: 'Subscription introuvable' }, 404);
    }

    // 3. Si déjà dans un état final, retourner directement
    if (sub.payment_status === 'paid' || sub.payment_status === 'failed') {
      return jsonResponse({ status: sub.payment_status });
    }

    // 4. Interroger CinetPay pour le statut réel
    const provider = createPaymentProvider();
    const confirmedStatus = await provider.checkStatus(sub.id);

    // 5. Mettre à jour si changement de statut
    if (confirmedStatus === 'paid' && sub.payment_status !== 'paid') {
      await activateSubscription(
        serviceClient,
        sub.id,
        sub.transaction_reference ?? sub.id,
        { source: 'manual_verify' }
      );
      return jsonResponse({ status: 'paid' });
    }

    if (confirmedStatus === 'failed' && sub.payment_status !== 'failed') {
      await failSubscription(serviceClient, sub.id, 'manual_verify_failed');
      return jsonResponse({ status: 'failed' });
    }

    return jsonResponse({ status: sub.payment_status });

  } catch (err) {
    if (err instanceof Response) return err;
    console.error('[payment-verify]', err);
    return jsonResponse({ error: 'Erreur interne' }, 500);
  }
});
