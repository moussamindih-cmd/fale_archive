class AuditLogItem {
  final String id;
  final String organizationId;
  final String userName;
  final String action;
  final String targetResource;
  final DateTime timestamp;
  final String ipAddress;
  final String deviceInfo;

  const AuditLogItem({
    required this.id,
    required this.organizationId,
    required this.userName,
    required this.action,
    required this.targetResource,
    required this.timestamp,
    required this.ipAddress,
    required this.deviceInfo,
  });
}
