class ShareLinkItem {
  final String id;
  final String documentId;
  final String token;
  final DateTime expiresAt;
  final bool hasPassword;
  final int maxDownloads;
  final int currentDownloads;
  final bool isRevoked;

  const ShareLinkItem({
    required this.id,
    required this.documentId,
    required this.token,
    required this.expiresAt,
    this.hasPassword = false,
    required this.maxDownloads,
    this.currentDownloads = 0,
    this.isRevoked = false,
  });
}
