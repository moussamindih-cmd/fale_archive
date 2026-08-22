import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_reporting_service.dart';
import '../models/employee.dart';
import '../models/attached_file.dart';
import '../models/daily_archive.dart';
import '../models/candidate.dart';
import '../models/logistics_item.dart';
import '../models/action_history_entry.dart';
import '../models/in_app_notification.dart';
import '../models/user_role.dart';
import '../models/subscription.dart';

/// Service Supabase — singleton qui centralise tous les accès à la base
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  String? _cachedOrganizationId;

  // ─── Auth ────────────────────────────────────────────────────────────────

  /// Inscription : crée un compte Supabase Auth + profil dans `employees`
  /// Si `organizationId` est fourni, l'employé rejoint cette organisation (création par un admin).
  /// Sinon (nouvel admin), on crée une nouvelle organisation automatiquement.
  Future<String?> signUp({
    required String email,
    String? personalEmail,
    required String password,
    required String fullName,
    String jobTitle = '',
    UserRole role = UserRole.employe,
    String? organizationId,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'job_title': jobTitle, 'role': role.name},
      );

      if (res.user == null) return 'Erreur lors de la création du compte.';

      String targetOrgId = organizationId ?? '';

      // Si aucune organisation n'est fournie, c'est le premier admin : on crée l'organisation
      if (targetOrgId.isEmpty) {
        final orgRes = await _client
            .from('organizations')
            .insert({
              'name': 'Organisation de $fullName',
              'admin_id': res.user!.id,
            })
            .select('id')
            .single();
        targetOrgId = orgRes['id'] as String;
      }

      // Insérer le profil dans la table employees
      await _client.from('employees').insert({
        'id': res.user!.id,
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'personal_email': personalEmail?.trim().toLowerCase(),
        // Colonne héritée, non utilisée : l'authentification réelle passe
        // entièrement par Supabase Auth (signInWithPassword ci-dessous),
        // jamais par ce champ. Laissée vide plutôt que supprimée tant que
        // sa contrainte NOT NULL éventuelle côté DB n'est pas vérifiée.
        'password_hash': '',
        'job_title': role == UserRole.employe ? jobTitle : '',
        'role': role.name,
        'is_active': true,
        'organization_id': targetOrgId,
      });

      return null; // Succès
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (e) {
      return 'Erreur réseau : $e';
    }
  }

  /// Connexion via Supabase Auth
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return null; // Succès
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (e) {
      return 'Erreur réseau. Vérifiez votre connexion.';
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    _cachedOrganizationId = null;
    await _client.auth.signOut();
  }

  /// Organisation de l'utilisateur connecté (mise en cache pour éviter une
  /// requête à chaque upload de document).
  Future<String?> _currentOrganizationId() async {
    if (_cachedOrganizationId != null) return _cachedOrganizationId;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('employees')
        .select('organization_id')
        .eq('id', userId)
        .maybeSingle();
    _cachedOrganizationId = row?['organization_id'] as String?;
    return _cachedOrganizationId;
  }

  /// Utilisateur Auth actuellement connecté
  User? get currentAuthUser => _client.auth.currentUser;

  /// Récupérer le profil `Employee` de l'utilisateur connecté
  Future<Employee?> fetchCurrentEmployee() async {
    final user = currentAuthUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('employees')
          .select()
          .eq('id', user.id)
          .single();
      return _mapEmployee(data);
    } catch (_) {
      return null;
    }
  }

  // ─── Employees ───────────────────────────────────────────────────────────

  Future<List<Employee>> fetchAllEmployees() async {
    final data = await _client
        .from('employees')
        .select()
        .order('created_at', ascending: true);
    return (data as List).map((m) => _mapEmployee(m)).toList();
  }

  Future<void> updateEmployee({
    required String id,
    String? fullName,
    String? email,
    String? personalEmail,
    String? jobTitle,
    UserRole? role,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (email != null) updates['email'] = email;
    if (personalEmail != null) updates['personal_email'] = personalEmail;
    if (jobTitle != null) updates['job_title'] = jobTitle;
    if (role != null) updates['role'] = role.name;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (updates.isEmpty) return;
    await _client.from('employees').update(updates).eq('id', id);
  }

  /// Uploader une image de profil
  Future<String?> uploadAvatar(
    String userId,
    Uint8List fileBytes,
    String extension,
  ) async {
    try {
      final fileName =
          '$userId-${DateTime.now().millisecondsSinceEpoch}.$extension';
      await _client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return _client.storage.from('avatars').getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  // ─── Documents joints (bucket privé, isolé par organisation) ──────────────

  /// Uploader un fichier joint (candidat, document logistique, archive) et
  /// retourner une copie du fichier avec `storagePath` renseigné.
  Future<AttachedFile> uploadDocument({
    required String module,
    required String entityId,
    required AttachedFile file,
  }) async {
    if (file.storagePath != null || file.bytes == null) return file;
    // Filet de sécurité : les points d'entrée (sélecteur de fichiers,
    // scanner) valident déjà taille et type, mais on ne fait jamais
    // confiance aveuglément à l'appelant pour un stockage permanent.
    if (!file.isValid) {
      ErrorReportingService.instance.report(
        'uploadDocument refusé : ${file.validationError}',
        null,
        context: 'SupabaseService.uploadDocument',
      );
      return file;
    }
    final organizationId = await _currentOrganizationId();
    if (organizationId == null) return file;
    final path =
        '$organizationId/$module/$entityId/${DateTime.now().millisecondsSinceEpoch}-${file.name}';
    await _client.storage
        .from('documents')
        .uploadBinary(
          path,
          Uint8List.fromList(file.bytes!),
          fileOptions: const FileOptions(upsert: true),
        );
    return file.copyWith(storagePath: path);
  }

  /// Télécharger les octets d'un fichier joint précédemment uploadé.
  Future<Uint8List?> downloadDocument(String storagePath) async {
    try {
      return await _client.storage.from('documents').download(storagePath);
    } catch (e) {
      return null;
    }
  }

  /// Supprimer définitivement un fichier du bucket Storage (irréversible —
  /// à n'appeler qu'après confirmation utilisateur, depuis la corbeille de
  /// documents).
  Future<void> deleteDocumentFromStorage(String storagePath) async {
    try {
      await _client.storage.from('documents').remove([storagePath]);
    } catch (e, stack) {
      ErrorReportingService.instance.report(
        e,
        stack,
        context: 'SupabaseService.deleteDocumentFromStorage($storagePath)',
      );
    }
  }

  Future<void> toggleEmployeeActive({
    required String id,
    required bool isActive,
  }) async {
    await _client
        .from('employees')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  // ─── Daily Archives ──────────────────────────────────────────────────────

  Future<List<DailyArchive>> fetchAllArchives() async {
    final data = await _client
        .from('daily_archives')
        .select()
        .filter('deleted_at', 'is', null)
        .order('submitted_at', ascending: false);
    return (data as List).map((m) => _mapArchive(m)).toList();
  }

  Future<List<DailyArchive>> fetchDeletedArchives() async {
    final data = await _client
        .from('daily_archives')
        .select()
        .not('deleted_at', 'is', null)
        .order('deleted_at', ascending: false);
    return (data as List).map((m) => _mapArchive(m)).toList();
  }

  Future<void> softDeleteArchive(String id) async {
    await _client
        .from('daily_archives')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Future<void> restoreArchive(String id) async {
    await _client
        .from('daily_archives')
        .update({'deleted_at': null})
        .eq('id', id);
  }

  Future<void> permanentlyDeleteArchive(String id) async {
    await _client.from('daily_archives').delete().eq('id', id);
  }

  Future<String?> insertArchive(DailyArchive archive) async {
    try {
      final organizationId = await _currentOrganizationId();
      await _client.from('daily_archives').insert({
        'id': archive.id,
        'employee_id': archive.employeeId,
        'employee_name': archive.employeeName,
        'job_title': archive.jobTitle,
        'archive_date': archive.archiveDate.toIso8601String().substring(0, 10),
        'title': archive.title,
        'summary': archive.summary,
        'category': archive.category,
        'document_count': archive.documentCount,
        'physical_location': archive.physicalLocation,
        'submitted_at': archive.submittedAt.toIso8601String(),
        'documents': archive.files.map((f) => f.toJson()).toList(),
        if (organizationId != null) 'organization_id': organizationId,
      });
      return null;
    } catch (e) {
      return 'Erreur lors de la soumission de l\'archive : $e';
    }
  }

  // ─── Candidates ──────────────────────────────────────────────────────────

  Future<List<Candidate>> fetchAllCandidates() async {
    final data = await _client
        .from('candidates')
        .select()
        .order('application_date', ascending: false);
    return (data as List).map((m) => _mapCandidate(m)).toList();
  }

  Future<String?> insertCandidate(Candidate candidate) async {
    try {
      final organizationId = await _currentOrganizationId();
      await _client.from('candidates').insert({
        'id': candidate.id,
        'full_name': candidate.fullName,
        'target_position': candidate.targetPosition,
        'email': candidate.email,
        'phone': candidate.phone,
        'application_date': candidate.applicationDate.toIso8601String(),
        'status': candidate.status.name,
        'rh_notes': candidate.rhNotes,
        'is_deleted': false,
        'documents': candidate.documents.map((f) => f.toJson()).toList(),
        if (organizationId != null) 'organization_id': organizationId,
      });
      return null;
    } catch (e) {
      return 'Erreur lors de l\'ajout du candidat : $e';
    }
  }

  Future<void> updateCandidate({
    required String id,
    String? fullName,
    String? targetPosition,
    String? email,
    String? phone,
    String? rhNotes,
    List<AttachedFile>? documents,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (targetPosition != null) updates['target_position'] = targetPosition;
    if (email != null) updates['email'] = email;
    if (phone != null) updates['phone'] = phone;
    if (rhNotes != null) updates['rh_notes'] = rhNotes;
    if (documents != null) {
      updates['documents'] = documents.map((f) => f.toJson()).toList();
    }
    if (updates.isEmpty) return;
    await _client.from('candidates').update(updates).eq('id', id);
  }

  Future<void> updateCandidateStatus({
    required String id,
    required CandidateStatus status,
  }) async {
    await _client
        .from('candidates')
        .update({'status': status.name})
        .eq('id', id);
  }

  Future<void> softDeleteCandidate(String id) async {
    await _client
        .from('candidates')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> restoreCandidate(String id) async {
    await _client
        .from('candidates')
        .update({'is_deleted': false, 'deleted_at': null})
        .eq('id', id);
  }

  Future<void> permanentlyDeleteCandidate(String id) async {
    await _client.from('candidates').delete().eq('id', id);
  }

  // ─── Logistics ───────────────────────────────────────────────────────────

  Future<List<LogisticsItem>> fetchAllLogisticsItems() async {
    final data = await _client
        .from('logistics_items')
        .select()
        .order('issue_date', ascending: false);
    return (data as List).map((m) => _mapLogisticsItem(m)).toList();
  }

  Future<String?> insertLogisticsItem(LogisticsItem item) async {
    try {
      final organizationId = await _currentOrganizationId();
      await _client.from('logistics_items').insert({
        'id': item.id,
        'document_type': item.documentType.name,
        'reference': item.reference,
        'amount': item.amount,
        'supplier': item.supplier,
        'issue_date': item.issueDate.toIso8601String(),
        'status': item.status.name,
        'registered_by_id': item.registeredById,
        'registered_by_name': item.registeredByName,
        'validated_by_name': item.validatedByName,
        'notes': item.notes,
        'is_deleted': false,
        'documents': item.files.map((f) => f.toJson()).toList(),
        if (organizationId != null) 'organization_id': organizationId,
      });
      return null;
    } catch (e) {
      return 'Erreur lors de l\'enregistrement : $e';
    }
  }

  Future<void> updateLogisticsItem({
    required String id,
    LogisticsDocType? documentType,
    String? reference,
    double? amount,
    String? supplier,
    DateTime? issueDate,
    String? notes,
    List<AttachedFile>? files,
  }) async {
    final updates = <String, dynamic>{};
    if (documentType != null) updates['document_type'] = documentType.name;
    if (reference != null) updates['reference'] = reference;
    if (amount != null) updates['amount'] = amount;
    if (supplier != null) updates['supplier'] = supplier;
    if (issueDate != null) updates['issue_date'] = issueDate.toIso8601String();
    if (notes != null) updates['notes'] = notes;
    if (files != null) {
      updates['documents'] = files.map((f) => f.toJson()).toList();
    }
    if (updates.isEmpty) return;
    await _client.from('logistics_items').update(updates).eq('id', id);
  }

  Future<void> validateLogisticsItem({
    required String id,
    required String validatedByName,
  }) async {
    await _client
        .from('logistics_items')
        .update({'status': 'valide', 'validated_by_name': validatedByName})
        .eq('id', id);
  }

  Future<void> rejectLogisticsItem({
    required String id,
    required String validatedByName,
  }) async {
    await _client
        .from('logistics_items')
        .update({'status': 'rejete', 'validated_by_name': validatedByName})
        .eq('id', id);
  }

  Future<void> softDeleteLogisticsItem(String id) async {
    await _client
        .from('logistics_items')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> restoreLogisticsItem(String id) async {
    await _client
        .from('logistics_items')
        .update({'is_deleted': false, 'deleted_at': null})
        .eq('id', id);
  }

  Future<void> permanentlyDeleteLogisticsItem(String id) async {
    await _client.from('logistics_items').delete().eq('id', id);
  }

  // ─── Action History ──────────────────────────────────────────────────────

  Future<void> insertHistoryEntry({
    required ActionHistoryEntry entry,
    String? candidateId,
    String? logisticsItemId,
  }) async {
    try {
      // `action_history_entries.organization_id` est NOT NULL côté Postgres
      // — sans cette valeur, chaque entrée d'audit/commentaire échouait en
      // silence (bug d'origine, invisible avant l'ajout du monitoring).
      final organizationId = await _currentOrganizationId();
      await _client.from('action_history_entries').insert({
        'user_name': entry.userName,
        'action': entry.action,
        'details': entry.details,
        'timestamp': entry.timestamp.toIso8601String(),
        if (organizationId != null) 'organization_id': organizationId,
        if (candidateId != null) 'candidate_id': candidateId,
        if (logisticsItemId != null) 'logistics_item_id': logisticsItemId,
      });
    } catch (e, stack) {
      // Ne pas bloquer l'UI si le log échoue, mais ne jamais l'avaler en
      // silence : une entrée d'audit manquante doit rester observable.
      ErrorReportingService.instance.report(
        e,
        stack,
        context: 'SupabaseService.insertHistoryEntry(action=${entry.action})',
      );
    }
  }

  Future<List<ActionHistoryEntry>> fetchActivityLog({int limit = 200}) async {
    final data = await _client
        .from('action_history_entries')
        .select()
        .order('timestamp', ascending: false)
        .limit(limit);
    return (data as List)
        .map(
          (m) => ActionHistoryEntry(
            userName: m['user_name'] as String,
            action: m['action'] as String,
            timestamp: DateTime.parse(m['timestamp'] as String),
            details: m['details'] as String? ?? '',
          ),
        )
        .toList();
  }

  /// Historique complet (actions système + commentaires) d'un candidat ou
  /// d'un document logistique, dans l'ordre chronologique.
  Future<List<ActionHistoryEntry>> fetchHistoryFor({
    String? candidateId,
    String? logisticsItemId,
  }) async {
    final data = candidateId != null
        ? await _client
              .from('action_history_entries')
              .select()
              .eq('candidate_id', candidateId)
              .order('timestamp', ascending: true)
        : await _client
              .from('action_history_entries')
              .select()
              .eq('logistics_item_id', logisticsItemId!)
              .order('timestamp', ascending: true);
    return (data as List)
        .map(
          (m) => ActionHistoryEntry(
            userName: m['user_name'] as String,
            action: m['action'] as String,
            timestamp: DateTime.parse(m['timestamp'] as String),
            details: m['details'] as String? ?? '',
          ),
        )
        .toList();
  }

  // ─── Notifications ───────────────────────────────────────────────────────

  Future<List<InAppNotification>> fetchNotificationsForUser({
    required String userId,
    required String userRole,
  }) async {
    final data = await _client
        .from('in_app_notifications')
        .select()
        .or(
          'target_user_id.eq.$userId,target_user_id.is.null,target_role.eq.$userRole',
        )
        .order('timestamp', ascending: false)
        .limit(50);
    return (data as List)
        .map(
          (m) => InAppNotification.fromJson({
            'id': m['id'],
            'title': m['title'],
            'message': m['message'],
            'type': m['type'],
            'timestamp': m['timestamp'],
            'isRead': m['is_read'],
            'relatedEntityId': m['related_entity_id'],
            'targetRole': m['target_role'],
            'targetUserId': m['target_user_id'],
          }),
        )
        .toList();
  }

  Future<void> markNotificationAsRead(String id) async {
    await _client
        .from('in_app_notifications')
        .update({'is_read': true})
        .eq('id', id);
  }

  Future<void> insertNotification(InAppNotification notif) async {
    await _client.from('in_app_notifications').insert({
      'id': notif.id,
      'title': notif.title,
      'message': notif.message,
      'type': notif.type.name,
      'timestamp': notif.timestamp.toIso8601String(),
      'is_read': notif.isRead,
      'related_entity_id': notif.relatedEntityId,
      'target_role': notif.targetRole,
      'target_user_id': notif.targetUserId,
    });
  }

  // ─── Subscriptions ───────────────────────────────────────────────────────

  Future<SubscriptionInfo?> fetchSubscriptionInfo(String organizationId) async {
    try {
      final data = await _client
          .from('subscriptions')
          .select('*, subscription_plans(*)')
          .eq('organization_id', organizationId)
          .order('created_at', ascending: false);

      if (data.isEmpty) return const SubscriptionInfo(history: []);

      final history = (data as List).map((m) {
        final planData = m['subscription_plans'] as Map<String, dynamic>? ?? {};
        m['plan_name'] = planData['name'];
        return SubscriptionTransaction.fromJson(m);
      }).toList();

      final active = history.where((t) => t.isActive).firstOrNull;

      SubscriptionPlan? activePlan;
      if (active != null) {
        final activeRow = data.firstWhere((m) => m['id'] == active.id);
        activePlan = SubscriptionPlan.fromJson(activeRow['subscription_plans']);
      }

      return SubscriptionInfo(
        activeTransaction: active,
        history: history,
        activePlan: activePlan,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<SubscriptionPlan>> fetchSubscriptionPlans() async {
    final data = await _client
        .from('subscription_plans')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (data as List).map((m) => SubscriptionPlan.fromJson(m)).toList();
  }

  // ─── Mappers ─────────────────────────────────────────────────────────────

  Employee _mapEmployee(Map<String, dynamic> m) {
    return Employee(
      id: m['id'] as String,
      fullName: m['full_name'] as String,
      email: m['email'] as String,
      personalEmail: m['personal_email'] as String?,
      avatarUrl: m['avatar_url'] as String?,
      password: '', // Non exposé — géré par Supabase Auth
      jobTitle: m['job_title'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == m['role'],
        orElse: () => UserRole.employe,
      ),
      isActive: m['is_active'] as bool? ?? true,
      organizationId: m['organization_id'] as String? ?? '',
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  List<AttachedFile> _parseDocuments(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => AttachedFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  DailyArchive _mapArchive(Map<String, dynamic> m) {
    return DailyArchive(
      id: m['id'] as String,
      employeeId: m['employee_id'] as String,
      employeeName: m['employee_name'] as String,
      jobTitle: m['job_title'] as String? ?? '',
      archiveDate: DateTime.parse(m['archive_date'] as String),
      title: m['title'] as String,
      summary: m['summary'] as String? ?? '',
      category: m['category'] as String? ?? '',
      documentCount: m['document_count'] as int? ?? 0,
      physicalLocation: m['physical_location'] as String? ?? '',
      submittedAt: DateTime.parse(m['submitted_at'] as String),
      deletedAt: m['deleted_at'] != null
          ? DateTime.parse(m['deleted_at'] as String)
          : null,
      files: _parseDocuments(m['documents']),
    );
  }

  Candidate _mapCandidate(Map<String, dynamic> m) {
    return Candidate(
      id: m['id'] as String,
      fullName: m['full_name'] as String,
      targetPosition: m['target_position'] as String,
      email: m['email'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      applicationDate: DateTime.parse(m['application_date'] as String),
      status: CandidateStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => CandidateStatus.enAttente,
      ),
      rhNotes: m['rh_notes'] as String? ?? '',
      isDeleted: m['is_deleted'] as bool? ?? false,
      deletedAt: m['deleted_at'] != null
          ? DateTime.parse(m['deleted_at'] as String)
          : null,
      documents: _parseDocuments(m['documents']),
    );
  }

  LogisticsItem _mapLogisticsItem(Map<String, dynamic> m) {
    return LogisticsItem(
      id: m['id'] as String,
      documentType: LogisticsDocType.values.firstWhere(
        (d) => d.name == m['document_type'],
        orElse: () => LogisticsDocType.autre,
      ),
      reference: m['reference'] as String,
      amount: (m['amount'] as num?)?.toDouble(),
      supplier: m['supplier'] as String? ?? '',
      issueDate: DateTime.parse(m['issue_date'] as String),
      status: LogisticsStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => LogisticsStatus.enAttente,
      ),
      registeredById: m['registered_by_id'] as String? ?? '',
      registeredByName: m['registered_by_name'] as String? ?? '',
      validatedByName: m['validated_by_name'] as String? ?? '',
      notes: m['notes'] as String? ?? '',
      isDeleted: m['is_deleted'] as bool? ?? false,
      deletedAt: m['deleted_at'] != null
          ? DateTime.parse(m['deleted_at'] as String)
          : null,
      files: _parseDocuments(m['documents']),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _translateAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (message.contains('User already registered') ||
        message.contains('already been registered')) {
      return 'Un compte avec cet email existe déjà.';
    }
    if (message.contains('Password should be at least')) {
      return 'Le mot de passe doit contenir au moins 6 caractères.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Veuillez confirmer votre email avant de vous connecter.';
    }
    if (message.contains('network') || message.contains('connection')) {
      return 'Erreur réseau. Vérifiez votre connexion.';
    }
    return message;
  }
}
