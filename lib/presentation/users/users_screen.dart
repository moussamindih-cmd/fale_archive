import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../app_state.dart';
import '../widgets/app_button.dart';

class UsersScreen extends StatelessWidget {
  final AppStateProvider appState;

  const UsersScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final users = appState.users;

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
                    'Gestion des Utilisateurs & Rôles',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Gérez les accès, les affectations aux départements et les permissions.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              AppButton(
                label: 'Inviter un utilisateur',
                icon: Icons.person_add_alt,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Formulaire d invitation envoyé !')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final u = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          u.fullName.substring(0, 1),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${u.email} • Dept: ${u.departmentName} • Rôle: ${u.role.name}'),
                      trailing: Switch(
                        value: u.isActive,
                        onChanged: (val) {
                          appState.toggleUserStatus(u.id);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
