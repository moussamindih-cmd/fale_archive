// ═══════════════════════════════════════════════════════════════════════════
// payment-initiate/index.ts
// POST — Crée une transaction et l'initie côté CinetPay
// Auth : JWT (admin uniquement)
// ═══════════════════════════════════════════════════════════════════════════

import { verifyAuth, getServiceClient, jsonResponse, corsHeaders } from '../_shared/auth.ts';
import { createPaymentProvider } from '../_shared/cinetpay.ts';
import { createPendingSubscription, attachTransactionReference } from '../_shared/subscription.ts';

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() });
  }

  try {
    // 1. Authentification — admin requis
    const auth = await verifyAuth(req, true);

    // 2. Lecture du corps
    const body = await req.json() as {
      plan_id: string;
      operator: 'moov' | 'airtel';
      phone_number: string;
    };

    if (!body.plan_id || !body.operator || !body.phone_number) {
      return jsonResponse({ error: 'plan_id, operator et phone_number sont requis' }, 400);
    }

    const serviceClient = getServiceClient();

    // 3. Créer la transaction en DB (status=pending)
    const subscription = await createPendingSubscription(serviceClient, {
      organizationId: auth.organizationId,
      planId: body.plan_id,
      operator: body.operator,
      phoneNumber: body.phone_number,
    });

    // 4. Initier le paiement côté CinetPay (clés API = côté serveur uniquement)
    const provider = createPaymentProvider();
    const webhookUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/payment-webhook`;

    const result = await provider.initiate({
      amount: subscription.amount,
      currency: subscription.currency,
      operator: body.operator,
      phoneNumber: body.phone_number,
      reference: subscription.id, // On utilise notre UUID comme référence
      description: `Abonnement FALE Archives`,
      notifyUrl: webhookUrl,
    });

    if (!result.success) {
      // Marquer comme failed en DB
      await serviceClient
        .from('subscriptions')
        .update({ payment_status: 'failed', metadata: { error: result.error } })
        .eq('id', subscription.id);

      return jsonResponse({ error: result.error ?? 'Échec de l\'initiation' }, 502);
    }

    // 5. Sauvegarder la référence du provider
    if (result.providerReference) {
      await attachTransactionReference(
        serviceClient,
        subscription.id,
        result.providerReference
      );
    }

    // 6. Retourner au client Flutter (jamais de clés API !)
    return jsonResponse({
      subscription_id: subscription.id,
      status: 'pending',
      payment_url: result.paymentUrl, // URL de paiement mobile si applicable
      message: 'Transaction initiée. Validez sur votre téléphone.',
    });

  } catch (err) {
    if (err instanceof Response) return err;
    console.error('[payment-initiate]', err);
    return jsonResponse({ error: 'Erreur interne du serveur' }, 500);
  }
});
