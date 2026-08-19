import 'package:flutter/material.dart';
import '../data/models/user.dart';
import '../data/models/organization.dart';
import '../data/models/permission.dart';
import '../data/models/role.dart';
import '../data/models/department.dart';
import '../data/models/category.dart';
import '../data/models/folder.dart';
import '../data/models/document.dart';
import '../data/models/physical_location.dart';
import '../data/models/access_request.dart';
import '../data/models/audit_log.dart';
import '../data/models/notification_item.dart';
import '../data/models/daily_archive.dart';
import '../data/datasources/mock_data.dart';
import '../core/security/security_manager.dart';

class AppStateProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  String _currentLanguage = 'FR';
  
  User _currentUser = MockData.demoUsers[0]; // Admin by default
  final Organization _currentOrg = MockData.demoOrg;
  
  final List<DocumentItem> _documents = List.from(MockData.demoDocuments);
  final List<Folder> _folders = List.from(MockData.demoFolders);
  final List<Category> _categories = List.from(MockData.demoCategories);
  final List<Department> _departments = List.from(MockData.demoDepartments);
  final List<User> _users = List.from(MockData.demoUsers);
  final List<PhysicalLocation> _physicalLocations = List.from(MockData.demoPhysicalLocations);
  final List<AccessRequestItem> _accessRequests = List.from(MockData.demoRequests);
  List<NotificationItem> _notifications = List.from(MockData.demoNotifications);
  final List<AuditLogItem> _auditLogs = List.from(MockData.demoAuditLogs);
  final List<DailyArchiveItem> _dailyArchives = List.from(MockData.demoDailyArchives);
  
  // Search & Filter State
  String _searchQuery = '';
  String? _selectedCategoryId;
  String? _selectedDepartmentId;
  ConfidentialityLevel? _selectedConfidentiality;
  
  // Getters
  bool get isDarkMode => _isDarkMode;
  String get currentLanguage => _currentLanguage;
  User get currentUser => _currentUser;
  Organization get currentOrg => _currentOrg;
  
  List<DocumentItem> get documents => _documents;
  List<Folder> get folders => _folders;
  List<Category> get categories => _categories;
  List<Department> get departments => _departments;
  List<User> get users => _users;
  List<PhysicalLocation> get physicalLocations => _physicalLocations;
  List<AccessRequestItem> get accessRequests => _accessRequests;
  List<NotificationItem> get notifications => _notifications;
  List<AuditLogItem> get auditLogs => _auditLogs;
  List<DailyArchiveItem> get dailyArchives => _dailyArchives;
  
  String get searchQuery => _searchQuery;
  String? get selectedCategoryId => _selectedCategoryId;
  String? get selectedDepartmentId => _selectedDepartmentId;
  
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  // Filtered documents getter
  List<DocumentItem> get filteredDocuments {
    return _documents.where((doc) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = doc.title.toLowerCase().contains(q);
        final matchRef = doc.reference.toLowerCase().contains(q);
        final matchKw = doc.keywords.any((k) => k.toLowerCase().contains(q));
        if (!matchTitle && !matchRef && !matchKw) return false;
      }
      if (_selectedCategoryId != null && doc.categoryId != _selectedCategoryId) {
        return false;
      }
      if (_selectedDepartmentId != null && doc.departmentId != _selectedDepartmentId) {
        return false;
      }
      if (_selectedConfidentiality != null && doc.confidentiality != _selectedConfidentiality) {
        return false;
      }
      return true;
    }).toList();
  }

  // State Mutators
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setLanguage(String lang) {
    _currentLanguage = lang;
    notifyListeners();
  }

  void switchUserRole(Role newRole) {
    _currentUser = User(
      id: _currentUser.id,
      organizationId: _currentUser.organizationId,
      fullName: _currentUser.fullName,
      email: _currentUser.email,
      phone: _currentUser.phone,
      departmentId: _currentUser.departmentId,
      departmentName: _currentUser.departmentName,
      role: newRole,
      lastLoginAt: DateTime.now(),
      createdAt: _currentUser.createdAt,
    );
    notifyListeners();
  }

  bool hasPermission(AppPermission permission) {
    return _currentUser.role.hasPermission(permission);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setDepartmentFilter(String? departmentId) {
    _selectedDepartmentId = departmentId;
    notifyListeners();
  }

  void addDocument(DocumentItem doc) {
    final allowed = SecurityManager().canExecute(
      user: _currentUser,
      targetOrganizationId: doc.organizationId,
      requiredPermission: AppPermission.createDocument,
      actionName: 'Création Document',
      resourceName: doc.reference,
      onViolationLogged: logSecurityViolation,
    );
    if (!allowed) return;

    _documents.insert(0, doc);
    _logAudit('DOCUMENT_UPLOAD', doc.reference);
    notifyListeners();
  }

  void updateDocument(DocumentItem doc) {
    final allowed = SecurityManager().canExecute(
      user: _currentUser,
      targetOrganizationId: doc.organizationId,
      requiredPermission: AppPermission.updateDocument,
      actionName: 'Modification Document',
      resourceName: doc.reference,
      onViolationLogged: logSecurityViolation,
    );
    if (!allowed) return;

    final index = _documents.indexWhere((d) => d.id == doc.id);
    if (index != -1) {
      _documents[index] = doc;
      _logAudit('DOCUMENT_UPDATE', doc.reference);
      notifyListeners();
    }
  }

  void deleteDocument(String docId) {
    final doc = _documents.firstWhere((d) => d.id == docId);
    final allowed = SecurityManager().canExecute(
      user: _currentUser,
      targetOrganizationId: doc.organizationId,
      requiredPermission: AppPermission.deleteDocument,
      actionName: 'Suppression Document',
      resourceName: doc.reference,
      onViolationLogged: logSecurityViolation,
    );
    if (!allowed) return;

    _documents.removeWhere((d) => d.id == docId);
    _logAudit('DOCUMENT_DELETE', doc.reference);
    notifyListeners();
  }

  void archiveDocument(String docId) {
    final index = _documents.indexWhere((d) => d.id == docId);
    if (index != -1) {
      final doc = _documents[index];
      final allowed = SecurityManager().canExecute(
        user: _currentUser,
        targetOrganizationId: doc.organizationId,
        requiredPermission: AppPermission.updateDocument,
        actionName: 'Archivage Document',
        resourceName: doc.reference,
        onViolationLogged: logSecurityViolation,
      );
      if (!allowed) return;

      _documents[index] = _documents[index].copyWith(isArchived: true);
      _logAudit('DOCUMENT_ARCHIVED', _documents[index].reference);
      notifyListeners();
    }
  }

  void handleAccessRequest(String requestId, bool approve) {
    final index = _accessRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final req = _accessRequests[index];
      final allowed = SecurityManager().canExecute(
        user: _currentUser,
        targetOrganizationId: _currentOrg.id,
        requiredPermission: AppPermission.manageUsers,
        actionName: 'Décision Demande d Accès',
        resourceName: 'Req ID: $requestId (${req.userName})',
        onViolationLogged: logSecurityViolation,
      );
      if (!allowed) return;

      _accessRequests[index] = _accessRequests[index].copyWith(
        status: approve ? RequestStatus.approved : RequestStatus.rejected,
      );
      _logAudit('ACCESS_REQUEST_DECISION', 'Req ID: $requestId');
      notifyListeners();
    }
  }

  void markAllNotificationsRead() {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  void toggleUserStatus(String userId) {
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final u = _users[index];
      final allowed = SecurityManager().canExecute(
        user: _currentUser,
        targetOrganizationId: u.organizationId,
        requiredPermission: AppPermission.manageUsers,
        actionName: 'Modification Statut Utilisateur',
        resourceName: u.email,
        onViolationLogged: logSecurityViolation,
      );
      if (!allowed) return;

      _users[index] = User(
        id: u.id,
        organizationId: u.organizationId,
        fullName: u.fullName,
        email: u.email,
        phone: u.phone,
        departmentId: u.departmentId,
        departmentName: u.departmentName,
        role: u.role,
        isActive: !u.isActive,
        lastLoginAt: u.lastLoginAt,
        createdAt: u.createdAt,
      );
      notifyListeners();
    }
  }

  void addFolder(Folder folder) {
    _folders.add(folder);
    notifyListeners();
  }

  void addDepartment(Department dept) {
    final allowed = SecurityManager().canExecute(
      user: _currentUser,
      targetOrganizationId: dept.organizationId,
      requiredPermission: AppPermission.manageDepartments,
      actionName: 'Création Département',
      resourceName: dept.name,
      onViolationLogged: logSecurityViolation,
    );
    if (!allowed) return;

    _departments.add(dept);
    _logAudit('DEPARTMENT_CREATE', dept.name);
    notifyListeners();
  }

  void addCategory(Category cat) {
    final allowed = SecurityManager().canExecute(
      user: _currentUser,
      targetOrganizationId: cat.organizationId,
      requiredPermission: AppPermission.manageCategories,
      actionName: 'Création Catégorie',
      resourceName: cat.name,
      onViolationLogged: logSecurityViolation,
    );
    if (!allowed) return;

    _categories.add(cat);
    _logAudit('CATEGORY_CREATE', cat.name);
    notifyListeners();
  }

  void addPhysicalLocation(PhysicalLocation loc) {
    _physicalLocations.add(loc);
    notifyListeners();
  }

  void addDailyArchive(DailyArchiveItem item) {
    final allowed = SecurityManager().canExecute(
      user: _currentUser,
      targetOrganizationId: item.organizationId,
      requiredPermission: AppPermission.createDocument,
      actionName: 'Versement Archive Journalière',
      resourceName: item.reference,
      onViolationLogged: logSecurityViolation,
    );
    if (!allowed) return;

    _dailyArchives.insert(0, item);
    _logAudit('ARCHIVE_JOURNALIERE_SUBMIT', '${item.userJobTitle} - ${item.reference}');
    notifyListeners();
  }

  void logSecurityViolation(String action, String details) {
    _auditLogs.insert(
      0,
      AuditLogItem(
        id: 'sec_log_${DateTime.now().millisecondsSinceEpoch}',
        organizationId: _currentOrg.id,
        userName: '${_currentUser.fullName} [VIOLATION]',
        action: action,
        targetResource: details,
        timestamp: DateTime.now(),
        ipAddress: '197.225.34.12',
        deviceInfo: 'SecurityManager Guard Engine',
      ),
    );
    notifyListeners();
  }

  void _logAudit(String action, String target) {
    _auditLogs.insert(
      0,
      AuditLogItem(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}',
        organizationId: _currentOrg.id,
        userName: _currentUser.fullName,
        action: action,
        targetResource: target,
        timestamp: DateTime.now(),
        ipAddress: '197.225.34.12',
        deviceInfo: 'Flutter Web/Desktop Shell',
      ),
    );
  }
}
