// ═══════════════════════════════════════════════════════════════════════════
// _shared/subscription.ts — Logique métier pure (indépendante de l'opérateur)
// ═══════════════════════════════════════════════════════════════════════════

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export type PaymentStatus = 'pending' | 'paid' | 'failed' | 'expired';

export interface SubscriptionRow {
  id: string;
  organization_id: string;
  plan_id: string;
  amount: number;
  currency: string;
  operator: string;
  phone_number: string;
  transaction_reference: string | null;
  payment_status: PaymentStatus;
  expires_at: string | null;
  activated_at: string | null;
  metadata: Record<string, unknown>;
}

// ─── Créer une transaction (status=pending) ───────────────────────────────────

export async function createPendingSubscription(
  client: SupabaseClient,
  params: {
    organizationId: string;
    planId: string;
    operator: string;
    phoneNumber: string;
  }
): Promise<SubscriptionRow> {
  // Récupérer le montant du plan
  const { data: plan, error: planErr } = await client
    .from('subscription_plans')
    .select('amount, currency')
    .eq('id', params.planId)
    .single();

  if (planErr || !plan) throw new Error('Plan introuvable');

  const { data, error } = await client
    .from('subscriptions')
    .insert({
      organization_id: params.organizationId,
      plan_id: params.planId,
      amount: plan.amount,
      currency: plan.currency,
      operator: params.operator,
      phone_number: params.phoneNumber,
      payment_status: 'pending',
    })
    .select()
    .single();

  if (error || !data) throw new Error(`Erreur création subscription: ${error?.message}`);
  return data as SubscriptionRow;
}

// ─── Activer un abonnement (status: pending → paid) ───────────────────────────

export async function activateSubscription(
  client: SupabaseClient,
  subscriptionId: string,
  transactionReference: string,
  rawResponse: unknown = {}
): Promise<void> {
  // Récupérer la durée du plan pour calculer expires_at
  const { data: sub } = await client
    .from('subscriptions')
    .select('plan_id, created_at')
    .eq('id', subscriptionId)
    .single();

  if (!sub) throw new Error('Subscription introuvable');

  const { data: plan } = await client
    .from('subscription_plans')
    .select('duration_days')
    .eq('id', sub.plan_id)
    .single();

  const durationDays = plan?.duration_days ?? 30;
  const now = new Date();
  const expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);

  const { error } = await client
    .from('subscriptions')
    .update({
      payment_status: 'paid',
      transaction_reference: transactionReference,
      activated_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      metadata: rawResponse as Record<string, unknown>,
    })
    .eq('id', subscriptionId)
    .eq('payment_status', 'pending'); // Guard: ne jamais re-activer un déjà actif

  if (error) throw new Error(`Erreur activation: ${error.message}`);

  // Log d'audit
  await client.from('subscription_audit_log').insert({
    subscription_id: subscriptionId,
    old_status: 'pending',
    new_status: 'paid',
    reason: 'webhook_cinetpay',
  });
}

// ─── Marquer comme échoué ─────────────────────────────────────────────────────

export async function failSubscription(
  client: SupabaseClient,
  subscriptionId: string,
  reason = 'payment_failed'
): Promise<void> {
  await client
    .from('subscriptions')
    .update({ payment_status: 'failed' })
    .eq('id', subscriptionId)
    .eq('payment_status', 'pending');

  await client.from('subscription_audit_log').insert({
    subscription_id: subscriptionId,
    old_status: 'pending',
    new_status: 'failed',
    reason,
  });
}

// ─── Lier la référence de transaction à la subscription ──────────────────────

export async function attachTransactionReference(
  client: SupabaseClient,
  subscriptionId: string,
  reference: string
): Promise<void> {
  await client
    .from('subscriptions')
    .update({ transaction_reference: reference })
    .eq('id', subscriptionId);
}
