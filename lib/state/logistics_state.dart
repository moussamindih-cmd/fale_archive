import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/logistics_item.dart';
import '../models/attached_file.dart';
import '../models/action_history_entry.dart';
import '../services/supabase_service.dart';
import '../services/error_reporting_service.dart';

class LogisticsState extends ChangeNotifier {
  // ─── Store ──────────────────────────────────────────────────────────────
  final List<LogisticsItem> _items = [];
  final SupabaseService _supabase;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// [supabaseService] est injectable pour les tests (mock) ; en usage
  /// normal, le singleton [SupabaseService.instance] est utilisé.
  LogisticsState({SupabaseService? supabaseService})
    : _supabase = supabaseService ?? SupabaseService.instance {
    _loadFromSupabase();
  }

  Future<void> _loadFromSupabase() async {
    _isLoading = true;
    notifyListeners();
    try {
      final list = await _supabase.fetchAllLogisticsItems();
      _items
        ..clear()
        ..addAll(list);
    } catch (e, stack) {
      ErrorReportingService.instance.report(
        e,
        stack,
        context: 'LogisticsState._loadFromSupabase',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Getters ────────────────────────────────────────────────────────────

  /// Tous les documents non supprimés
  List<LogisticsItem> get items =>
      List.unmodifiable(_items.where((i) => !i.isDeleted));

  /// Nombre de documents en attente de validation
  int get pendingCount =>
      items.where((i) => i.status == LogisticsStatus.enAttente).length;

  /// Nombre total de documents
  int get totalCount => items.length;

  // ─── Séries temporelles & tendances (dashboards) ────────────────────────

  /// Pièces émises par jour sur les [days] derniers jours,
  /// du plus ancien au plus récent.
  List<int> itemsPerDay(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(days, (i) {
      final day = today.subtract(Duration(days: days - 1 - i));
      return items
          .where(
            (it) =>
                it.issueDate.year == day.year &&
                it.issueDate.month == day.month &&
                it.issueDate.day == day.day,
          )
          .length;
    });
  }

  /// Pièces émises sur les 7 derniers jours.
  int get itemsThisWeek => _countBetween(7, 0);

  /// Pièces émises sur les 7 jours précédents — base de comparaison.
  int get itemsPreviousWeek => _countBetween(14, 7);

  int _countBetween(int fromDaysAgo, int toDaysAgo) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = today.subtract(Duration(days: fromDaysAgo - 1));
    final to = today.subtract(Duration(days: toDaysAgo - 1));
    return items
        .where(
          (it) =>
              !it.issueDate.isBefore(from) &&
              (toDaysAgo == 0 || it.issueDate.isBefore(to)),
        )
        .length;
  }

  /// Statistiques par statut
  Map<LogisticsStatus, int> get itemsByStatus {
    final map = <LogisticsStatus, int>{};
    for (final status in LogisticsStatus.values) {
      map[status] = items.where((i) => i.status == status).length;
    }
    return map;
  }

  // ─── Filtrage ───────────────────────────────────────────────────────────

  List<LogisticsItem> filteredItems({
    LogisticsDocType? docType,
    LogisticsStatus? status,
    String? supplier,
    String? keyword,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return items.where((i) {
      if (docType != null && i.documentType != docType) return false;
      if (status != null && i.status != status) return false;
      if (supplier != null &&
          supplier.isNotEmpty &&
          !i.supplier.toLowerCase().contains(supplier.toLowerCase())) {
        return false;
      }
      if (keyword != null && keyword.isNotEmpty) {
        final kw = keyword.toLowerCase();
        final match =
            i.reference.toLowerCase().contains(kw) ||
            i.supplier.toLowerCase().contains(kw) ||
            i.notes.toLowerCase().contains(kw) ||
            i.documentType.label.toLowerCase().contains(kw);
        if (!match) return false;
      }
      if (fromDate != null && i.issueDate.isBefore(fromDate)) return false;
      if (toDate != null && i.issueDate.isAfter(toDate)) return false;
      return true;
    }).toList()..sort((a, b) => b.issueDate.compareTo(a.issueDate));
  }

  // ─── CRUD ───────────────────────────────────────────────────────────────

  /// Ajouter un nouveau document logistique. Retourne `null` si l'ajout a
  /// réussi, sinon un message d'erreur — à vérifier par l'appelant.
  Future<String?> addItem({
    required LogisticsDocType documentType,
    required String reference,
    double? amount,
    required String supplier,
    required DateTime issueDate,
    String notes = '',
    List<AttachedFile> files = const [],
    required String registeredById,
    required String registeredByName,
  }) async {
    final entry = ActionHistoryEntry(
      userName: registeredByName,
      action: 'CREATE',
      timestamp: DateTime.now(),
      details: 'Document logistique enregistré.',
    );
    final item = LogisticsItem(
      // Doit être un UUID valide : `logistics_items.id` est de type uuid
      // côté Postgres. Un ID informel ('log_<epoch>') fait échouer
      // l'insertion en silence — c'était le bug d'origine.
      id: const Uuid().v4(),
      documentType: documentType,
      reference: reference.trim(),
      amount: amount,
      supplier: supplier.trim(),
      issueDate: issueDate,
      notes: notes,
      files: files,
      registeredById: registeredById,
      registeredByName: registeredByName,
      history: [entry],
    );
    // Mise à jour optimiste
    _items.insert(0, item);
    notifyListeners();
    // Upload des fichiers joints puis persistance Supabase
    final uploaded = await Future.wait(
      files.map(
        (f) => _supabase.uploadDocument(
          module: 'logistics',
          entityId: item.id,
          file: f,
        ),
      ),
    );
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx != -1) {
      _items[idx] = _items[idx].copyWith(files: uploaded);
      notifyListeners();
    }
    final error = await _supabase.insertLogisticsItem(
      item.copyWith(files: uploaded),
    );
    if (error != null) {
      // La persistance a échoué : annuler la mise à jour optimiste plutôt
      // que de laisser un document fantôme, visible seulement en local.
      _items.removeWhere((i) => i.id == item.id);
      notifyListeners();
      return error;
    }
    await _supabase.insertHistoryEntry(entry: entry, logisticsItemId: item.id);
    return null;
  }

  /// Modifier un document existant
  Future<void> updateItem({
    required String id,
    LogisticsDocType? documentType,
    String? reference,
    double? amount,
    String? supplier,
    DateTime? issueDate,
    String? notes,
    List<AttachedFile>? files,
    required String actionUserName,
  }) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final old = _items[idx];
    final entry = ActionHistoryEntry(
      userName: actionUserName,
      action: 'UPDATE',
      timestamp: DateTime.now(),
      details: 'Document modifié.',
    );
    _items[idx] = old.copyWith(
      documentType: documentType,
      reference: reference,
      amount: amount,
      supplier: supplier,
      issueDate: issueDate,
      notes: notes,
      files: files,
      history: [...old.history, entry],
    );
    notifyListeners();
    List<AttachedFile>? uploadedFiles;
    if (files != null) {
      uploadedFiles = await Future.wait(
        files.map(
          (f) => _supabase.uploadDocument(
            module: 'logistics',
            entityId: id,
            file: f,
          ),
        ),
      );
      final freshIdx = _items.indexWhere((i) => i.id == id);
      if (freshIdx != -1) {
        _items[freshIdx] = _items[freshIdx].copyWith(files: uploadedFiles);
        notifyListeners();
      }
    }
    await _supabase.updateLogisticsItem(
      id: id,
      documentType: documentType,
      reference: reference,
      amount: amount,
      supplier: supplier,
      issueDate: issueDate,
      notes: notes,
      files: uploadedFiles,
    );
    await _supabase.insertHistoryEntry(entry: entry, logisticsItemId: id);
  }

  /// Valider un document (Directeur Administratif / Admin)
  Future<void> validateItem({
    required String id,
    required String validatorName,
  }) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final old = _items[idx];
    final entry = ActionHistoryEntry(
      userName: validatorName,
      action: 'VALIDATE',
      timestamp: DateTime.now(),
      details: 'Document validé.',
    );
    _items[idx] = old.copyWith(
      status: LogisticsStatus.valide,
      validatedByName: validatorName,
      history: [...old.history, entry],
    );
    notifyListeners();
    await _supabase.validateLogisticsItem(
      id: id,
      validatedByName: validatorName,
    );
    await _supabase.insertHistoryEntry(entry: entry, logisticsItemId: id);
  }

  /// Rejeter un document (Directeur Administratif / Admin)
  Future<void> rejectItem({
    required String id,
    required String validatorName,
    String reason = '',
  }) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final old = _items[idx];
    final entry = ActionHistoryEntry(
      userName: validatorName,
      action: 'REJECT',
      timestamp: DateTime.now(),
      details: reason.isNotEmpty
          ? 'Document rejeté. Motif : $reason'
          : 'Document rejeté.',
    );
    _items[idx] = old.copyWith(
      status: LogisticsStatus.rejete,
      validatedByName: validatorName,
      history: [...old.history, entry],
    );
    notifyListeners();
    await _supabase.rejectLogisticsItem(id: id, validatedByName: validatorName);
    await _supabase.insertHistoryEntry(entry: entry, logisticsItemId: id);
  }

  /// Suppression logique
  Future<void> softDeleteItem({
    required String id,
    required String actionUserName,
  }) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final old = _items[idx];
    final entry = ActionHistoryEntry(
      userName: actionUserName,
      action: 'DELETE',
      timestamp: DateTime.now(),
      details: 'Document supprimé (archivé).',
    );
    final now = DateTime.now();
    _items[idx] = old.copyWith(
      isDeleted: true,
      deletedAt: now,
      history: [...old.history, entry],
    );
    notifyListeners();
    await _supabase.softDeleteLogisticsItem(id);
    await _supabase.insertHistoryEntry(entry: entry, logisticsItemId: id);
  }

  /// Restaurer un document logistique depuis la corbeille
  Future<void> restoreItem({
    required String id,
    required String actionUserName,
  }) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final old = _items[idx];
    final entry = ActionHistoryEntry(
      userName: actionUserName,
      action: 'RESTORE',
      timestamp: DateTime.now(),
      details: 'Document restauré depuis la corbeille.',
    );
    _items[idx] = old.copyWith(
      isDeleted: false,
      clearDeletedAt: true,
      history: [...old.history, entry],
    );
    notifyListeners();
    await _supabase.restoreLogisticsItem(id);
    await _supabase.insertHistoryEntry(entry: entry, logisticsItemId: id);
  }

  /// Supprimer définitivement un document logistique (irréversible)
  Future<void> permanentlyDeleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    _historyCache.remove(id);
    notifyListeners();
    await _supabase.permanentlyDeleteLogisticsItem(id);
  }

  /// Récupérer un item par son ID
  LogisticsItem? getItemById(String id) {
    try {
      return _items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Documents logistiques dans la corbeille (suppression logique)
  List<LogisticsItem> get deletedItems =>
      List.unmodifiable(_items.where((i) => i.isDeleted));

  // ─── Historique & commentaires d'équipe ────────────────────────────────

  final Map<String, List<ActionHistoryEntry>> _historyCache = {};

  /// Historique (actions système + commentaires) d'un document logistique,
  /// du plus ancien au plus récent. Vide tant que [loadHistory] n'a pas été
  /// appelé.
  List<ActionHistoryEntry> historyFor(String itemId) =>
      List.unmodifiable(_historyCache[itemId] ?? const []);

  /// Charge l'historique complet d'un document depuis Supabase.
  Future<void> loadHistory(String itemId) async {
    try {
      final entries = await _supabase.fetchHistoryFor(logisticsItemId: itemId);
      _historyCache[itemId] = entries;
      notifyListeners();
    } catch (e, stack) {
      ErrorReportingService.instance.report(
        e,
        stack,
        context: 'LogisticsState.loadHistory($itemId)',
      );
    }
  }

  /// Ajouter un commentaire d'équipe sur un document logistique.
  Future<void> addComment({
    required String itemId,
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
    _historyCache[itemId] = [...(_historyCache[itemId] ?? const []), entry];
    notifyListeners();
    await _supabase.insertHistoryEntry(entry: entry, logisticsItemId: itemId);
  }

  // ─── Corbeille de documents ─────────────────────────────────────────────
  //
  // Retirer un fichier d'un document logistique ne le détruit pas : il
  // reste attaché (marqué `removedAt`), récupérable depuis la Corbeille
  // tant qu'il n'est pas supprimé définitivement.

  /// Tous les fichiers retirés, tous documents confondus (actifs ou déjà
  /// à la corbeille), avec le document logistique auquel chacun appartient.
  List<({LogisticsItem item, AttachedFile file})> get removedDocuments {
    final result = <({LogisticsItem item, AttachedFile file})>[];
    for (final it in _items) {
      for (final f in it.files) {
        if (f.isRemoved) result.add((item: it, file: f));
      }
    }
    return List.unmodifiable(result);
  }

  /// Retire un fichier déjà persisté d'un document logistique (corbeille,
  /// pas de suppression définitive). Les fichiers jamais uploadés (sans
  /// `storagePath`, encore en cours d'édition) doivent être retirés
  /// localement par l'écran de formulaire, sans passer par ici.
  Future<void> removeDocument({
    required String itemId,
    required String storagePath,
    required String actionUserName,
  }) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    final old = _items[idx];
    final updatedFiles = old.files
        .map(
          (f) => f.storagePath == storagePath
              ? f.copyWith(removedAt: DateTime.now())
              : f,
        )
        .toList();
    _items[idx] = old.copyWith(files: updatedFiles);
    notifyListeners();
    await _supabase.updateLogisticsItem(id: itemId, files: updatedFiles);
    await _supabase.insertHistoryEntry(
      entry: ActionHistoryEntry(
        userName: actionUserName,
        action: 'DOCUMENT_REMOVE',
        timestamp: DateTime.now(),
        details: 'Fichier retiré (corbeille).',
      ),
      logisticsItemId: itemId,
    );
  }

  /// Restaure un fichier précédemment retiré.
  Future<void> restoreDocument({
    required String itemId,
    required String storagePath,
    required String actionUserName,
  }) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    final old = _items[idx];
    final updatedFiles = old.files
        .map(
          (f) => f.storagePath == storagePath
              ? f.copyWith(clearRemovedAt: true)
              : f,
        )
        .toList();
    _items[idx] = old.copyWith(files: updatedFiles);
    notifyListeners();
    await _supabase.updateLogisticsItem(id: itemId, files: updatedFiles);
    await _supabase.insertHistoryEntry(
      entry: ActionHistoryEntry(
        userName: actionUserName,
        action: 'DOCUMENT_RESTORE',
        timestamp: DateTime.now(),
        details: 'Fichier restauré depuis la corbeille.',
      ),
      logisticsItemId: itemId,
    );
  }

  /// Supprime définitivement un fichier retiré : l'entrée disparaît du
  /// document et le fichier est effacé du bucket Storage.
  Future<void> permanentlyDeleteDocument({
    required String itemId,
    required String storagePath,
  }) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    final old = _items[idx];
    final updatedFiles = old.files
        .where((f) => f.storagePath != storagePath)
        .toList();
    _items[idx] = old.copyWith(files: updatedFiles);
    notifyListeners();
    await _supabase.updateLogisticsItem(id: itemId, files: updatedFiles);
    await _supabase.deleteDocumentFromStorage(storagePath);
  }
}
