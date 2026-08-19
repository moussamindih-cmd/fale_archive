class PhysicalLocation {
  final String id;
  final String organizationId;
  final String building; // Bâtiment
  final String room; // Salle
  final String cabinet; // Armoire
  final String shelf; // Rayon
  final String boxRef; // Boîte
  final String qrCodeData;
  final int documentCount;

  const PhysicalLocation({
    required this.id,
    required this.organizationId,
    required this.building,
    required this.room,
    required this.cabinet,
    required this.shelf,
    required this.boxRef,
    required this.qrCodeData,
    required this.documentCount,
  });

  String get fullAddress => "$building > $room > $cabinet > $shelf > Boîte $boxRef";
}
