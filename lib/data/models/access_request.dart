enum RequestStatus { pending, approved, rejected, expired }

class AccessRequestItem {
  final String id;
  final String organizationId;
  final String documentId;
  final String documentTitle;
  final String userId;
  final String userName;
  final String justification;
  final DateTime requestedAt;
  final RequestStatus status;

  const AccessRequestItem({
    required this.id,
    required this.organizationId,
    required this.documentId,
    required this.documentTitle,
    required this.userId,
    required this.userName,
    required this.justification,
    required this.requestedAt,
    required this.status,
  });

  AccessRequestItem copyWith({RequestStatus? status}) {
    return AccessRequestItem(
      id: id,
      organizationId: organizationId,
      documentId: documentId,
      documentTitle: documentTitle,
      userId: userId,
      userName: userName,
      justification: justification,
      requestedAt: requestedAt,
      status: status ?? this.status,
    );
  }
}
