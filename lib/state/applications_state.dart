import 'package:flutter/foundation.dart';

import '../models/application.dart';
import '../services/supabase_service.dart';

/// État du module « Suivi des candidatures » (§5.3).
class ApplicationsState extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService.instance;

  List<PipelineStage> _stages = [];
  List<Application> _applications = [];
  List<Interview> _interviews = [];
  bool _isLoading = false;
  String? _error;

  List<PipelineStage> get stages => List.unmodifiable(_stages);
  List<Application> get applications => List.unmodifiable(_applications);
  List<Interview> get interviews => List.unmodifiable(_interviews);
  bool get isLoading => _isLoading;
  String? get error => _error;

  PipelineStage? stageById(String? id) {
    if (id == null) return null;
    for (final s in _stages) {
      if (s.id == id) return s;
    }
    return null;
  }

  PipelineStage? get wonStage {
    for (final s in _stages) {
      if (s.isWon) return s;
    }
    return null;
  }

  /// Étapes non terminales, dans l'ordre — les colonnes du tableau.
  List<PipelineStage> get openStages =>
      _stages.where((s) => !s.isTerminal).toList();

  List<PipelineStage> get terminalStages =>
      _stages.where((s) => s.isTerminal).toList();

  /// Candidatures d'une étape donnée, éventuellement restreintes à une offre.
  List<Application> inStage(String stageId, {String? jobOfferId}) {
    return _applications.where((a) {
      if (a.stageId != stageId) return false;
      if (jobOfferId != null && a.jobOfferId != jobOfferId) return false;
      return true;
    }).toList();
  }

  List<Application> get openApplications =>
      _applications.where((a) => a.isOpen).toList();

  /// Candidatures qui dépassent le délai de leur étape (§5.3.6).
  ///
  /// C'est ce qui fait remonter les dossiers oubliés : sans indicateur, une
  /// candidature peut stagner des mois sans que personne ne le voie.
  List<Application> get stalled {
    return _applications.where((a) {
      final stage = stageById(a.stageId);
      return stage != null && a.isStalled(stage);
    }).toList();
  }

  /// Entretiens à venir, du plus proche au plus lointain.
  List<Interview> get upcomingInterviews {
    final list = _interviews.where((i) => i.isUpcoming).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  // ── Indicateurs (§5.4.1) ────────────────────────────────────────────────

  /// Délai moyen de recrutement, en jours, sur les candidatures abouties.
  ///
  /// Retourne `null` s'il n'y a aucun recrutement : afficher « 0 jour »
  /// laisserait croire à un recrutement instantané.
  double? get averageTimeToHire {
    final won = wonStage;
    if (won == null) return null;
    final hired = _applications
        .where((a) => a.stageId == won.id && a.closedAt != null)
        .toList();
    if (hired.isEmpty) return null;
    final total = hired.fold<int>(
        0, (sum, a) => sum + a.closedAt!.difference(a.appliedAt).inDays);
    return total / hired.length;
  }

  /// Taux de conversion global : recrutements sur candidatures closes.
  ///
  /// Les candidatures encore en cours sont exclues du dénominateur — les
  /// compter comme des échecs sous-estimerait mécaniquement le taux.
  double? get conversionRate {
    final won = wonStage;
    if (won == null) return null;
    final closed = _applications.where((a) => !a.isOpen).length;
    if (closed == 0) return null;
    final hired = _applications.where((a) => a.stageId == won.id).length;
    return hired / closed;
  }

  /// Répartition par source de candidature.
  Map<ApplicationSource, int> get bySource {
    final counts = <ApplicationSource, int>{};
    for (final a in _applications) {
      counts[a.source] = (counts[a.source] ?? 0) + 1;
    }
    return counts;
  }

  /// Effectif par étape, dans l'ordre du pipeline — l'entonnoir.
  Map<PipelineStage, int> get funnel {
    return {
      for (final s in _stages) s: _applications.where((a) => a.stageId == s.id).length,
    };
  }

  // ── Chargement et actions ───────────────────────────────────────────────

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _stages = await _supabase.fetchPipelineStages();
      _applications = await _supabase.fetchApplications();
      _interviews = await _supabase.fetchInterviews();
    } catch (e) {
      _error = 'Chargement des candidatures impossible : $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return null;
    } on ApplicationException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur : $e';
    }
  }

  Future<String?> createApplication({
    required String candidateId,
    String? jobOfferId,
    String? stageId,
    ApplicationSource source = ApplicationSource.interne,
  }) {
    // Sans étape explicite, on entre par la première du pipeline : une
    // candidature ne doit jamais démarrer au milieu du parcours.
    final entry = stageId ?? (openStages.isNotEmpty ? openStages.first.id : null);
    if (entry == null) {
      return Future.value('Aucune étape de pipeline configurée.');
    }
    return _run(() => _supabase.createApplication(
          candidateId: candidateId,
          jobOfferId: jobOfferId,
          stageId: entry,
          source: source,
        ));
  }

  Future<String?> moveToStage(String applicationId, String stageId) =>
      _run(() => _supabase.moveApplication(id: applicationId, stageId: stageId));

  Future<String?> addNote({
    required String applicationId,
    required String body,
    int? rating,
    String? stageId,
  }) {
    if (body.trim().isEmpty) {
      return Future.value('Le commentaire ne peut pas être vide.');
    }
    return _run(() => _supabase.addApplicationNote(
          applicationId: applicationId,
          body: body.trim(),
          rating: rating,
          stageId: stageId,
        ));
  }

  Future<String?> scheduleInterview(Interview interview) =>
      _run(() => _supabase.scheduleInterview(interview));

  Future<String?> updateInterview(String id, Interview interview) =>
      _run(() => _supabase.updateInterview(id, interview));

  Future<List<ApplicationNote>> notesOf(String applicationId) =>
      _supabase.fetchApplicationNotes(applicationId);

  Future<List<StageTransition>> historyOf(String applicationId) =>
      _supabase.fetchStageHistory(applicationId);

  List<Interview> interviewsOf(String applicationId) =>
      _interviews.where((i) => i.applicationId == applicationId).toList();

  void clear() {
    _stages = [];
    _applications = [];
    _interviews = [];
    _error = null;
    notifyListeners();
  }
}
