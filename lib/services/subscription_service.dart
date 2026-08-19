import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription.dart';

/// Service qui communique avec les Supabase Edge Functions.
/// NE PARLE JAMAIS directement à CinetPay — tout passe par le backend.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ─── Plans ────────────────────────────────────────────────────────────────

  /// Récupère les formules d'abonnement actives
  Future<List<SubscriptionPlan>> getPlans() async {
    final response = await _client
        .from('subscription_plans')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return (response as List)
        .map((j) => SubscriptionPlan.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ─── Statut de l'abonnement ───────────────────────────────────────────────

  /// Récupère l'état complet de l'abonnement de l'organisation
  Future<SubscriptionInfo> getSubscriptionInfo(
      String organizationId) async {
    // Abonnement actif (vue active_subscriptions)
    final activeRows = await _client
        .from('active_subscriptions')
        .select()
        .eq('organization_id', organizationId)
        .maybeSingle();

    // Historique complet (toutes transactions)
    final historyRows = await _client
        .from('subscriptions')
        .select('''
          *,
          subscription_plans(name)
        ''')
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false)
        .limit(50);

    SubscriptionTransaction? active;
    if (activeRows != null) {
      active = SubscriptionTransaction.fromJson(activeRows);
    }

    final history = (historyRows as List).map((row) {
      final map = row as Map<String, dynamic>;
      // Aplatir le nom du plan
      final planData = map['subscription_plans'] as Map<String, dynamic>?;
      map['plan_name'] = planData?['name'] ?? '';
      return SubscriptionTransaction.fromJson(map);
    }).toList();

    return SubscriptionInfo(
      activeTransaction: active,
      history: history,
    );
  }

  // ─── Initier un paiement ──────────────────────────────────────────────────

  /// Envoie une demande d'initiation de paiement à l'Edge Function.
  /// Retourne l'ID de la transaction créée (pending), ou une erreur.
  Future<({String? subscriptionId, String? error})> initiatePayment({
    required String organizationId,
    required String planId,
    required PaymentOperator operator,
    required String phoneNumber,
  }) async {
    try {
      final token = _client.auth.currentSession?.accessToken;
      if (token == null) return (subscriptionId: null, error: 'Non authentifié');

      final response = await _client.functions.invoke(
        'payment-initiate',
        body: {
          'organization_id': organizationId,
          'plan_id': planId,
          'operator': operator.name,
          'phone_number': phoneNumber,
        },
      );

      if (response.status != 200) {
        final msg = (response.data as Map?)?['error'] ?? 'Erreur inconnue';
        return (subscriptionId: null, error: msg.toString());
      }

      final id = (response.data as Map)['subscription_id'] as String?;
      return (subscriptionId: id, error: null);
    } catch (e) {
      return (subscriptionId: null, error: 'Erreur réseau : $e');
    }
  }

  // ─── Vérifier le statut d'une transaction ─────────────────────────────────

  /// Force une vérification du statut auprès de CinetPay (via Edge Function)
  Future<SubscriptionStatus> verifyPayment(String subscriptionId) async {
    try {
      final response = await _client.functions.invoke(
        'payment-verify',
        body: {'subscription_id': subscriptionId},
      );
      if (response.status != 200) return SubscriptionStatus.pending;
      final status = (response.data as Map)['status'] as String?;
      return SubscriptionStatus.fromString(status);
    } catch (_) {
      return SubscriptionStatus.pending;
    }
  }

  // ─── Poll jusqu'à confirmation ────────────────────────────────────────────

  /// Interroge le statut toutes les [intervalSeconds] secondes
  /// jusqu'à ce que le paiement soit confirmé (paid/failed) ou [timeout] dépassé.
  Stream<SubscriptionStatus> pollStatus({
    required String subscriptionId,
    Duration interval = const Duration(seconds: 8),
    Duration timeout = const Duration(minutes: 5),
  }) async* {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(interval);
      final status = await verifyPayment(subscriptionId);
      yield status;
      if (status == SubscriptionStatus.paid ||
          status == SubscriptionStatus.failed) {
        return;
      }
    }
    yield SubscriptionStatus.expired; // Timeout
  }
}
