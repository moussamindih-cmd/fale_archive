import 'package:flutter/foundation.dart';

import '../models/job_offer.dart';
import '../services/supabase_service.dart';

/// État du module « Offres d'emploi » (§5.2).
class JobOffersState extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService.instance;

  List<JobOffer> _offers = [];
  List<JobOffer> _templates = [];
  bool _isLoading = false;
  String? _error;

  List<JobOffer> get offers => List.unmodifiable(_offers);
  List<JobOffer> get templates => List.unmodifiable(_templates);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Offres visibles des candidats externes — ce que la page publique
  /// différée affichera, calculé ici pour que les compteurs de l'interface
  /// interne disent déjà la vérité.
  List<JobOffer> get publiclyVisible =>
      _offers.where((o) => o.isPubliclyVisible).toList();

  /// Offres en attente d'une décision de validation (§5.2.2).
  List<JobOffer> get awaitingValidation => _offers
      .where((o) => o.workflowStatus == OfferWorkflowStatus.enValidation)
      .toList();

  /// Offres publiées dont l'échéance approche — sans cela, une offre expire
  /// sans que personne ne s'en aperçoive.
  List<JobOffer> expiringSoon({int withinDays = 7}) => _offers.where((o) {
        if (!o.isPubliclyVisible) return false;
        final days = o.daysUntilDeadline;
        return days != null && days >= 0 && days <= withinDays;
      }).toList();

  JobOffer? byId(String id) {
    for (final o in _offers) {
      if (o.id == id) return o;
    }
    for (final t in _templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Filtrage multicritère sur les deux axes de statut.
  List<JobOffer> filtered({
    OfferWorkflowStatus? workflow,
    OfferLifecycleStatus? lifecycle,
    ContractType? contract,
    String keyword = '',
  }) {
    final kw = keyword.trim().toLowerCase();
    return _offers.where((o) {
      if (workflow != null && o.workflowStatus != workflow) return false;
      if (lifecycle != null && o.lifecycleStatus != lifecycle) return false;
      if (contract != null && o.contractType != contract) return false;
      if (kw.isEmpty) return true;
      return o.title.toLowerCase().contains(kw) ||
          o.reference.toLowerCase().contains(kw) ||
          (o.location ?? '').toLowerCase().contains(kw) ||
          o.skills.any((s) => s.toLowerCase().contains(kw));
    }).toList();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _offers = await _supabase.fetchJobOffers();
      _templates = await _supabase.fetchJobOfferTemplates();
    } catch (e) {
      _error = 'Chargement des offres impossible : $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Exécute une opération et recharge. Retourne `null` en cas de succès,
  /// sinon le message d'erreur déjà traduit pour l'utilisateur.
  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return null;
    } on JobOfferException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur : $e';
    }
  }

  Future<String?> create(JobOffer offer, {bool asTemplate = false}) =>
      _run(() => _supabase.createJobOffer(offer, asTemplate: asTemplate));

  Future<String?> update(String id, JobOffer offer) =>
      _run(() => _supabase.updateJobOffer(id, offer));

  Future<String?> submitForValidation(String id) => _run(() =>
      _supabase.changeOfferWorkflow(
          id: id, status: OfferWorkflowStatus.enValidation));

  Future<String?> publish(String id) => _run(() => _supabase.changeOfferWorkflow(
      id: id, status: OfferWorkflowStatus.publiee));

  Future<String?> reject(String id, String reason) {
    if (reason.trim().isEmpty) {
      return Future.value('Merci d\'indiquer le motif du rejet.');
    }
    return _run(() => _supabase.changeOfferWorkflow(
        id: id, status: OfferWorkflowStatus.rejetee, reason: reason.trim()));
  }

  Future<String?> returnToDraft(String id) => _run(() =>
      _supabase.changeOfferWorkflow(
          id: id, status: OfferWorkflowStatus.brouillon));

  Future<String?> changeLifecycle(String id, OfferLifecycleStatus status) =>
      _run(() => _supabase.changeOfferLifecycle(id: id, status: status));

  Future<String?> duplicate(String id, {bool asTemplate = false, String? title}) =>
      _run(() => _supabase.duplicateJobOffer(id,
          asTemplate: asTemplate, title: title));

  Future<String?> delete(String id) => _run(() => _supabase.deleteJobOffer(id));

  Future<List<JobOfferTransition>> transitionsOf(String id) =>
      _supabase.fetchOfferTransitions(id);

  /// Vide l'état à la déconnexion : les offres d'une organisation ne doivent
  /// pas survivre au changement de compte.
  void clear() {
    _offers = [];
    _templates = [];
    _error = null;
    notifyListeners();
  }
}
