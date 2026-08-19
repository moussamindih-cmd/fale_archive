import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../app_state.dart';

class AuditLogsScreen extends StatelessWidget {
  final AppStateProvider appState;

  const AuditLogsScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final logs = appState.auditLogs;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Journal d Audit & Traçabilité (Audit Logs)',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            'Historique complet et inaltérable des connexions, consultations et versements.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 900,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        isDark ? AppColors.borderDark : AppColors.bgLight,
                      ),
                      columns: const [
                        DataColumn(label: Text('Horodatage', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Utilisateur', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Ressource Cible', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Adresse IP', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Appareil / Nav', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: logs.map((log) {
                        return DataRow(
                          cells: [
                            DataCell(Text('${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}')),
                            DataCell(Text(log.userName, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(log.action, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            DataCell(Text(log.targetResource)),
                            DataCell(Text(log.ipAddress)),
                            DataCell(Text(log.deviceInfo)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
