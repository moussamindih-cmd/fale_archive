import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../app_state.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class OrganizationSettingsScreen extends StatefulWidget {
  final AppStateProvider appState;

  const OrganizationSettingsScreen({super.key, required this.appState});

  @override
  State<OrganizationSettingsScreen> createState() => _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState extends State<OrganizationSettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    final org = widget.appState.currentOrg;
    _nameCtrl = TextEditingController(text: org.name);
    _addressCtrl = TextEditingController(text: org.address);
    _phoneCtrl = TextEditingController(text: org.phone);
    _emailCtrl = TextEditingController(text: org.email);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paramètres de l Organisation SaaS',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Configurez les informations officielles de votre tenant et le logo FALE TECH.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.business, color: AppColors.primary, size: 36),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Logo Officiel de l Organisation', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.upload, size: 16),
                                label: const Text('Changer de logo'),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      AppTextField(label: 'Nom de l Organisation', controller: _nameCtrl),
                      const SizedBox(height: 16),
                      AppTextField(label: 'Adresse physique', controller: _addressCtrl),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: AppTextField(label: 'Téléphone', controller: _phoneCtrl)),
                          const SizedBox(width: 16),
                          Expanded(child: AppTextField(label: 'Email de contact', controller: _emailCtrl)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Enregistrer les paramètres',
                        icon: Icons.save,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Paramètres enregistrés avec succès !')),
                          );
                        },
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
