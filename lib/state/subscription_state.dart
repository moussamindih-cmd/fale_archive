import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';

/// Gère l'état de l'abonnement de l'organisation.
/// S'intègre avec ChangeNotifier (cohérent avec AppState, CandidatesState, etc.)
class SubscriptionState extends ChangeNotifier {
  final _service = SubscriptionService.instance;

  SubscriptionInfo _info = const SubscriptionInfo(history: []);
  List<SubscriptionPlan> _plans = [];
  bool _isLoading = false;
  bool _isPaying = false;
  String? _error;
  String? _pendingSubscriptionId;
  SubscriptionStatus _pollStatus = SubscriptionStatus.none;

  // ─── Getters ──────────────────────────────────────────────────────────────
  SubscriptionInfo get info => _info;
  List<SubscriptionPlan> get plans => _plans;
  bool get isLoading => _isLoading;
  bool get isPaying => _isPaying;
  String? get error => _error;
  String? get pendingSubscriptionId => _pendingSubscriptionId;
  SubscriptionStatus get pollStatus => _pollStatus;

  /// true si l'organisation a un abonnement actif et non expiré
  bool get isActive => _info.isActive;

  /// Transaction active (ou null)
  SubscriptionTransaction? get activeTransaction => _info.activeTransaction;

  /// Historique complet des transactions
  List<SubscriptionTransaction> get history => _info.history;

  // ─── Chargement ───────────────────────────────────────────────────────────

  Future<void> load(String organizationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getSubscriptionInfo(organizationId),
        _service.getPlans(),
      ]);
      _info = results[0] as SubscriptionInfo;
      _plans = results[1] as List<SubscriptionPlan>;
    } catch (e) {
      _error = 'Impossible de charger l\'abonnement : $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Initier un paiement ──────────────────────────────────────────────────

  Future<String?> initiatePayment({
    required String organizationId,
    required String planId,
    required PaymentOperator operator,
    required String phoneNumber,
  }) async {
    _isPaying = true;
    _error = null;
    _pendingSubscriptionId = null;
    _pollStatus = SubscriptionStatus.pending;
    notifyListeners();

    final result = await _service.initiatePayment(
      organizationId: organizationId,
      planId: planId,
      operator: operator,
      phoneNumber: phoneNumber,
    );

    if (result.error != null) {
      _isPaying = false;
      _error = result.error;
      _pollStatus = SubscriptionStatus.failed;
      notifyListeners();
      return result.error;
    }

    _pendingSubscriptionId = result.subscriptionId;
    notifyListeners();

    // Lancer le poll automatique
    _startPolling(organizationId, result.subscriptionId!);
    return null;
  }

  // ─── Polling automatique ──────────────────────────────────────────────────

  void _startPolling(String organizationId, String subscriptionId) {
    _service
        .pollStatus(subscriptionId: subscriptionId)
        .listen((status) async {
      _pollStatus = status;
      notifyListeners();

      if (status == SubscriptionStatus.paid ||
          status == SubscriptionStatus.failed) {
        _isPaying = false;
        _pendingSubscriptionId = null;
        // Recharger les données fraîches
        await load(organizationId);
      }
    });
  }

  // ─── Rafraîchissement manuel ──────────────────────────────────────────────

  Future<void> refresh(String organizationId) => load(organizationId);

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
