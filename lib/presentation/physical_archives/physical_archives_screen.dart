import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/physical_location.dart';
import '../app_state.dart';
import '../widgets/app_button.dart';
import '../widgets/qr_code_widget.dart';

class PhysicalArchivesScreen extends StatefulWidget {
  final AppStateProvider appState;

  const PhysicalArchivesScreen({super.key, required this.appState});

  @override
  State<PhysicalArchivesScreen> createState() => _PhysicalArchivesScreenState();
}

class _PhysicalArchivesScreenState extends State<PhysicalArchivesScreen> {
  void _createNewLocation() {
    final buildingCtrl = TextEditingController(text: 'Bâtiment Principal A');
    final roomCtrl = TextEditingController(text: 'Salle S4');
    final cabinetCtrl = TextEditingController(text: 'Armoire 03');
    final shelfCtrl = TextEditingController(text: 'Rayon R2');
    final boxCtrl = TextEditingController(text: 'B-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau conteneur / Boîte d archives (GAE)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: buildingCtrl, decoration: const InputDecoration(labelText: 'Bâtiment')),
              const SizedBox(height: 10),
              TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Salle')),
              const SizedBox(height: 10),
              TextField(controller: cabinetCtrl, decoration: const InputDecoration(labelText: 'Armoire')),
              const SizedBox(height: 10),
              TextField(controller: shelfCtrl, decoration: const InputDecoration(labelText: 'Rayon')),
              const SizedBox(height: 10),
              TextField(controller: boxCtrl, decoration: const InputDecoration(labelText: 'Réf Boîte')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final loc = PhysicalLocation(
                id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
                organizationId: widget.appState.currentOrg.id,
                building: buildingCtrl.text,
                room: roomCtrl.text,
                cabinet: cabinetCtrl.text,
                shelf: shelfCtrl.text,
                boxRef: boxCtrl.text,
                qrCodeData: 'FALE-BOX-${boxCtrl.text}',
                documentCount: 0,
              );
              widget.appState.addPhysicalLocation(loc);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Emplacement Boîte ${loc.boxRef} enregistré !')),
              );
            },
            child: const Text('Créer l emplacement'),
          ),
        ],
      ),
    );
  }

  void _showQrCodeModal(PhysicalLocation loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('QR Code - Boîte d archives ${loc.boxRef}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrCodeWidget(data: loc.qrCodeData, size: 160),
            const SizedBox(height: 12),
            Text(
              loc.fullAddress,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              'Code: ${loc.qrCodeData}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Imprimer l étiquette QR'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Impression de l étiquette QR démarrée...')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locations = widget.appState.physicalLocations;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gestion des Archives Physiques (GAE)',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Localisation 6 niveaux : Bâtiment > Salle > Armoire > Rayon > Boîte > Document avec QR Code.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              AppButton(
                label: 'Nouvel Emplacement Boîte',
                icon: Icons.qr_code_2,
                onPressed: _createNewLocation,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final loc = locations[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2, color: AppColors.accentTeal, size: 24),
                    ),
                    title: Text(
                      'Boîte ${loc.boxRef} (${loc.documentCount} documents physiques)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(loc.fullAddress),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.qr_code, color: AppColors.primary),
                          tooltip: 'Voir QR Code',
                          onPressed: () => _showQrCodeModal(loc),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
