import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/access_request.dart';
import '../app_state.dart';
import '../widgets/status_badge.dart';
import '../widgets/app_button.dart';

class AccessRequestsScreen extends StatelessWidget {
  final AppStateProvider appState;

  const AccessRequestsScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final reqs = appState.accessRequests;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demandes d accès aux documents confidentiels',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            'Validez ou rejetez les demandes de consultation soumises par les collaborateurs.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: reqs.isEmpty
                ? const Center(child: Text('Aucune demande en attente.'))
                : ListView.builder(
                    itemCount: reqs.length,
                    itemBuilder: (context, index) {
                      final req = reqs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    req.documentTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  StatusBadge.fromRequestStatus(req.status),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Demandeur: ${req.userName} • Date: ${req.requestedAt.day}/${req.requestedAt.month}/${req.requestedAt.year}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.bgDark : AppColors.bgLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Justification: "${req.justification}"',
                                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                                ),
                              ),
                              if (req.status == RequestStatus.pending) ...[
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    AppButton(
                                      label: 'Refuser',
                                      variant: AppButtonVariant.danger,
                                      onPressed: () {
                                        appState.handleAccessRequest(req.id, false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Demande refusée')),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    AppButton(
                                      label: 'Approuver l accès',
                                      icon: Icons.check,
                                      onPressed: () {
                                        appState.handleAccessRequest(req.id, true);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Accès accordé au collaborateur !')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
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
