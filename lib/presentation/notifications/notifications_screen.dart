import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../app_state.dart';
import '../widgets/app_button.dart';

class NotificationsScreen extends StatelessWidget {
  final AppStateProvider appState;

  const NotificationsScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final notifs = appState.notifications;

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
                    'Centre de Notifications',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Restez informé des versements, demandes d accès et expirations.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              AppButton(
                label: 'Tout marquer comme lu',
                icon: Icons.done_all,
                variant: AppButtonVariant.outlined,
                onPressed: appState.markAllNotificationsRead,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: notifs.length,
              itemBuilder: (context, index) {
                final item = notifs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.type == 'EXPIRATION'
                          ? AppColors.accentAmber.withValues(alpha: 0.2)
                          : AppColors.primary.withValues(alpha: 0.2),
                      child: Icon(
                        item.type == 'EXPIRATION' ? Icons.warning : Icons.notifications,
                        color: item.type == 'EXPIRATION' ? AppColors.accentAmber : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(item.message),
                    trailing: Text(
                      '${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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
