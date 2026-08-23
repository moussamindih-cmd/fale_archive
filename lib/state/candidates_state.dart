import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/candidate.dart';
import '../models/attached_file.dart';
import '../models/action_history_entry.dart';
import '../services/supabase_service.dart';
import '../services/error_reporting_service.dart';

class CandidatesState extends ChangeNotifier {
  static const _uuid = Uuid();

  // ─── Store ──────────────────────────────────────────────────────────────
  final List<Candidate> _candidates = [];
  final SupabaseService _supabase;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// [supabaseService] est injectable pour les tests (mock) ; en usage
  /// normal, le singleton [SupabaseService.instance] est utilisé.
  CandidatesState({SupabaseService? supabaseService})
    : _supabase = supabaseService ?? SupabaseService.instance {
    _loadFromSupabase();
  }

  Future<void> _loadFromSupabase() async {
    _isLoading = true;
    notifyListeners();
    try {
      final list = await _supabase.fetchAllCandidates();
      _candidates
        ..clear()
        ..addAll(list);
    } catch (e, stack) {
      ErrorReportingService.instance.report(
        e,
        stack,
        context: 'CandidatesState._loadFromSupabase',
      );
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
          .where(
            (c) =>
                c.applicationDate.year == day.year &&
                c.applicationDate.month == day.month &&
                c.applicationDate.day == day.day,
          )
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
        .where(
          (c) =>
              !c.applicationDate.isBefore(from) &&
              (toDaysAgo == 0 || c.applicationDate.isBefore(to)),
        )
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
      if (fromDate != null && c.applicationDate.isBefore(fromDate)) {
        return false;
      }
      if (toDate != null && c.applicationDate.isAfter(toDate)) return false;
      return true;
    }).toList()..sort((a, b) => b.applicationDate.compareTo(a.applicationDate));
  }

  // ─── CRUD ───────────────────────────────────────────────────────────────

  /// Ajouter un nouveau candidat
  /// Retourne `null` si l'ajout a réussi, sinon un message d'erreur — à
  /// vérifier par l'appelant (ne pas ignorer : un candidat "ajouté" en
  /// façade sans persistance réelle est pire qu'une erreur visible).
  Future<String?> addCandidate({
    required String fullName,
    required String targetPosition,
    String email = '',
    String phone = '',
    String rhNotes = '',
    List<AttachedFile> documents = const [],
    required String actionUserName,
  }) async {
    final candidate = Candidate(
      // Identifiant uuid, et non plus `cand_<millis>`.
      // Les colonnes `id` sont des uuid en base : la chaîne préfixée était rejetée
      // (« invalid input syntax for type uuid »). Elle entrait de surcroît en
      // collision dès deux créations dans la même milliseconde, et se laissait
      // énumérer.
      id: _uuid.v4(),
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
        (f) => _supabase.uploadDocument(
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
    final error = await _supabase.insertCandidate(
      candidate.copyWith(documents: uploaded),
    );
    if (error != null) {
      // La persistance a échoué : annuler la mise à jour optimiste plutôt
      // que de laisser un candidat fantôme, visible seulement en local.
      _candidates.removeWhere((c) => c.id == candidate.id);
      notifyListeners();
      return error;
    }
    await _supabase.insertHistoryEntry(
      entry: candidate.history.first,
      candidateId: candidate.id,
    );
    return null;
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
          (f) => _supabase.uploadDocument(
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
    await _supabase.updateCandidate(
      id: id,
      fullName: fullName,
      targetPosition: targetPosition,
      email: email,
      phone: phone,
      rhNotes: rhNotes,
      documents: uploadedDocuments,
    );
    await _supabase.insertHistoryEntry(entry: entry, candidateId: id);
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
    await _supabase.updateCandidateStatus(id: id, status: newStatus);
    await _supabase.insertHistoryEntry(entry: entry, candidateId: id);
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
    final now = DateTime.now();
    _candidates[idx] = old.copyWith(
      isDeleted: true,
      deletedAt: now,
      history: [...old.history, entry],
    );
    notifyListeners();
    await _supabase.softDeleteCandidate(id);
    await _supabase.insertHistoryEntry(entry: entry, candidateId: id);
  }

  /// Restaurer un candidat depuis la corbeille
  Future<void> restoreCandidate({
    required String id,
    required String actionUserName,
  }) async {
    final idx = _candidates.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final old = _candidates[idx];
    final entry = ActionHistoryEntry(
      userName: actionUserName,
      action: 'RESTORE',
      timestamp: DateTime.now(),
      details: 'Dossier restauré depuis la corbeille.',
    );
    _candidates[idx] = old.copyWith(
      isDeleted: false,
      clearDeletedAt: true,
      history: [...old.history, entry],
    );
    notifyListeners();
    await _supabase.restoreCandidate(id);
    await _supabase.insertHistoryEntry(entry: entry, candidateId: id);
  }

  /// Supprimer définitivement un candidat (irréversible)
  Future<void> permanentlyDeleteCandidate(String id) async {
    _candidates.removeWhere((c) => c.id == id);
    _historyCache.remove(id);
    notifyListeners();
    await _supabase.permanentlyDeleteCandidate(id);
  }

  /// Récupérer un candidat par son ID
  Candidate? getCandidateById(String id) {
    try {
      return _candidates.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Candidats dans la corbeille (suppression logique)
  List<Candidate> get deletedCandidates =>
      List.unmodifiable(_candidates.where((c) => c.isDeleted));

  // ─── Historique & commentaires d'équipe ────────────────────────────────

  final Map<String, List<ActionHistoryEntry>> _historyCache = {};

  /// Historique (actions système + commentaires) d'un candidat, du plus
  /// ancien au plus récent. Vide tant que [loadHistory] n'a pas été appelé.
  List<ActionHistoryEntry> historyFor(String candidateId) =>
      List.unmodifiable(_historyCache[candidateId] ?? const []);

  /// Charge l'historique complet d'un candidat depuis Supabase.
  Future<void> loadHistory(String candidateId) async {
    try {
      final entries = await _supabase.fetchHistoryFor(candidateId: candidateId);
      _historyCache[candidateId] = entries;
      notifyListeners();
    } catch (e, stack) {
      ErrorReportingService.instance.report(
        e,
        stack,
        context: 'CandidatesState.loadHistory($candidateId)',
      );
    }
  }

  /// Ajouter un commentaire d'équipe sur un dossier candidat.
  Future<void> addComment({
    required String candidateId,
    required String text,
    required String authorName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final entry = ActionHistoryEntry(
      userName: authorName,
      action: 'COMMENT',
      timestamp: DateTime.now(),
      details: trimmed,
    );
    _historyCache[candidateId] = [
      ...(_historyCache[candidateId] ?? const []),
      entry,
    ];
    notifyListeners();
    await _supabase.insertHistoryEntry(entry: entry, candidateId: candidateId);
  }

  // ─── Corbeille de documents ─────────────────────────────────────────────
  //
  // Retirer un document d'un dossier ne le détruit pas : il reste attaché
  // au dossier (marqué `removedAt`), récupérable depuis la Corbeille tant
  // qu'il n'est pas supprimé définitivement.

  /// Tous les documents retirés, tous dossiers confondus (actifs ou déjà
  /// à la corbeille), avec le dossier auquel chacun appartient.
  List<({Candidate candidate, AttachedFile file})> get removedDocuments {
    final result = <({Candidate candidate, AttachedFile file})>[];
    for (final c in _candidates) {
      for (final f in c.documents) {
        if (f.isRemoved) result.add((candidate: c, file: f));
      }
    }
    return List.unmodifiable(result);
  }

  /// Retire un document déjà persisté d'un dossier (corbeille, pas de
  /// suppression définitive). Les fichiers jamais uploadés (sans
  /// `storagePath`, encore en cours d'édition) doivent être retirés
  /// localement par l'écran de formulaire, sans passer par ici.
  Future<void> removeDocument({
    required String candidateId,
    required String storagePath,
    required String actionUserName,
  }) async {
    final idx = _candidates.indexWhere((c) => c.id == candidateId);
    if (idx == -1) return;
    final old = _candidates[idx];
    final updatedDocs = old.documents
        .map(
          (f) => f.storagePath == storagePath
              ? f.copyWith(removedAt: DateTime.now())
              : f,
        )
        .toList();
    _candidates[idx] = old.copyWith(documents: updatedDocs);
    notifyListeners();
    await _supabase.updateCandidate(id: candidateId, documents: updatedDocs);
    await _supabase.insertHistoryEntry(
      entry: ActionHistoryEntry(
        userName: actionUserName,
        action: 'DOCUMENT_REMOVE',
        timestamp: DateTime.now(),
        details: 'Document retiré (corbeille).',
      ),
      candidateId: candidateId,
    );
  }

  /// Restaure un document précédemment retiré.
  Future<void> restoreDocument({
    required String candidateId,
    required String storagePath,
    required String actionUserName,
  }) async {
    final idx = _candidates.indexWhere((c) => c.id == candidateId);
    if (idx == -1) return;
    final old = _candidates[idx];
    final updatedDocs = old.documents
        .map(
          (f) => f.storagePath == storagePath
              ? f.copyWith(clearRemovedAt: true)
              : f,
        )
        .toList();
    _candidates[idx] = old.copyWith(documents: updatedDocs);
    notifyListeners();
    await _supabase.updateCandidate(id: candidateId, documents: updatedDocs);
    await _supabase.insertHistoryEntry(
      entry: ActionHistoryEntry(
        userName: actionUserName,
        action: 'DOCUMENT_RESTORE',
        timestamp: DateTime.now(),
        details: 'Document restauré depuis la corbeille.',
      ),
      candidateId: candidateId,
    );
  }

  /// Supprime définitivement un document retiré : l'entrée disparaît du
  /// dossier et le fichier est effacé du bucket Storage.
  Future<void> permanentlyDeleteDocument({
    required String candidateId,
    required String storagePath,
  }) async {
    final idx = _candidates.indexWhere((c) => c.id == candidateId);
    if (idx == -1) return;
    final old = _candidates[idx];
    final updatedDocs = old.documents
        .where((f) => f.storagePath != storagePath)
        .toList();
    _candidates[idx] = old.copyWith(documents: updatedDocs);
    notifyListeners();
    await _supabase.updateCandidate(id: candidateId, documents: updatedDocs);
    await _supabase.deleteDocumentFromStorage(storagePath);
  }
}
