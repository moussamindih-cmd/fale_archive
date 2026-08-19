import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../app_state.dart';
import '../widgets/app_button.dart';

class ReportsScreen extends StatelessWidget {
  final AppStateProvider appState;

  const ReportsScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
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
                    'Rapports & Statistiques d Archives',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Générez et exportez les statistiques mensuelles au format PDF, Excel ou CSV.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  AppButton(
                    label: 'Export Excel / CSV',
                    icon: Icons.table_chart,
                    variant: AppButtonVariant.outlined,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Exportation CSV générée avec succès !')),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Générer Rapport PDF',
                    icon: Icons.picture_as_pdf,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Génération du rapport PDF d audit en cours...')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Volume d archivage mensuel (2026)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        const Expanded(
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _BarItem(label: 'Jan', heightFraction: 0.5, color: AppColors.primary),
                                _BarItem(label: 'Fév', heightFraction: 0.8, color: AppColors.primary),
                                _BarItem(label: 'Mar', heightFraction: 0.6, color: AppColors.primary),
                                _BarItem(label: 'Avr', heightFraction: 0.9, color: AppColors.accentTeal),
                                _BarItem(label: 'Mai', heightFraction: 0.4, color: AppColors.accentTeal),
                                _BarItem(label: 'Juin', heightFraction: 0.7, color: AppColors.accentTeal),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statut des durées de conservation',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 20),
                        _buildSummaryItem('Archives Actives', '720 docs', AppColors.accentEmerald),
                        _buildSummaryItem('Proches d expiration', '15 docs', AppColors.accentAmber),
                        _buildSummaryItem('Expirées & À détruire', '4 docs', AppColors.accentCrimson),
                        _buildSummaryItem('Détruites définitivement', '45 docs', AppColors.statusArchived),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
          Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final String label;
  final double heightFraction;
  final Color color;

  const _BarItem({required this.label, required this.heightFraction, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: 120 * heightFraction,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
