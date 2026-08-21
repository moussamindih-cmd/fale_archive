import 'package:flutter/material.dart';
import '../models/candidate.dart';
import '../models/attached_file.dart';
import '../models/action_history_entry.dart';
import '../services/supabase_service.dart';

class CandidatesState extends ChangeNotifier {
  // ─── Store ──────────────────────────────────────────────────────────────
  final List<Candidate> _candidates = [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  CandidatesState() {
    _loadFromSupabase();
  }

  Future<void> _loadFromSupabase() async {
    _isLoading = true;
    notifyListeners();
    try {
      final list = await SupabaseService.instance.fetchAllCandidates();
      _candidates
        ..clear()
        ..addAll(list);
    } catch (_) {
      // Ignorer en cas d'erreur réseau
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Getters ────────────────────────────────────────────────────────────

  /// Tous les candidats non supprimés
  List<Candidate> get candidates =>
      List.unmodifiable(_candidates.where((c) => !c.isDeleted));

  /// Tous les candidats y compris supprimés (pour admin)
  List<Candidate> get allCandidatesIncludingDeleted =>
      List.unmodifiable(_candidates);

  /// Nombre de candidats par statut
  Map<CandidateStatus, int> get candidatesByStatus {
    final map = <CandidateStatus, int>{};
    for (final status in CandidateStatus.values) {
      map[status] = candidates.where((c) => c.status == status).length;
    }
    return map;
  }

  /// Nombre total de candidats actifs
  int get totalActive => candidates.length;

  // ─── Séries temporelles & tendances (dashboards) ────────────────────────

  /// Candidatures reçues par jour sur les [days] derniers jours,
  /// du plus ancien au plus récent.
  List<int> candidatesPerDay(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(days, (i) {
      final day = today.subtract(Duration(days: days - 1 - i));
      return candidates
          .where((c) =>
              c.applicationDate.year == day.year &&
              c.applicationDate.month == day.month &&
              c.applicationDate.day == day.day)
          .length;
    });
  }

  /// Candidatures reçues sur les 7 derniers jours.
  int get candidatesThisWeek => _countBetween(7, 0);

  /// Candidatures reçues sur les 7 jours précédents — base de comparaison.
  int get candidatesPreviousWeek => _countBetween(14, 7);

  int _countBetween(int fromDaysAgo, int toDaysAgo) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = today.subtract(Duration(days: fromDaysAgo - 1));
    final to = today.subtract(Duration(days: toDaysAgo - 1));
    return candidates
        .where((c) =>
            !c.applicationDate.isBefore(from) &&
            (toDaysAgo == 0 || c.applicationDate.isBefore(to)))
        .length;
  }

  // ─── Filtrage ───────────────────────────────────────────────────────────

  List<Candidate> filteredCandidates({
    CandidateStatus? status,
    String? targetPosition,
    String? keyword,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return candidates.where((c) {
      if (status != null && c.status != status) return false;
      if (targetPosition != null &&
          targetPosition.isNotEmpty &&
          c.targetPosition != targetPosition) {
        return false;
      }
      if (keyword != null && keyword.isNotEmpty) {
        final kw = keyword.toLowerCase();
        final match =
            c.fullName.toLowerCase().contains(kw) ||
            c.email.toLowerCase().contains(kw) ||
            c.phone.contains(kw) ||
            c.targetPosition.toLowerCase().contains(kw) ||
            c.rhNotes.toLowerCase().contains(kw);
        if (!match) return false;
      }
      if (fromDate != null && c.applicationDate.isBefore(fromDate))
        return false;
      if (toDate != null && c.applicationDate.isAfter(toDate)) return false;
      return true;
    }).toList()..sort((a, b) => b.applicationDate.compareTo(a.applicationDate));
  }

  // ─── CRUD ───────────────────────────────────────────────────────────────

  /// Ajouter un nouveau candidat
  Future<void> addCandidate({
    required String fullName,
    required String targetPosition,
    String email = '',
    String phone = '',
    String rhNotes = '',
    List<AttachedFile> documents = const [],
    required String actionUserName,
  }) async {
    final candidate = Candidate(
      id: 'cand_${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName.trim(),
      targetPosition: targetPosition,
      email: email.trim(),
      phone: phone.trim(),
      applicationDate: DateTime.now(),
      documents: documents,
      rhNotes: rhNotes,
      history: [
        ActionHistoryEntry(
          userName: actionUserName,
          action: 'CREATE',
          timestamp: DateTime.now(),
          details: 'Dossier de candidature créé.',
        ),
      ],
    );
    // Mise à jour optimiste
    _candidates.insert(0, candidate);
    notifyListeners();
    // Upload des fichiers joints puis persistance Supabase
    final uploaded = await Future.wait(
      documents.map(
        (f) => SupabaseService.instance.uploadDocument(
          module: 'candidates',
          entityId: candidate.id,
          file: f,
        ),
      ),
    );
    final idx = _candidates.indexWhere((c) => c.id == candidate.id);
    if (idx != -1) {
      _candidates[idx] = _candidates[idx].copyWith(documents: uploaded);
      notifyListeners();
    }
    await SupabaseService.instance.insertCandidate(
      candidate.copyWith(documents: uploaded),
    );
    await SupabaseService.instance.insertHistoryEntry(
      entry: candidate.history.first,
      candidateId: candidate.id,
    );
  }

  /// Modifier un candidat existant
  Future<void> updateCandidate({
    required String id,
    String? fullName,
    String? targetPosition,
    String? email,
    String? phone,
    String? rhNotes,
    List<AttachedFile>? documents,
    required String actionUserName,
  }) async {
    final idx = _candidates.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final old = _candidates[idx];
    final entry = ActionHistoryEntry(
      userName: actionUserName,
      action: 'UPDATE',
      timestamp: DateTime.now(),
      details: 'Dossier modifié.',
    );
    final updated = old.copyWith(
      fullName: fullName,
      targetPosition: targetPosition,
      email: email,
      phone: phone,
      rhNotes: rhNotes,
      documents: documents,
      history: [...old.history, entry],
    );
    _candidates[idx] = updated;
    notifyListeners();
    List<AttachedFile>? uploadedDocuments;
    if (documents != null) {
      uploadedDocuments = await Future.wait(
        documents.map(
          (f) => SupabaseService.instance.uploadDocument(
            module: 'candidates',
            entityId: id,
            file: f,
          ),
        ),
      );
      final freshIdx = _candidates.indexWhere((c) => c.id == id);
      if (freshIdx != -1) {
        _candidates[freshIdx] = _candidates[freshIdx].copyWith(
          documents: uploadedDocuments,
        );
        notifyListeners();
      }
    }
    await SupabaseService.instance.updateCandidate(
      id: id,
      fullName: fullName,
      targetPosition: targetPosition,
      email: email,
      phone: phone,
      rhNotes: rhNotes,
      documents: uploadedDocuments,
    );
    await SupabaseService.instance.insertHistoryEntry(
      entry: entry,
      candidateId: id,
    );
  }

  /// Changer le statut d'un candidat
  Future<void> changeStatus({
    required String id,
    required CandidateStatus newStatus,
    required String actionUserName,
  }) async {
    final idx = _candidates.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final old = _candidates[idx];
    final entry = ActionHistoryEntry(
      userName: actionUserName,
      action: 'STATUS_CHANGE',
      timestamp: DateTime.now(),
      details: 'Statut changé de "${old.status.label}" à "${newStatus.label}".',
    );
    _candidates[idx] = old.copyWith(
      status: newStatus,
      history: [...old.history, entry],
    );
    notifyListeners();
    await SupabaseService.instance.updateCandidateStatus(
      id: id,
      status: newStatus,
    );
    await SupabaseService.instance.insertHistoryEntry(
      entry: entry,
      candidateId: id,
    );
  }

  /// Suppression logique (soft delete) d'un candidat
  Future<void> softDeleteCandidate({
    required String id,
    required String actionUserName,
  }) async {
    final idx = _candidates.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final old = _candidates[idx];
    final entry = ActionHistoryEntry(
      userName: actionUserName,
      action: 'DELETE',
      timestamp: DateTime.now(),
      details: 'Dossier supprimé (archivé).',
    );
    _candidates[idx] = old.copyWith(
      isDeleted: true,
      history: [...old.history, entry],
    );
    notifyListeners();
    await SupabaseService.instance.softDeleteCandidate(id);
    await SupabaseService.instance.insertHistoryEntry(
      entry: entry,
      candidateId: id,
    );
  }

  /// Récupérer un candidat par son ID
  Candidate? getCandidateById(String id) {
    try {
      return _candidates.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
