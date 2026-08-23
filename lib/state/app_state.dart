import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/allowed_email.dart';
import '../models/fale_permission.dart';
import '../models/employee.dart';
import '../models/archive_category.dart';
import '../models/daily_archive.dart';
import '../models/attached_file.dart';
import '../models/signup_result.dart';
import '../models/signup_rules.dart';
import '../models/user_role.dart';
import '../models/action_history_entry.dart';
import '../models/subscription.dart';
import '../services/retention_service.dart';
import '../services/supabase_service.dart';
import '../services/error_reporting_service.dart';

class AppState extends ChangeNotifier {
  static const _uuid = Uuid();

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
      _categories = await _supabase.fetchCategories();
      _documentTypes = await _supabase.fetchDocumentTypes();
    } catch (e) {
      // La taxonomie n'est pas indispensable au démarrage : sans elle, le
      // dépôt retombe sur la catégorie déduite du poste.
      debugPrint('Taxonomie documentaire indisponible : $e');
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
      // Réservée à l'administration : la RLS renvoie une liste vide aux autres
      // rôles, ce qui laisse simplement l'onglet « Invitations » vide.
      if (_currentEmployee!.can(FalePermission.manageUsers)) {
        try {
          _allowedEmails = await _supabase.fetchAllowedEmails();
        } catch (e) {
          debugPrint("Liste d'autorisation indisponible : $e");
        }
      }
    }
    notifyListeners();
  }

  // ─── Accounts store ───────────────────────────────────────────────────────
  List<Employee> _employees = [];
  List<Employee> get employees =>
      List.unmodifiable(_employees.where((e) => e.isActive));
  List<Employee> get allEmployees => List.unmodifiable(_employees);

  // ─── Taxonomie documentaire (§5.1.2 / §5.1.4) ────────────────────────────
  List<ArchiveCategory> _categories = [];
  List<RetentionRule> _documentTypes = [];

  /// Catégories de classement de l'organisation.
  List<ArchiveCategory> get categories => List.unmodifiable(_categories);

  /// Types de documents — chacun porte sa durée légale de conservation.
  List<RetentionRule> get documentTypes => List.unmodifiable(_documentTypes);

  ArchiveCategory? categoryById(String? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  RetentionRule? documentTypeById(String? id) {
    if (id == null) return null;
    for (final t in _documentTypes) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Évalue une archive au regard de sa règle de conservation (§5.1.4).
  RetentionAssessment retentionOf(DailyArchive archive) {
    return RetentionService.evaluate(
      archivedAt: archive.archiveDate,
      rule: documentTypeById(archive.documentTypeId),
      legalHold: archive.legalHold,
    );
  }

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

  /// Inscription d'une entreprise et de son administrateur.
  ///
  /// Aucune session n'est ouverte : le compte administrateur naît non confirmé,
  /// et c'est la confirmation de son email — sur le domaine de l'entreprise —
  /// qui vaut preuve de contrôle de ce domaine.
  Future<SignUpResult> registerCompany({
    required String companyName,
    required String companyEmail,
    required String adminFullName,
    required String adminEmail,
    String? adminPersonalEmail,
    required String password,
  }) async {
    final local = _validateCompanyInput(
      companyName: companyName,
      companyEmail: companyEmail,
      adminFullName: adminFullName,
      adminEmail: adminEmail,
      password: password,
    );
    if (local != null) return local;

    _isLoading = true;
    notifyListeners();
    final result = await _supabase.signUpCompany(
      companyName: companyName,
      companyEmail: companyEmail,
      adminFullName: adminFullName,
      adminEmail: adminEmail,
      adminPersonalEmail: adminPersonalEmail,
      password: password,
    );
    _isLoading = false;
    notifyListeners();
    return result;
  }

  /// Inscription d'un employé — refusée si l'adresse ne figure pas sur la liste
  /// tenue par l'administrateur de son entreprise.
  ///
  /// Le rôle et le poste ne sont pas transmis : la fonction Edge les lit sur la
  /// ligne d'autorisation. Le quota d'utilisateurs y est vérifié aussi — il ne
  /// peut plus vivre ici, l'employé s'inscrivant sans être connecté.
  Future<SignUpResult> registerEmployee({
    required String fullName,
    required String email,
    String? personalEmail,
    required String password,
  }) async {
    if (fullName.trim().isEmpty) {
      return const SignUpResult.failure('Le nom complet est obligatoire.');
    }
    if (!isValidEmail(email)) {
      return const SignUpResult.failure('Email professionnel invalide.');
    }
    if (password.length < kMinPasswordLength) {
      return const SignUpResult.failure(
        'Le mot de passe doit comporter au moins $kMinPasswordLength caractères.',
      );
    }

    _isLoading = true;
    notifyListeners();
    final result = await _supabase.signUpEmployee(
      email: email,
      fullName: fullName,
      personalEmail: personalEmail,
      password: password,
    );
    _isLoading = false;
    notifyListeners();
    return result;
  }

  /// Contrôles réalisables sans appel réseau. Le serveur les rejoue tous : ils
  /// n'évitent qu'un aller-retour, ils ne protègent rien.
  SignUpResult? _validateCompanyInput({
    required String companyName,
    required String companyEmail,
    required String adminFullName,
    required String adminEmail,
    required String password,
  }) {
    if (companyName.trim().length < 2) {
      return const SignUpResult.failure("Le nom de l'entreprise est obligatoire.");
    }
    if (!isValidEmail(companyEmail)) {
      return const SignUpResult.failure("L'email de l'entreprise est invalide.");
    }
    if (isFreeEmailDomain(companyEmail)) {
      return const SignUpResult.failure(
        "Veuillez utiliser l'adresse professionnelle de votre entreprise, "
        'pas une messagerie grand public.',
      );
    }
    if (adminFullName.trim().isEmpty) {
      return const SignUpResult.failure(
        "Le nom complet de l'administrateur est obligatoire.",
      );
    }
    if (!isValidEmail(adminEmail)) {
      return const SignUpResult.failure("L'email de l'administrateur est invalide.");
    }
    if (domainOf(adminEmail) != domainOf(companyEmail)) {
      return SignUpResult.failure(
        "L'email de l'administrateur doit être sur le domaine "
        '@${domainOf(companyEmail)}.',
      );
    }
    if (password.length < kMinPasswordLength) {
      return const SignUpResult.failure(
        'Le mot de passe doit comporter au moins $kMinPasswordLength caractères.',
      );
    }
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
    _allowedEmails = [];
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
    if (newPassword.length < 8) {
      return 'Le nouveau mot de passe doit comporter au moins 8 caractères.';
    }
    if (newPassword == oldPassword) {
      return 'Le nouveau mot de passe doit être différent de l\'ancien.';
    }

    // L'ancien mot de passe n'était pas vérifié : une session laissée
    // ouverte sur un poste partagé suffisait à changer le mot de passe et à
    // s'approprier le compte. Supabase n'expose pas de « vérifier ce mot de
    // passe », mais une reconnexion silencieuse fait exactement cela.
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _currentEmployee!.email,
        password: oldPassword,
      );
    } on AuthException {
      return 'Mot de passe actuel incorrect.';
    } catch (e) {
      return 'Vérification du mot de passe actuel impossible : $e';
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
    String? categoryId,
    String? categoryLabel,
    String? documentTypeId,
    List<String> keywords = const [],
  }) async {
    if (_currentEmployee == null) return 'Aucun utilisateur connecté.';
    // Identifiant uuid, et non plus `arc_<millis>`.
    // Les colonnes `id` sont des uuid en base : la chaîne préfixée était rejetée
    // (« invalid input syntax for type uuid »). Elle entrait de surcroît en
    // collision dès deux créations dans la même milliseconde, et se laissait
    // énumérer.
    final archiveId = _uuid.v4();
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
      // La catégorie déduite du poste n'est plus qu'un repli : elle sert
      // de valeur par défaut quand l'utilisateur n'a rien choisi (§5.1.2).
      category: categoryLabel ?? _currentEmployee!.archiveCategory,
      categoryId: categoryId,
      documentTypeId: documentTypeId,
      keywords: keywords,
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

  /// Modifier une archive déjà déposée (§5.1.6).
  ///
  /// N'existait pas : une archive soumise était définitivement figée, ce qui
  /// interdisait aussi bien la correction d'une faute de saisie que
  /// l'historique des modifications demandé par le cahier des charges.
  ///
  /// Chaque nouvelle pièce est enregistrée comme une révision : l'ancienne
  /// n'est jamais écrasée dans le stockage.
  Future<String?> updateArchive({
    required String id,
    String? title,
    String? summary,
    String? categoryId,
    String? categoryLabel,
    String? documentTypeId,
    List<String>? keywords,
    String? physicalLocation,
    bool? legalHold,
    List<AttachedFile>? newFiles,
    String? versionComment,
  }) async {
    if (_currentEmployee == null) return 'Aucun utilisateur connecté.';

    final index = _allArchives.indexWhere((a) => a.id == id);
    if (index == -1) return 'Archive introuvable.';
    final existing = _allArchives[index];

    if (existing.isPurged) {
      return 'Cette archive a été détruite au terme de sa durée légale de '
          'conservation : elle ne peut plus être modifiée.';
    }

    // Les nouvelles pièces sont envoyées puis versionnées ; les anciennes
    // restent en place et restent consultables dans l'historique.
    var files = existing.files;
    if (newFiles != null && newFiles.isNotEmpty) {
      final uploaded = await Future.wait(
        newFiles.map(
          (f) => SupabaseService.instance.uploadDocument(
            module: 'archives',
            entityId: id,
            file: f,
          ),
        ),
      );
      for (final file in uploaded) {
        final versionError = await SupabaseService.instance.addDocumentVersion(
          archiveId: id,
          file: file,
          comment: versionComment,
        );
        // Un contenu identique à la révision précédente est refusé par la
        // base : ce n'est pas une erreur bloquante, la pièce est déjà là.
        if (versionError != null) {
          debugPrint('Version non enregistrée pour ${file.name} : $versionError');
        }
      }
      files = [...existing.files, ...uploaded];
    }

    final error = await SupabaseService.instance.updateArchive(
      id: id,
      title: title,
      summary: summary,
      category: categoryLabel,
      categoryId: categoryId,
      documentTypeId: documentTypeId,
      keywords: keywords,
      physicalLocation: physicalLocation,
      documentCount: files.length,
      legalHold: legalHold,
      files: files == existing.files ? null : files,
    );
    if (error != null) return error;

    _allArchives[index] = existing.copyWith(
      title: title,
      summary: summary,
      category: categoryLabel,
      categoryId: categoryId,
      documentTypeId: documentTypeId,
      keywords: keywords,
      physicalLocation: physicalLocation,
      legalHold: legalHold,
      files: files,
      documentCount: files.length,
    );

    _logActivity(
      userName: _currentEmployee!.fullName,
      action: 'UPDATE',
      details: 'Archive modifiée : ${_allArchives[index].title}.',
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

  // ─── Liste d'autorisation des employés ───────────────────────────────────

  List<AllowedEmail> _allowedEmails = [];

  /// Adresses pré-autorisées de l'organisation, les plus récentes d'abord.
  List<AllowedEmail> get allowedEmails => List.unmodifiable(_allowedEmails);

  /// Adresses enregistrées mais dont le compte n'a pas encore été créé.
  List<AllowedEmail> get pendingAllowedEmails =>
      List.unmodifiable(_allowedEmails.where((e) => e.isClaimable));

  /// Charge la liste. Sans droit d'administration, la RLS renvoie zéro ligne :
  /// on retombe sur une liste vide plutôt que de faire échouer l'écran.
  Future<void> loadAllowedEmails() async {
    try {
      _allowedEmails = await SupabaseService.instance.fetchAllowedEmails();
    } catch (e) {
      debugPrint("Liste d'autorisation indisponible : $e");
      _allowedEmails = [];
    }
    notifyListeners();
  }

  /// Autorise une adresse. Retourne `null` en cas de succès.
  Future<String?> addAllowedEmail({
    required String email,
    String? fullName,
    required UserRole role,
    String jobTitle = '',
    required String actionUserName,
  }) async {
    final normalized = normalizeEmail(email);
    if (!isValidEmail(normalized)) return 'Email invalide.';
    if (role == UserRole.employe && jobTitle.isEmpty) {
      return 'Veuillez choisir un poste pour cet employé.';
    }

    final error = await SupabaseService.instance.addAllowedEmail(
      email: normalized,
      fullName: fullName,
      role: role,
      jobTitle: jobTitle,
    );
    if (error != null) return error;

    await loadAllowedEmails();
    _logActivity(
      userName: actionUserName,
      action: 'INVITE',
      details: '$normalized autorisé à créer un compte (${role.label}).',
    );
    return null;
  }

  /// Autorise plusieurs adresses d'un coup, toutes avec le même rôle et le même
  /// poste. Retourne les échecs par adresse — un lot n'est pas rejeté en bloc
  /// parce qu'une seule ligne est en double.
  Future<Map<String, String>> addAllowedEmails({
    required List<String> emails,
    required UserRole role,
    String jobTitle = '',
    required String actionUserName,
  }) async {
    final failures = <String, String>{};
    var added = 0;

    for (final raw in emails) {
      final normalized = normalizeEmail(raw);
      if (normalized.isEmpty) continue;
      if (!isValidEmail(normalized)) {
        failures[normalized] = 'Email invalide.';
        continue;
      }
      final error = await SupabaseService.instance.addAllowedEmail(
        email: normalized,
        role: role,
        jobTitle: jobTitle,
      );
      if (error != null) {
        failures[normalized] = error;
      } else {
        added++;
      }
    }

    if (added > 0) {
      await loadAllowedEmails();
      _logActivity(
        userName: actionUserName,
        action: 'INVITE',
        details: '$added adresse(s) autorisée(s) (${role.label}).',
      );
    }
    return failures;
  }

  /// Modifie le rôle, le poste ou le nom d'une entrée. L'adresse elle-même
  /// n'est pas modifiable : elle est la clé de l'autorisation, la changer
  /// reviendrait à en créer une autre.
  Future<String?> updateAllowedEmailEntry({
    required String id,
    String? fullName,
    UserRole? role,
    String? jobTitle,
    required String actionUserName,
  }) async {
    if (role == UserRole.employe && (jobTitle == null || jobTitle.isEmpty)) {
      return 'Veuillez choisir un poste pour cet employé.';
    }
    try {
      await SupabaseService.instance.updateAllowedEmail(
        id: id,
        fullName: fullName,
        role: role,
        jobTitle: jobTitle,
      );
    } catch (e) {
      return 'Modification impossible : $e';
    }
    await loadAllowedEmails();
    final entry = _allowedEmails.where((e) => e.id == id).firstOrNull;
    _logActivity(
      userName: actionUserName,
      action: 'UPDATE',
      details: "Autorisation mise à jour pour ${entry?.email ?? id}.",
    );
    return null;
  }

  /// Retire l'autorisation : les inscriptions sur cette adresse sont refusées.
  Future<void> revokeAllowedEmail({
    required String id,
    required String actionUserName,
  }) async {
    final entry = _allowedEmails.where((e) => e.id == id).firstOrNull;
    await SupabaseService.instance.revokeAllowedEmail(id);
    await loadAllowedEmails();
    _logActivity(
      userName: actionUserName,
      action: 'UPDATE',
      details: "Autorisation retirée pour ${entry?.email ?? id}.",
    );
  }

  /// Rouvre une autorisation révoquée.
  Future<void> restoreAllowedEmail({
    required String id,
    required String actionUserName,
  }) async {
    final entry = _allowedEmails.where((e) => e.id == id).firstOrNull;
    await SupabaseService.instance.restoreAllowedEmail(id);
    await loadAllowedEmails();
    _logActivity(
      userName: actionUserName,
      action: 'UPDATE',
      details: "Autorisation rétablie pour ${entry?.email ?? id}.",
    );
  }

  /// Efface une entrée jamais utilisée. Une entrée déjà consommée se révoque —
  /// la politique `allowed_emails_delete` refuse de l'effacer.
  Future<String?> deleteAllowedEmail({
    required String id,
    required String actionUserName,
  }) async {
    final entry = _allowedEmails.where((e) => e.id == id).firstOrNull;
    if (entry != null && !entry.isDeletable) {
      return "Cette adresse a déjà servi à créer un compte : désactivez le "
          "compte depuis l'onglet Membres.";
    }
    try {
      await SupabaseService.instance.deleteAllowedEmail(id);
    } catch (e) {
      return 'Suppression impossible : $e';
    }
    await loadAllowedEmails();
    _logActivity(
      userName: actionUserName,
      action: 'DELETE',
      details: "Autorisation supprimée pour ${entry?.email ?? id}.",
    );
    return null;
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
