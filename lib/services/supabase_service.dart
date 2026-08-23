import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/allowed_email.dart';
import '../models/employee.dart';
import '../models/application.dart';
import '../models/archive_category.dart';
import '../models/archive_search.dart';
import '../models/attached_file.dart';
import '../models/document_version.dart';
import '../models/daily_archive.dart';
import '../models/candidate.dart';
import '../models/logistics_item.dart';
import '../models/action_history_entry.dart';
import '../models/hr_metrics.dart';
import '../models/in_app_notification.dart';
import '../models/job_offer.dart';
import '../models/signup_result.dart';
import '../models/signup_rules.dart';
import '../models/user_role.dart';
import '../models/subscription.dart';
import 'retention_service.dart';

/// Service Supabase — singleton qui centralise tous les accès à la base
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  String? _cachedOrganizationId;

  // ─── Auth ────────────────────────────────────────────────────────────────

  /// Inscription d'une entreprise et de son administrateur (étapes 1 et 2).
  ///
  /// Passe par la fonction Edge `signup-company`, en service_role : la RLS ne
  /// laisse plus aucune politique d'INSERT sur `organizations`, et
  /// `employees_insert` exige `has_role('superAdmin','admin')` — qu'un inscrit
  /// sans fiche employé ne peut satisfaire (20260822000000_rbac_rls.sql:117).
  Future<SignUpResult> signUpCompany({
    required String companyName,
    required String companyEmail,
    required String adminFullName,
    required String adminEmail,
    String? adminPersonalEmail,
    required String password,
  }) {
    return _invokeSignUp('signup-company', {
      'companyName': companyName.trim(),
      'companyEmail': normalizeEmail(companyEmail),
      'adminFullName': adminFullName.trim(),
      'adminEmail': normalizeEmail(adminEmail),
      'adminPersonalEmail':
          adminPersonalEmail == null ? null : normalizeEmail(adminPersonalEmail),
      'password': password,
    }, confirmationEmailFor: normalizeEmail(adminEmail));
  }

  /// Inscription d'un employé, sous réserve de figurer sur la liste tenue par
  /// l'administrateur de son entreprise.
  ///
  /// Ni le rôle ni le poste ne sont transmis : la fonction Edge les lit sur la
  /// ligne d'autorisation. Les envoyer d'ici laisserait le client les choisir.
  Future<SignUpResult> signUpEmployee({
    required String email,
    required String fullName,
    String? personalEmail,
    required String password,
  }) {
    return _invokeSignUp('signup-employee', {
      'email': normalizeEmail(email),
      'fullName': fullName.trim(),
      'personalEmail':
          personalEmail == null ? null : normalizeEmail(personalEmail),
      'password': password,
    }, confirmationEmailFor: normalizeEmail(email));
  }

  Future<SignUpResult> _invokeSignUp(
    String function,
    Map<String, dynamic> body, {
    required String confirmationEmailFor,
  }) async {
    try {
      // `invoke` LÈVE une FunctionsHttpException sur tout statut non-2xx : il
      // ne rend jamais une réponse portant un statut d'erreur. Les refus de la
      // fonction Edge — dont EMAIL_NOT_ALLOWED — arrivent donc dans le `catch`
      // ci-dessous, pas ici.
      final res = await _client.functions.invoke(function, body: body);
      final data = res.data;
      final payload = data is Map ? Map<String, dynamic>.from(data) : const {};

      // `admin.createUser` ne déclenche aucun envoi : c'est ce rappel qui fait
      // partir le mail de confirmation par le chemin GoTrue habituel. Son échec
      // ne remet pas le compte en cause — l'utilisateur peut le redemander
      // depuis l'écran de connexion.
      if (payload['needsEmailConfirmation'] == true) {
        try {
          await _client.auth.resend(
            type: OtpType.signup,
            email: confirmationEmailFor,
          );
        } catch (e) {
          debugPrint('Renvoi du mail de confirmation impossible : $e');
        }
      }

      return SignUpResult.success(
        needsEmailConfirmation: payload['needsEmailConfirmation'] == true,
      );
    } on FunctionException catch (e) {
      // `details` porte le corps JSON décodé de la réponse — c'est là que se
      // trouvent `code` et `error`. Sur une panne réseau (FunctionsFetchException)
      // ce n'est pas une Map : on retombe alors sur le message générique.
      final details = e.details;
      final payload =
          details is Map ? Map<String, dynamic>.from(details) : const {};
      return SignUpResult.failure(
        _signUpErrorMessage(
            payload['code'] as String?, payload['error'] as String?),
        code: payload['code'] as String?,
      );
    } catch (e) {
      return SignUpResult.failure('Erreur réseau : $e');
    }
  }

  /// Message affichable pour un code d'erreur d'inscription.
  ///
  /// Le message renvoyé par la fonction Edge est déjà en français ; on ne le
  /// remplace que pour les cas où l'UI a besoin d'un texte plus précis.
  String _signUpErrorMessage(String? code, String? serverMessage) {
    switch (code) {
      case 'EMAIL_NOT_ALLOWED':
        return "Cette adresse ne figure pas dans la liste des employés "
            "autorisés par votre entreprise. Contactez votre administrateur.";
      case 'COMPANY_ALREADY_REGISTERED':
        return "Cette entreprise est déjà inscrite. Demandez à votre "
            "administrateur de vous ajouter à la liste des employés autorisés.";
      case 'ALREADY_REGISTERED':
      case 'EMAIL_TAKEN':
        return 'Un compte existe déjà pour cette adresse. Connectez-vous ou '
            'réinitialisez votre mot de passe.';
    }
    return serverMessage ?? "Erreur lors de la création du compte.";
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
  /// requête à chaque écriture).
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

  /// Organisation de l'utilisateur connecté, ou une exception.
  ///
  /// Toute écriture doit porter son `organization_id` : c'est la colonne sur
  /// laquelle repose le cloisonnement RLS. Sans elle, la ligne est soit
  /// rejetée, soit — pire — rattachée à la mauvaise organisation.
  Future<String> _requireOrganizationId() async {
    final organizationId = await _currentOrganizationId();
    if (organizationId == null || organizationId.isEmpty) {
      throw StateError(
        'Aucune organisation rattachée au compte connecté : '
        'opération refusée pour ne pas produire de donnée orpheline.',
      );
    }
    return organizationId;
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
    return data.map(_mapEmployee).toList();
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
    // Auparavant, une organisation nulle faisait retourner le fichier tel
    // quel : la pièce jointe disparaissait sans le moindre message.
    final organizationId = await _requireOrganizationId();
    final bytes = Uint8List.fromList(file.bytes!);
    final path =
        '$organizationId/$module/$entityId/${DateTime.now().millisecondsSinceEpoch}-${file.name}';
    await _client.storage.from('documents').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: mimeTypeFor(file.extension),
          ),
        );
    return file.copyWith(
      storagePath: path,
      mimeType: mimeTypeFor(file.extension),
      // Empreinte du contenu : permet de détecter une altération et
      // d'écarter une révision identique à la précédente (§5.1.6).
      checksumSha256: sha256.convert(bytes).toString(),
      uploadedBy: _client.auth.currentUser?.id,
      uploadedAt: DateTime.now(),
    );
  }

  /// Télécharger les octets d'un fichier joint précédemment uploadé.
  Future<Uint8List?> downloadDocument(String storagePath) async {
    try {
      return await _client.storage.from('documents').download(storagePath);
    } catch (e) {
      return null;
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
    return data.map(_mapArchive).toList();
  }

  Future<List<DailyArchive>> fetchDeletedArchives() async {
    final data = await _client
        .from('daily_archives')
        .select()
        .not('deleted_at', 'is', null)
        .order('deleted_at', ascending: false);
    return data.map(_mapArchive).toList();
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
      await _client.from('daily_archives').insert({
        'id': archive.id,
        'organization_id': await _requireOrganizationId(),
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
      });
      return null;
    } catch (e) {
      return 'Erreur lors de la soumission de l\'archive : $e';
    }
  }

  /// Modifier une archive déjà déposée (§5.1.6).
  ///
  /// N'existait pas : une archive soumise était définitivement immuable, ce
  /// qui rendait impossible aussi bien la correction d'une erreur de saisie
  /// que l'historique des modifications exigé par le cahier des charges.
  Future<String?> updateArchive({
    required String id,
    String? title,
    String? summary,
    String? category,
    String? categoryId,
    String? documentTypeId,
    List<String>? keywords,
    String? physicalLocation,
    int? documentCount,
    bool? legalHold,
    List<AttachedFile>? files,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (summary != null) updates['summary'] = summary;
      if (category != null) updates['category'] = category;
      if (categoryId != null) updates['category_id'] = categoryId;
      if (documentTypeId != null) updates['document_type_id'] = documentTypeId;
      if (keywords != null) updates['keywords'] = keywords;
      if (physicalLocation != null) {
        updates['physical_location'] = physicalLocation;
      }
      if (documentCount != null) updates['document_count'] = documentCount;
      if (legalHold != null) updates['legal_hold'] = legalHold;
      if (files != null) {
        updates['documents'] = files.map((f) => f.toJson()).toList();
      }
      if (updates.isEmpty) return null;

      await _client.from('daily_archives').update(updates).eq('id', id);
      return null;
    } catch (e) {
      return 'Erreur lors de la modification de l\'archive : $e';
    }
  }

  /// Recherche serveur (§5.1.3).
  ///
  /// Remplace le filtrage `contains()` sur les listes chargées en mémoire :
  /// l'index GIN fait le travail, la pagination borne le transfert, et le
  /// classement tient compte de la pondération des champs.
  Future<ArchiveSearchPage> searchArchives({
    String? query,
    String? categoryId,
    DateTime? from,
    DateTime? to,
    String? employeeId,
    int limit = 50,
    int offset = 0,
  }) async {
    String? day(DateTime? d) => d?.toIso8601String().substring(0, 10);

    final rows = await _client.rpc('search_archives', params: {
      'p_query': (query == null || query.trim().isEmpty) ? null : query.trim(),
      'p_category': categoryId,
      'p_from': day(from),
      'p_to': day(to),
      'p_employee': employeeId,
      'p_limit': limit,
      'p_offset': offset,
    }) as List;

    final results = rows
        .cast<Map<String, dynamic>>()
        .map(ArchiveSearchResult.fromJson)
        .toList();

    return ArchiveSearchPage(
      results: results,
      // `total_count` est calculé par une fenêtre sur la requête filtrée :
      // il vaut pour l'ensemble du résultat, pas pour la seule page.
      totalCount: results.isEmpty ? 0 : results.first.totalCount,
      offset: offset,
      limit: limit,
    );
  }

  /// Journalise une consultation de document (§5.1.5).
  ///
  /// Une lecture ne déclenche aucun trigger : elle doit être déclarée. La
  /// fonction serveur déduit l'acteur du JWT, il n'est donc pas falsifiable.
  Future<void> logDocumentAccess({
    required String entityType,
    required String entityId,
    String? details,
  }) async {
    try {
      await _client.rpc('log_document_access', params: {
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_details': details,
      });
    } catch (e) {
      debugPrint('Échec de journalisation de consultation : $e');
    }
  }

  // ─── Taxonomie et conservation (§5.1.2, §5.1.4) ──────────────────────────

  Future<List<ArchiveCategory>> fetchCategories() async {
    final data = await _client
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return data.map(ArchiveCategory.fromJson).toList();
  }

  Future<List<RetentionRule>> fetchDocumentTypes() async {
    final data = await _client
        .from('document_types')
        .select()
        .eq('is_active', true)
        .order('label', ascending: true);
    return data.map(RetentionRule.fromJson).toList();
  }

  // ─── Versions de documents (§5.1.6) ──────────────────────────────────────

  Future<List<DocumentVersion>> fetchDocumentVersions(String archiveId) async {
    final data = await _client
        .from('document_versions')
        .select()
        .eq('archive_id', archiveId)
        .order('version_number', ascending: false);
    return data.map(DocumentVersion.fromJson).toList();
  }

  /// Enregistre une nouvelle révision d'une pièce jointe.
  ///
  /// Le numéro de version et le refus d'un contenu identique sont gérés
  /// côté base : deux clients concurrents ne peuvent pas produire le même
  /// numéro, ce qu'un calcul applicatif ne garantirait pas.
  Future<String?> addDocumentVersion({
    required String archiveId,
    required AttachedFile file,
    String? comment,
  }) async {
    try {
      if (file.storagePath == null) {
        return 'La pièce doit être envoyée avant d\'être versionnée.';
      }
      await _client.from('document_versions').insert({
        'organization_id': await _requireOrganizationId(),
        'archive_id': archiveId,
        'file_name': file.name,
        'mime_type': file.mimeType,
        'size_bytes': file.sizeBytes,
        'checksum_sha256': file.checksumSha256,
        'storage_path': file.storagePath,
        'comment': comment,
        'created_by': _client.auth.currentUser?.id,
      });
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return 'Cette version est identique à la précédente.';
      }
      return 'Erreur lors de l\'enregistrement de la version : ${e.message}';
    } catch (e) {
      return 'Erreur lors de l\'enregistrement de la version : $e';
    }
  }

  // ─── Candidates ──────────────────────────────────────────────────────────

  Future<List<Candidate>> fetchAllCandidates() async {
    final data = await _client
        .from('candidates')
        .select()
        .order('application_date', ascending: false);
    return data.map(_mapCandidate).toList();
  }

  Future<String?> insertCandidate(Candidate candidate) async {
    try {
      await _client.from('candidates').insert({
        'id': candidate.id,
        'organization_id': await _requireOrganizationId(),
        'full_name': candidate.fullName,
        'target_position': candidate.targetPosition,
        'email': candidate.email,
        'phone': candidate.phone,
        'application_date': candidate.applicationDate.toIso8601String(),
        'status': candidate.status.name,
        'rh_notes': candidate.rhNotes,
        'is_deleted': false,
        'documents': candidate.documents.map((f) => f.toJson()).toList(),
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
    await _client.from('candidates').update({'is_deleted': true}).eq('id', id);
  }

  // ─── Logistics ───────────────────────────────────────────────────────────

  Future<List<LogisticsItem>> fetchAllLogisticsItems() async {
    final data = await _client
        .from('logistics_items')
        .select()
        .order('issue_date', ascending: false);
    return data.map(_mapLogisticsItem).toList();
  }

  Future<String?> insertLogisticsItem(LogisticsItem item) async {
    try {
      await _client.from('logistics_items').insert({
        'id': item.id,
        'organization_id': await _requireOrganizationId(),
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
        .update({'is_deleted': true})
        .eq('id', id);
  }

  // ─── Action History ──────────────────────────────────────────────────────

  Future<void> insertHistoryEntry({
    required ActionHistoryEntry entry,
    String? candidateId,
    String? logisticsItemId,
  }) async {
    try {
      await _client.from('action_history_entries').insert({
        'organization_id': await _requireOrganizationId(),
        'employee_id': _client.auth.currentUser?.id,
        'user_name': entry.userName,
        'action': entry.action,
        'details': entry.details,
        'timestamp': entry.timestamp.toIso8601String(),
        if (candidateId != null) 'candidate_id': candidateId,
        if (logisticsItemId != null) 'logistics_item_id': logisticsItemId,
      });
    } catch (e) {
      // Le journal ne doit pas bloquer l'action de l'utilisateur, mais un
      // échec silencieux masque une piste d'audit incomplète : on le remonte
      // au moins en console jusqu'à la bascule sur les triggers serveur.
      debugPrint('Échec d\'écriture du journal d\'activité : $e');
    }
  }

  Future<List<ActionHistoryEntry>> fetchActivityLog({int limit = 200}) async {
    final data = await _client
        .from('action_history_entries')
        .select()
        .order('timestamp', ascending: false)
        .limit(limit);
    return data
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
    return data
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
      'organization_id': await _requireOrganizationId(),
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

  // ─── Offres d'emploi (§5.2) ──────────────────────────────────────────────

  /// Offres de l'organisation. [includeTemplates] à false pour la liste
  /// courante : un modèle n'est pas une offre à pourvoir.
  Future<List<JobOffer>> fetchJobOffers({bool includeTemplates = false}) async {
    var query = _client.from('job_offers').select();
    if (!includeTemplates) {
      query = query.eq('is_template', false);
    }
    final data = await query.order('created_at', ascending: false);
    return data.map(JobOffer.fromJson).toList();
  }

  Future<List<JobOffer>> fetchJobOfferTemplates() async {
    final data = await _client
        .from('job_offers')
        .select()
        .eq('is_template', true)
        .order('template_name', ascending: true);
    return data.map(JobOffer.fromJson).toList();
  }

  /// Crée une offre. Elle démarre toujours en brouillon : le workflow de
  /// validation n'est pas contournable par le point d'entrée de création.
  Future<String?> createJobOffer(JobOffer offer, {bool asTemplate = false}) async {
    try {
      final row = await _client
          .from('job_offers')
          .insert({
            ...offer.toWritableJson(),
            'organization_id': await _requireOrganizationId(),
            'created_by': _client.auth.currentUser?.id,
            'is_template': asTemplate,
            if (asTemplate) 'template_name': offer.templateName ?? offer.title,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } on PostgrestException catch (e) {
      throw JobOfferException(_translateOfferError(e));
    }
  }

  Future<void> updateJobOffer(String id, JobOffer offer) async {
    try {
      await _client
          .from('job_offers')
          .update(offer.toWritableJson())
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw JobOfferException(_translateOfferError(e));
    }
  }

  /// Fait avancer le workflow de validation (§5.2.2).
  ///
  /// La transition et l'habilitation sont vérifiées côté base : un appel
  /// direct à PostgREST ne peut pas publier sans validation.
  Future<void> changeOfferWorkflow({
    required String id,
    required OfferWorkflowStatus status,
    String? reason,
  }) async {
    try {
      await _client.from('job_offers').update({
        'workflow_status': status.code,
        if (reason != null) 'rejection_reason': reason,
      }).eq('id', id);
    } on PostgrestException catch (e) {
      throw JobOfferException(_translateOfferError(e));
    }
  }

  Future<void> changeOfferLifecycle({
    required String id,
    required OfferLifecycleStatus status,
  }) async {
    try {
      await _client
          .from('job_offers')
          .update({'lifecycle_status': status.code}).eq('id', id);
    } on PostgrestException catch (e) {
      throw JobOfferException(_translateOfferError(e));
    }
  }

  /// Duplique une offre ou instancie un modèle (§5.2.5).
  /// La copie repart en brouillon, avec une nouvelle référence.
  Future<String> duplicateJobOffer(
    String sourceId, {
    bool asTemplate = false,
    String? title,
  }) async {
    try {
      final id = await _client.rpc('duplicate_job_offer', params: {
        'p_source_id': sourceId,
        'p_as_template': asTemplate,
        'p_title': title,
      });
      return id as String;
    } on PostgrestException catch (e) {
      throw JobOfferException(_translateOfferError(e));
    }
  }

  Future<void> deleteJobOffer(String id) async {
    try {
      await _client.from('job_offers').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw JobOfferException(_translateOfferError(e));
    }
  }

  Future<List<JobOfferTransition>> fetchOfferTransitions(String offerId) async {
    final data = await _client
        .from('job_offer_transitions')
        .select('*, employees:changed_by(full_name)')
        .eq('job_offer_id', offerId)
        .order('changed_at', ascending: true);

    return data.map((row) {
      final employee = row['employees'] as Map<String, dynamic>?;
      return JobOfferTransition.fromJson({
        ...row,
        'changed_by_name': employee?['full_name'],
      });
    }).toList();
  }

  /// Traduit les erreurs de contrainte en messages exploitables.
  ///
  /// Les messages bruts de PostgreSQL nomment des contraintes internes que
  /// l'utilisateur ne peut pas comprendre.
  String _translateOfferError(PostgrestException e) {
    final message = e.message;
    if (message.contains('job_offers_salary_range')) {
      return 'Le salaire maximum doit être supérieur au minimum.';
    }
    if (message.contains('job_offers_template_not_published')) {
      return 'Un modèle ne peut pas entrer dans le circuit de publication.';
    }
    if (message.contains('Transition de workflow interdite')) {
      return 'Cette étape n\'est pas accessible depuis le statut actuel.';
    }
    if (message.contains('Un rejet doit être motivé')) {
      return 'Merci d\'indiquer le motif du rejet.';
    }
    if (message.contains('Validation d\'offre non autorisée')) {
      return 'Votre rôle ne permet pas de valider une offre.';
    }
    if (e.code == '23505') {
      return 'Une offre porte déjà cette référence.';
    }
    if (e.code == '42501') {
      return 'Action non autorisée pour votre rôle.';
    }
    return 'Erreur : $message';
  }

  // ─── Candidatures (§5.3) ─────────────────────────────────────────────────

  Future<List<PipelineStage>> fetchPipelineStages() async {
    final data = await _client
        .from('pipeline_stages')
        .select()
        .eq('is_active', true)
        .order('position', ascending: true);
    return data.map(PipelineStage.fromJson).toList();
  }

  /// Candidatures avec le candidat et l'offre joints, pour éviter une
  /// requête par ligne à l'affichage du tableau de bord.
  Future<List<Application>> fetchApplications({String? jobOfferId}) async {
    var query = _client.from('applications').select(
        '*, candidates:candidate_id(full_name, email), '
        'job_offers:job_offer_id(title, reference)');
    if (jobOfferId != null) {
      query = query.eq('job_offer_id', jobOfferId);
    }
    final data = await query.order('applied_at', ascending: false);
    return data.map(Application.fromJson).toList();
  }

  Future<String> createApplication({
    required String candidateId,
    String? jobOfferId,
    required String stageId,
    ApplicationSource source = ApplicationSource.interne,
  }) async {
    try {
      final row = await _client
          .from('applications')
          .insert({
            'organization_id': await _requireOrganizationId(),
            'candidate_id': candidateId,
            'job_offer_id': jobOfferId,
            'stage_id': stageId,
            'source': source.code,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } on PostgrestException catch (e) {
      throw ApplicationException(_translateApplicationError(e));
    }
  }

  /// Déplace une candidature dans le pipeline (§5.3.2).
  ///
  /// L'historique, la clôture et la notification sont produits par un trigger :
  /// un déplacement ne peut pas échapper à sa trace.
  Future<void> moveApplication({
    required String id,
    required String stageId,
  }) async {
    try {
      await _client
          .from('applications')
          .update({'stage_id': stageId}).eq('id', id);
    } on PostgrestException catch (e) {
      throw ApplicationException(_translateApplicationError(e));
    }
  }

  Future<List<StageTransition>> fetchStageHistory(String applicationId) async {
    final data = await _client
        .from('application_stage_history')
        .select('*, employees:changed_by(full_name)')
        .eq('application_id', applicationId)
        .order('changed_at', ascending: true);

    return data.map((row) {
      final employee = row['employees'] as Map<String, dynamic>?;
      return StageTransition.fromJson({
        ...row,
        'changed_by_name': employee?['full_name'],
      });
    }).toList();
  }

  // ─── Avis et notations (§5.3.3) ──────────────────────────────────────────

  Future<List<ApplicationNote>> fetchApplicationNotes(String applicationId) async {
    final data = await _client
        .from('application_notes')
        .select('*, employees:author_id(full_name)')
        .eq('application_id', applicationId)
        .order('created_at', ascending: false);
    return data.map(ApplicationNote.fromJson).toList();
  }

  Future<void> addApplicationNote({
    required String applicationId,
    required String body,
    int? rating,
    String? stageId,
  }) async {
    final authorId = _client.auth.currentUser?.id;
    if (authorId == null) {
      throw const ApplicationException('Aucune session active.');
    }
    try {
      await _client.from('application_notes').insert({
        'application_id': applicationId,
        // La politique RLS exige author_id = auth.uid() : on ne peut pas
        // signer au nom d'un collègue.
        'author_id': authorId,
        'body': body,
        'rating': rating,
        'stage_id': stageId,
      });
    } on PostgrestException catch (e) {
      throw ApplicationException(_translateApplicationError(e));
    }
  }

  Future<void> deleteApplicationNote(String id) async {
    await _client.from('application_notes').delete().eq('id', id);
  }

  // ─── Entretiens (§5.3.5) ─────────────────────────────────────────────────

  Future<List<Interview>> fetchInterviews({String? applicationId}) async {
    var query = _client.from('interviews').select();
    if (applicationId != null) {
      query = query.eq('application_id', applicationId);
    }
    final data = await query.order('scheduled_at', ascending: false);
    return data.map(Interview.fromJson).toList();
  }

  Future<String> scheduleInterview(Interview interview) async {
    try {
      final row = await _client
          .from('interviews')
          .insert({
            ...interview.toWritableJson(),
            'organization_id': await _requireOrganizationId(),
            'application_id': interview.applicationId,
            'created_by': _client.auth.currentUser?.id,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } on PostgrestException catch (e) {
      throw ApplicationException(_translateApplicationError(e));
    }
  }

  Future<void> updateInterview(String id, Interview interview) async {
    try {
      await _client
          .from('interviews')
          .update({
            ...interview.toWritableJson(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw ApplicationException(_translateApplicationError(e));
    }
  }

  String _translateApplicationError(PostgrestException e) {
    final message = e.message;
    if (message.contains('applications_candidate_id_job_offer_id_key')) {
      return 'Ce candidat a déjà postulé à cette offre.';
    }
    if (message.contains('Étape de pipeline étrangère')) {
      return 'Cette étape appartient à une autre organisation.';
    }
    if (message.contains('application_notes_rating_check')) {
      return 'La note doit être comprise entre 1 et 5.';
    }
    if (message.contains('pipeline_won_is_terminal')) {
      return 'Une étape de succès doit être une étape de sortie.';
    }
    if (e.code == '42501') {
      return 'Action non autorisée pour votre rôle.';
    }
    return 'Erreur : $message';
  }

  // ─── Reporting et pilotage (§5.4) ────────────────────────────────────────

  /// Synthèse du pilotage en un seul appel.
  ///
  /// Charger sept indicateurs séparément, c'est sept allers-retours réseau
  /// à l'ouverture d'un tableau de bord.
  Future<DashboardSummary> fetchDashboardSummary() async {
    final data = await _client.rpc('hr_dashboard_summary');
    return DashboardSummary.fromJson(data as Map<String, dynamic>);
  }

  Future<List<TimeToHireMetric>> fetchTimeToHire() async {
    final data = await _client
        .from('v_hr_time_to_hire')
        .select()
        .order('month', ascending: false);
    return data.map(TimeToHireMetric.fromJson).toList();
  }

  Future<List<FunnelStep>> fetchFunnel() async {
    final data = await _client
        .from('v_hr_funnel')
        .select()
        .order('position', ascending: true);
    return data.map(FunnelStep.fromJson).toList();
  }

  Future<List<SourceMetric>> fetchSourceMetrics() async {
    final data = await _client
        .from('v_hr_sources')
        .select()
        .order('total', ascending: false);
    return data.map(SourceMetric.fromJson).toList();
  }

  Future<List<ArchiveVolumeMetric>> fetchArchiveVolume() async {
    final data = await _client
        .from('v_archive_volume')
        .select()
        .order('month', ascending: false);
    return data.map(ArchiveVolumeMetric.fromJson).toList();
  }

  Future<RetentionCompliance> fetchRetentionCompliance() async {
    final data = await _client
        .from('v_retention_compliance')
        .select()
        .maybeSingle();
    // Aucune ligne signifie aucune archive : un parc vide n'est pas un
    // parc non conforme.
    return data == null
        ? const RetentionCompliance.empty()
        : RetentionCompliance.fromJson(data);
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

      final history = data.map((m) {
        final planData = m['subscription_plans'] as Map<String, dynamic>? ?? {};
        m['plan_name'] = planData['name'];
        return SubscriptionTransaction.fromJson(m);
      }).toList();

      final active = history.where((t) => t.isActive).firstOrNull;

      SubscriptionPlan? activePlan;
      if (active != null) {
        final activeRow = data.firstWhere((m) => m['id'] == active.id);
        final planRow = activeRow['subscription_plans'] as Map<String, dynamic>?;
        if (planRow != null) activePlan = SubscriptionPlan.fromJson(planRow);
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
    return data.map(SubscriptionPlan.fromJson).toList();
  }

  // ─── Liste d'autorisation des employés ───────────────────────────────────

  /// Adresses pré-autorisées de l'organisation courante.
  ///
  /// La RLS réserve déjà cette table à l'administration du tenant
  /// (`allowed_emails_select`) : un `employe` qui appellerait cette méthode
  /// obtiendrait une liste vide, pas l'annuaire de l'entreprise.
  Future<List<AllowedEmail>> fetchAllowedEmails() async {
    final data = await _client
        .from('allowed_employee_emails')
        .select()
        .order('created_at', ascending: false);
    return data.map(AllowedEmail.fromJson).toList();
  }

  /// Ajoute une adresse à la liste. Retourne `null` si l'ajout a réussi.
  Future<String?> addAllowedEmail({
    required String email,
    String? fullName,
    required UserRole role,
    String jobTitle = '',
  }) async {
    if (role == UserRole.superAdmin) {
      return 'Le rôle super administrateur est réservé à la plateforme.';
    }
    try {
      final organizationId = await _requireOrganizationId();
      await _client.from('allowed_employee_emails').insert({
        'organization_id': organizationId,
        'email': normalizeEmail(email),
        'full_name': fullName?.trim().isEmpty ?? true ? null : fullName!.trim(),
        'role': role.name,
        'job_title': role == UserRole.employe ? jobTitle : '',
        'status': 'pending',
        'invited_by': currentAuthUser?.id,
      });
      return null;
    } on PostgrestException catch (e) {
      return _translateAllowedEmailError(e);
    } catch (e) {
      return 'Erreur réseau : $e';
    }
  }

  /// Modifie le rôle, le poste ou le nom d'une entrée en attente.
  Future<void> updateAllowedEmail({
    required String id,
    String? fullName,
    UserRole? role,
    String? jobTitle,
  }) async {
    final patch = <String, dynamic>{};
    if (fullName != null) {
      patch['full_name'] = fullName.trim().isEmpty ? null : fullName.trim();
    }
    if (role != null) {
      if (role == UserRole.superAdmin) {
        throw ArgumentError(
          'Le rôle super administrateur ne peut pas être pré-attribué.',
        );
      }
      patch['role'] = role.name;
    }
    if (jobTitle != null) patch['job_title'] = jobTitle;
    if (patch.isEmpty) return;
    await _client.from('allowed_employee_emails').update(patch).eq('id', id);
  }

  /// Retire l'autorisation sans effacer la trace : l'inscription est refusée.
  Future<void> revokeAllowedEmail(String id) async {
    await _client
        .from('allowed_employee_emails')
        .update({'status': 'revoked'})
        .eq('id', id);
  }

  /// Rouvre une autorisation révoquée.
  Future<void> restoreAllowedEmail(String id) async {
    await _client
        .from('allowed_employee_emails')
        .update({'status': 'pending'})
        .eq('id', id);
  }

  /// Efface une entrée jamais utilisée. La politique `allowed_emails_delete`
  /// refuse les entrées déjà consommées : celles-là se révoquent.
  Future<void> deleteAllowedEmail(String id) async {
    await _client.from('allowed_employee_emails').delete().eq('id', id);
  }

  String _translateAllowedEmailError(PostgrestException e) {
    // 23505 : violation d'unicité sur `allowed_emails_email_key`. L'index est
    // global — l'adresse peut donc être réservée par une AUTRE organisation,
    // que la RLS empêche de voir. Le message doit couvrir les deux cas.
    if (e.code == '23505') {
      return 'Cette adresse est déjà enregistrée, ici ou dans une autre '
          'organisation.';
    }
    if (e.code == '42501') {
      return "Vous n'avez pas le droit de modifier cette liste.";
    }
    if (e.code == '23514') {
      return 'Rôle ou statut invalide.';
    }
    return e.message;
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
      role: UserRole.fromName(m['role'] as String?),
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
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.tryParse(v as String);

    return DailyArchive(
      id: m['id'] as String,
      employeeId: m['employee_id'] as String? ?? '',
      employeeName: m['employee_name'] as String? ?? '',
      jobTitle: m['job_title'] as String? ?? '',
      archiveDate: DateTime.parse(m['archive_date'] as String),
      title: m['title'] as String? ?? '',
      summary: m['summary'] as String? ?? '',
      category: m['category'] as String? ?? '',
      categoryId: m['category_id'] as String?,
      documentTypeId: m['document_type_id'] as String?,
      keywords: (m['keywords'] as List?)?.cast<String>() ?? const [],
      documentCount: m['document_count'] as int? ?? 0,
      physicalLocation: m['physical_location'] as String? ?? '',
      submittedAt: DateTime.parse(m['submitted_at'] as String),
      deletedAt: parse(m['deleted_at']),
      legalHold: m['legal_hold'] as bool? ?? false,
      retentionUntil: parse(m['retention_until']),
      purgedAt: parse(m['purged_at']),
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

/// Type MIME déduit de l'extension.
///
/// Storage le déduit sinon du nom de fichier, ce qui donne
/// `application/octet-stream` pour tout ce qu'il ne reconnaît pas — et le
/// navigateur propose alors un téléchargement là où un aperçu suffirait.
String mimeTypeFor(String extension) {
  switch (extension.toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'txt':
      return 'text/plain; charset=utf-8';
    case 'csv':
      return 'text/csv; charset=utf-8';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'zip':
      return 'application/zip';
    default:
      return 'application/octet-stream';
  }
}

/// Erreur métier sur une offre d'emploi, déjà traduite pour l'utilisateur.
class JobOfferException implements Exception {
  final String message;
  const JobOfferException(this.message);

  @override
  String toString() => message;
}

/// Erreur métier sur une candidature, déjà traduite pour l'utilisateur.
class ApplicationException implements Exception {
  final String message;
  const ApplicationException(this.message);

  @override
  String toString() => message;
}
