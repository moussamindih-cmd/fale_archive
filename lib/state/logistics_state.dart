import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import '../models/logistics_item.dart';
import '../models/attached_file.dart';
import '../models/action_history_entry.dart';
import '../services/supabase_service.dart';

class LogisticsState extends ChangeNotifier {
  static const _uuid = Uuid();

  // ─── Store ──────────────────────────────────────────────────────────────
  final List<LogisticsItem> _items = [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  LogisticsState() {
    _loadFromSupabase();
  }

  Future<void> _loadFromSupabase() async {
    _isLoading = true;
    notifyListeners();
    try {
      final list = await SupabaseService.instance.fetchAllLogisticsItems();
      _items
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
          .where((it) =>
              it.issueDate.year == day.year &&
              it.issueDate.month == day.month &&
              it.issueDate.day == day.day)
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
        .where((it) =>
            !it.issueDate.isBefore(from) &&
            (toDaysAgo == 0 || it.issueDate.isBefore(to)))
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

  /// Ajouter un nouveau document logistique
  Future<void> addItem({
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
      // Identifiant uuid, et non plus `log_<millis>`.
      // Les colonnes `id` sont des uuid en base : la chaîne préfixée était rejetée
      // (« invalid input syntax for type uuid »). Elle entrait de surcroît en
      // collision dès deux créations dans la même milliseconde, et se laissait
      // énumérer.
      id: _uuid.v4(),
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
        (f) => SupabaseService.instance.uploadDocument(
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
    await SupabaseService.instance.insertLogisticsItem(
      item.copyWith(files: uploaded),
    );
    await SupabaseService.instance.insertHistoryEntry(
      entry: entry,
      logisticsItemId: item.id,
    );
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
          (f) => SupabaseService.instance.uploadDocument(
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
    await SupabaseService.instance.updateLogisticsItem(
      id: id,
      documentType: documentType,
      reference: reference,
      amount: amount,
      supplier: supplier,
      issueDate: issueDate,
      notes: notes,
      files: uploadedFiles,
    );
    await SupabaseService.instance.insertHistoryEntry(
      entry: entry,
      logisticsItemId: id,
    );
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
    await SupabaseService.instance.validateLogisticsItem(
      id: id,
      validatedByName: validatorName,
    );
    await SupabaseService.instance.insertHistoryEntry(
      entry: entry,
      logisticsItemId: id,
    );
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
    await SupabaseService.instance.rejectLogisticsItem(
      id: id,
      validatedByName: validatorName,
    );
    await SupabaseService.instance.insertHistoryEntry(
      entry: entry,
      logisticsItemId: id,
    );
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
    _items[idx] = old.copyWith(
      isDeleted: true,
      history: [...old.history, entry],
    );
    notifyListeners();
    await SupabaseService.instance.softDeleteLogisticsItem(id);
    await SupabaseService.instance.insertHistoryEntry(
      entry: entry,
      logisticsItemId: id,
    );
  }

  /// Récupérer un item par son ID
  LogisticsItem? getItemById(String id) {
    try {
      return _items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }
}
