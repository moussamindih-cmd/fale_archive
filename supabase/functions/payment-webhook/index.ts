// ═══════════════════════════════════════════════════════════════════════════
// payment-webhook/index.ts
// POST — Reçoit les callbacks de CinetPay et active/échoue les abonnements
// Auth : Signature HMAC (serveur→serveur, jamais exposé au client Flutter)
// ═══════════════════════════════════════════════════════════════════════════

import { getServiceClient, jsonResponse, verifyWebhookSignature } from '../_shared/auth.ts';
import { createPaymentProvider } from '../_shared/cinetpay.ts';
import { activateSubscription, failSubscription } from '../_shared/subscription.ts';

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const rawBody = await req.text();

  // 1. Vérifier la signature HMAC (protège contre les appels frauduleux)
  const signature = req.headers.get('x-cinetpay-signature') ??
                    req.headers.get('x-webhook-signature');
  const isValid = await verifyWebhookSignature(rawBody, signature);

  if (!isValid) {
    console.warn('[payment-webhook] Signature invalide — requête rejetée');
    return jsonResponse({ error: 'Invalid signature' }, 401);
  }

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody) as Record<string, unknown>;
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  // CinetPay envoie transaction_id = notre subscription.id (UUID)
  const subscriptionId = payload['transaction_id'] as string | undefined;
  if (!subscriptionId) {
    return jsonResponse({ error: 'transaction_id manquant' }, 400);
  }

  const serviceClient = getServiceClient();

  // 2. Vérifier indépendamment le statut auprès de CinetPay
  //    IMPORTANT : Ne jamais faire confiance au body du webhook seul !
  const provider = createPaymentProvider();
  const confirmedStatus = await provider.checkStatus(subscriptionId);

  console.log(`[payment-webhook] subscription=${subscriptionId} status=${confirmedStatus}`);

  // 3. Agir selon le statut confirmé
  if (confirmedStatus === 'paid') {
    await activateSubscription(
      serviceClient,
      subscriptionId,
      payload['transaction_id'] as string,
      payload
    );
    return jsonResponse({ success: true, status: 'paid' });
  }

  if (confirmedStatus === 'failed') {
    await failSubscription(serviceClient, subscriptionId, 'webhook_failed');
    return jsonResponse({ success: true, status: 'failed' });
  }

  // Statut pending : rien à faire, laisser le poll Flutter gérer
  return jsonResponse({ success: true, status: 'pending' });
});
