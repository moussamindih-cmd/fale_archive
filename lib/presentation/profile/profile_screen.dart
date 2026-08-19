import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../app_state.dart';

class ProfileScreen extends StatefulWidget {
  final AppStateProvider appState;

  const ProfileScreen({super.key, required this.appState});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _enable2FA = true;
  bool _emailNotifs = true;

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          user.fullName.substring(0, 1),
                          style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${user.email} • Rôle: ${user.role.name}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Département: ${user.departmentName}',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sécurité & Authentification à Deux Facteurs (2FA)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      SwitchListTile(
                        title: const Text('Activer l authentification 2FA (TOTP / OTP)'),
                        subtitle: const Text('Exiger un code de vérification à chaque connexion'),
                        value: _enable2FA,
                        onChanged: (val) => setState(() => _enable2FA = val),
                      ),
                      SwitchListTile(
                        title: const Text('Notifications par email'),
                        subtitle: const Text('Recevoir un résumé en cas de modification ou expiration'),
                        value: _emailNotifs,
                        onChanged: (val) => setState(() => _emailNotifs = val),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
