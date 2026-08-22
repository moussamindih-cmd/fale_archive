import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee.dart';
import '../models/daily_archive.dart';
import '../models/attached_file.dart';
import '../models/user_role.dart';
import '../models/action_history_entry.dart';
import '../models/subscription.dart';
import '../services/supabase_service.dart';
import '../services/error_reporting_service.dart';

class AppState extends ChangeNotifier {
  // ─── Auth ────────────────────────────────────────────────────────────────
  Employee? _currentEmployee;
  Employee? get currentEmployee => _currentEmployee;
  bool get isLoggedIn => _currentEmployee != null;

  SubscriptionInfo? _subscriptionInfo;
  SubscriptionInfo? get subscriptionInfo => _subscriptionInfo;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final SupabaseService _supabase;

  /// [supabaseService] est injectable pour les tests (mock) ; en usage
  /// normal, le singleton [SupabaseService.instance] est utilisé.
  AppState({SupabaseService? supabaseService})
    : _supabase = supabaseService ?? SupabaseService.instance {
    _tryRestoreSession();
  }

  /// Tente de restaurer la session Supabase Auth au démarrage
  Future<void> _tryRestoreSession() async {
    _isLoading = true;
    notifyListeners();
    try {
      final emp = await _supabase.fetchCurrentEmployee();
      if (emp != null) {
        _currentEmployee = emp;
        await _loadRemoteData();
      }
    } catch (_) {
      // Pas de session active — l'utilisateur devra se connecter
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge employees + archives depuis Supabase
  Future<void> _loadRemoteData() async {
    try {
      _allArchives = await _supabase.fetchAllArchives();
      _deletedArchives = await _supabase.fetchDeletedArchives();
      _employees = await _supabase.fetchAllEmployees();
    } catch (e, stack) {
      ErrorReportingService.instance.report(
        e,
        stack,
        context: 'AppState._loadRemoteData(archives/employees)',
      );
    }
    try {
      final logs = await _supabase.fetchActivityLog();
      _activityLog
        ..clear()
        ..addAll(logs);
    } catch (e, stack) {
      ErrorReportingService.instance.report(
        e,
        stack,
        context: 'AppState._loadRemoteData(activityLog)',
      );
    }
    if (_currentEmployee != null) {
      try {
        _subscriptionInfo = await _supabase.fetchSubscriptionInfo(
          _currentEmployee!.organizationId,
        );
      } catch (e, stack) {
        ErrorReportingService.instance.report(
          e,
          stack,
          context: 'AppState._loadRemoteData(subscriptionInfo)',
        );
      }
    }
    notifyListeners();
  }

  // ─── Accounts store ───────────────────────────────────────────────────────
  List<Employee> _employees = [];
  List<Employee> get employees =>
      List.unmodifiable(_employees.where((e) => e.isActive));
  List<Employee> get allEmployees => List.unmodifiable(_employees);

  // ─── Archives store ──────────────────────────────────────────────────────
  List<DailyArchive> _allArchives = [];
  List<DailyArchive> _deletedArchives = [];

  List<DailyArchive> get allArchives => List.unmodifiable(_allArchives);
  List<DailyArchive> get deletedArchives => List.unmodifiable(_deletedArchives);
  List<DailyArchive> get archives => List.unmodifiable(_allArchives);

  // ─── Journal d'activité global ────────────────────────────────────────
  final List<ActionHistoryEntry> _activityLog = [
    ActionHistoryEntry(
      userName: 'Amadou Sow (Admin)',
      action: 'LOGIN',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      details: 'Connexion à l\'application.',
    ),
    ActionHistoryEntry(
      userName: 'Mariam Sy',
      action: 'ARCHIVE_SUBMIT',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      details: 'Archive journalière soumise : Courriers du 11/08/2026.',
    ),
    ActionHistoryEntry(
      userName: 'Moussa Ba',
      action: 'ARCHIVE_SUBMIT',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      details: 'Archive journalière soumise : Journal de Caisse du 11/08/2026.',
    ),
  ];

  List<ActionHistoryEntry> get activityLog => List.unmodifiable(_activityLog);

  // ─── Getters dérivés ─────────────────────────────────────────────────
  List<DailyArchive> get todayArchives {
    final now = DateTime.now();
    return _allArchives
        .where(
          (a) =>
              a.archiveDate.year == now.year &&
              a.archiveDate.month == now.month &&
              a.archiveDate.day == now.day,
        )
        .toList();
  }

  List<DailyArchive> get thisWeekArchives {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return _allArchives
        .where(
          (a) => a.archiveDate.isAfter(
            DateTime(
              startOfWeek.year,
              startOfWeek.month,
              startOfWeek.day,
            ).subtract(const Duration(seconds: 1)),
          ),
        )
        .toList();
  }

  List<DailyArchive> get myArchives {
    if (_currentEmployee == null) return [];
    return _allArchives
        .where((a) => a.employeeId == _currentEmployee!.id)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  /// Retrouver une archive par son identifiant (utilisé pour la recherche
  /// par code / QR).
  DailyArchive? getArchiveById(String id) {
    try {
      return _allArchives.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  bool get hasSubmittedToday {
    if (_currentEmployee == null) return false;
    final now = DateTime.now();
    return _allArchives.any(
      (a) =>
          a.employeeId == _currentEmployee!.id &&
          a.archiveDate.year == now.year &&
          a.archiveDate.month == now.month &&
          a.archiveDate.day == now.day,
    );
  }

  /// Statistiques globales pour le dashboard Admin
  Map<String, int> get globalStats {
    final now = DateTime.now();
    final today = _allArchives
        .where(
          (a) =>
              a.archiveDate.year == now.year &&
              a.archiveDate.month == now.month &&
              a.archiveDate.day == now.day,
        )
        .length;
    return {
      'totalEmployees': _employees.where((e) => e.isActive).length,
      'archivesToday': today,
      'archivesThisWeek': thisWeekArchives.length,
      'totalArchives': _allArchives.length,
    };
  }

  // ─── Séries temporelles & tendances (dashboards) ─────────────────────

  /// Nombre d'archives par jour sur les [days] derniers jours,
  /// du plus ancien au plus récent. Alimente le graphique d'activité.
  List<int> archivesPerDay(int days) => _perDay(_allArchives, days);

  /// Même découpage, restreint aux archives de l'employé connecté.
  List<int> myArchivesPerDay(int days) => _perDay(myArchives, days);

  List<int> _perDay(List<DailyArchive> source, int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(days, (i) {
      final day = today.subtract(Duration(days: days - 1 - i));
      return source
          .where(
            (a) =>
                a.archiveDate.year == day.year &&
                a.archiveDate.month == day.month &&
                a.archiveDate.day == day.day,
          )
          .length;
    });
  }

  /// Archives déposées hier — base de comparaison du jour courant.
  int get archivesYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _allArchives
        .where(
          (a) =>
              a.archiveDate.year == yesterday.year &&
              a.archiveDate.month == yesterday.month &&
              a.archiveDate.day == yesterday.day,
        )
        .length;
  }

  /// Archives de la semaine précédente — base de comparaison hebdomadaire.
  int get archivesPreviousWeek {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final startOfPrevious = startOfWeek.subtract(const Duration(days: 7));
    return _allArchives
        .where(
          (a) =>
              !a.archiveDate.isBefore(startOfPrevious) &&
              a.archiveDate.isBefore(startOfWeek),
        )
        .length;
  }

  // ─── Auth Methods ────────────────────────────────────────────────────────

  /// Connexion via Supabase Auth — retourne null si ok, sinon le message d'erreur
  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    final error = await _supabase.signIn(email: email, password: password);
    if (error != null) {
      _isLoading = false;
      notifyListeners();
      return error;
    }
    final emp = await _supabase.fetchCurrentEmployee();
    if (emp == null || !emp.isActive) {
      await _supabase.signOut();
      _isLoading = false;
      notifyListeners();
      return 'Compte désactivé ou introuvable.';
    }
    _currentEmployee = emp;
    await _loadRemoteData();
    _logActivity(
      userName: emp.fullName,
      action: 'LOGIN',
      details: 'Connexion à l\'application.',
    );
    _isLoading = false;
    notifyListeners();
    return null;
  }

  /// Inscription via Supabase Auth — retourne null si ok, sinon le message d'erreur
  Future<String?> register({
    required String fullName,
    required String email,
    String? personalEmail,
    required String password,
    String jobTitle = '',
    UserRole role = UserRole.employe,
  }) async {
    if (fullName.trim().isEmpty) return 'Le nom complet est obligatoire.';
    if (email.trim().isEmpty || !email.contains('@')) return 'Email invalide.';
    if (password.length < 6) {
      return 'Le mot de passe doit avoir au moins 6 caractères.';
    }
    if (role == UserRole.employe && jobTitle.isEmpty) {
      return 'Veuillez choisir votre poste.';
    }

    _isLoading = true;
    notifyListeners();

    // Vérification des quotas si on est déjà connecté (ajout d'employé par un admin)
    if (_currentEmployee != null) {
      if (_subscriptionInfo != null) {
        final maxUsers = _subscriptionInfo!.activePlan?.maxUsers ?? 1;
        // On compte les employés actifs existants (ou on suppose tous)
        if (_employees.length >= maxUsers && maxUsers != 9999) {
          _isLoading = false;
          notifyListeners();
          return 'Quota d\'utilisateurs atteint pour votre abonnement actuel.';
        }
      }
    }

    final error = await _supabase.signUp(
      email: email,
      personalEmail: personalEmail,
      password: password,
      fullName: fullName,
      jobTitle: jobTitle,
      role: _currentEmployee == null ? UserRole.admin : role,
      organizationId:
          _currentEmployee?.organizationId, // Passage de l'org courante
    );
    if (error != null) {
      _isLoading = false;
      notifyListeners();
      return error;
    }
    final emp = await _supabase.fetchCurrentEmployee();
    if (emp != null) {
      _currentEmployee = emp;
      _employees.add(emp);
      _logActivity(
        userName: emp.fullName,
        action: 'REGISTER',
        details: 'Nouveau compte créé (${emp.role.label}).',
      );
    } else {
      // Si l'utilisateur n'est pas connecté après l'inscription, cela signifie souvent qu'une confirmation d'email est requise.
      _isLoading = false;
      notifyListeners();
      return 'REQUIRE_CONFIRMATION';
    }
    _isLoading = false;
    notifyListeners();
    return null;
  }

  /// Met à jour la photo de profil
  Future<String?> updateProfilePicture(Uint8List bytes, String ext) async {
    if (_currentEmployee == null) return 'Non connecté';
    try {
      final url = await _supabase.uploadAvatar(
        _currentEmployee!.id,
        bytes,
        ext,
      );
      if (url == null) return 'Erreur lors de l\'upload';
      await _supabase.updateEmployee(id: _currentEmployee!.id, avatarUrl: url);
      _currentEmployee = _currentEmployee!.copyWith(avatarUrl: url);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    if (_currentEmployee != null) {
      _logActivity(
        userName: _currentEmployee!.fullName,
        action: 'LOGOUT',
        details: 'Déconnexion de l\'application.',
      );
    }
    await SupabaseService.instance.signOut();
    _currentEmployee = null;
    _employees.clear();
    _allArchives.clear();
    _activityLog.clear();
    notifyListeners();
  }

  // ─── Profile & Auth Methods ──────────────────────────────────────────────

  /// Modifier le mot de passe de l'utilisateur actuellement connecté
  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (_currentEmployee == null) return 'Aucun utilisateur connecté.';
    // Note: Avec Supabase, on ne vérifie pas l'ancien mdp localement. Supabase gère l'updateAuth.
    if (newPassword.length < 6) {
      return 'Le nouveau mot de passe doit comporter au moins 6 caractères.';
    }
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      _logActivity(
        userName: _currentEmployee!.fullName,
        action: 'UPDATE',
        details: 'Mot de passe modifié avec succès.',
      );
      notifyListeners();
      return null;
    } catch (e) {
      return 'Erreur lors de la mise à jour : $e';
    }
  }

  // ─── Archive Methods ─────────────────────────────────────────────────────

  Future<String?> submitArchive({
    required String title,
    required String summary,
    required int documentCount,
    List<AttachedFile> files = const [],
    String physicalLocation = '',
  }) async {
    if (_currentEmployee == null) return 'Aucun utilisateur connecté.';
    // Doit être un UUID valide : `daily_archives.id` est de type uuid côté
    // Postgres. Un ID informel ('arc_<epoch>') fait échouer l'insertion en
    // silence — c'était le bug d'origine.
    final archiveId = const Uuid().v4();
    final uploadedFiles = await Future.wait(
      files.map(
        (f) => SupabaseService.instance.uploadDocument(
          module: 'archives',
          entityId: archiveId,
          file: f,
        ),
      ),
    );
    final archive = DailyArchive(
      id: archiveId,
      employeeId: _currentEmployee!.id,
      employeeName: _currentEmployee!.fullName,
      jobTitle: _currentEmployee!.jobTitle,
      archiveDate: DateTime.now(),
      title: title,
      summary: summary,
      category: _currentEmployee!.archiveCategory,
      documentCount: files.isNotEmpty ? files.length : documentCount,
      files: uploadedFiles,
      physicalLocation: physicalLocation.trim(),
      submittedAt: DateTime.now(),
    );
    final error = await SupabaseService.instance.insertArchive(archive);
    if (error != null) return error;
    _allArchives.insert(0, archive);
    _logActivity(
      userName: _currentEmployee!.fullName,
      action: 'ARCHIVE_SUBMIT',
      details: 'Archive journalière soumise : $title.',
    );
    notifyListeners();
    return null;
  }

  /// Déplace une archive vers la corbeille (Soft Delete)
  Future<void> softDeleteArchive(String id) async {
    await _supabase.softDeleteArchive(id);
    _allArchives.removeWhere((a) => a.id == id);
    _deletedArchives = await _supabase.fetchDeletedArchives();
    notifyListeners();
    _logActivity(
      userName: _currentEmployee?.fullName ?? 'Système',
      action: 'DELETE',
      details: 'Archive mise à la corbeille.',
    );
  }

  /// Restaure une archive depuis la corbeille
  Future<void> restoreArchive(String id) async {
    await _supabase.restoreArchive(id);
    _deletedArchives.removeWhere((a) => a.id == id);
    _allArchives = await _supabase.fetchAllArchives();
    notifyListeners();
    _logActivity(
      userName: _currentEmployee?.fullName ?? 'Système',
      action: 'RESTORE',
      details: 'Archive restaurée depuis la corbeille.',
    );
  }

  /// Supprime définitivement une archive
  Future<void> permanentlyDeleteArchive(String id) async {
    await _supabase.permanentlyDeleteArchive(id);
    _deletedArchives.removeWhere((a) => a.id == id);
    notifyListeners();
    _logActivity(
      userName: _currentEmployee?.fullName ?? 'Système',
      action: 'PERMANENT_DELETE',
      details: 'Archive effacée définitivement de la corbeille.',
    );
  }

  // ─── User Management (Admin) ─────────────────────────────────────────────

  /// Modifier un utilisateur
  Future<void> updateEmployee({
    required String id,
    String? fullName,
    String? email,
    String? jobTitle,
    UserRole? role,
    required String actionUserName,
  }) async {
    final idx = _employees.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _employees[idx] = _employees[idx].copyWith(
      fullName: fullName,
      email: email,
      jobTitle: jobTitle,
      role: role,
    );
    await SupabaseService.instance.updateEmployee(
      id: id,
      fullName: fullName,
      email: email,
      jobTitle: jobTitle,
      role: role,
    );
    _logActivity(
      userName: actionUserName,
      action: 'UPDATE',
      details: 'Compte de ${_employees[idx].fullName} modifié.',
    );
    notifyListeners();
  }

  /// Changer le rôle d'un utilisateur
  Future<void> changeEmployeeRole({
    required String id,
    required UserRole newRole,
    required String actionUserName,
  }) async {
    final idx = _employees.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final old = _employees[idx];
    _employees[idx] = old.copyWith(role: newRole);
    await SupabaseService.instance.updateEmployee(id: id, role: newRole);
    _logActivity(
      userName: actionUserName,
      action: 'ROLE_CHANGE',
      details:
          'Rôle de ${old.fullName} changé : "${old.role.label}" → "${newRole.label}".',
    );
    notifyListeners();
  }

  /// Activer / Désactiver un utilisateur
  Future<void> toggleEmployeeStatus({
    required String id,
    required String actionUserName,
  }) async {
    final idx = _employees.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final old = _employees[idx];
    final newActive = !old.isActive;
    _employees[idx] = old.copyWith(isActive: newActive);
    await SupabaseService.instance.toggleEmployeeActive(
      id: id,
      isActive: newActive,
    );
    _logActivity(
      userName: actionUserName,
      action: old.isActive ? 'DELETE' : 'UPDATE',
      details: old.isActive
          ? 'Compte de ${old.fullName} désactivé.'
          : 'Compte de ${old.fullName} réactivé.',
    );
    notifyListeners();
  }

  /// Suppression logique (désactivation définitive)
  Future<void> deleteEmployee({
    required String id,
    required String actionUserName,
  }) async {
    final idx = _employees.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final name = _employees[idx].fullName;
    _employees[idx] = _employees[idx].copyWith(isActive: false);
    await SupabaseService.instance.toggleEmployeeActive(
      id: id,
      isActive: false,
    );
    _logActivity(
      userName: actionUserName,
      action: 'DELETE',
      details: 'Compte de $name supprimé (désactivé).',
    );
    notifyListeners();
  }

  // ─── Activité log ─────────────────────────────────────────────────────────

  void _logActivity({
    required String userName,
    required String action,
    String details = '',
  }) {
    final entry = ActionHistoryEntry(
      userName: userName,
      action: action,
      timestamp: DateTime.now(),
      details: details,
    );
    _activityLog.insert(0, entry);
    // Limiter le journal local à 200 entrées
    if (_activityLog.length > 200) {
      _activityLog.removeRange(200, _activityLog.length);
    }
    // Persister en base de façon non bloquante
    SupabaseService.instance.insertHistoryEntry(entry: entry);
  }
}
