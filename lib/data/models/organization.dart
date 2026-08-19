class Organization {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String logoUrl;
  final String country;
  final String currency;
  final String timezone;
  final double storageLimitGB;
  final double storageUsedGB;
  final int maxUsers;
  final String planName;
  final DateTime createdAt;

  const Organization({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.logoUrl,
    required this.country,
    required this.currency,
    required this.timezone,
    required this.storageLimitGB,
    required this.storageUsedGB,
    required this.maxUsers,
    required this.planName,
    required this.createdAt,
  });

  double get storagePercentage => (storageUsedGB / storageLimitGB).clamp(0.0, 1.0);
}
