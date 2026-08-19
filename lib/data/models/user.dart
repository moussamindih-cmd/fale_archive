import 'role.dart';

class User {
  final String id;
  final String organizationId;
  final String fullName;
  final String email;
  final String phone;
  final String departmentId;
  final String departmentName;
  final Role role;
  final bool isActive;
  final DateTime lastLoginAt;
  final DateTime createdAt;
  final String avatarUrl;

  const User({
    required this.id,
    required this.organizationId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.departmentId,
    required this.departmentName,
    required this.role,
    this.isActive = true,
    required this.lastLoginAt,
    required this.createdAt,
    this.avatarUrl = '',
  });
}
