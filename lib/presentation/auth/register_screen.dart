import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/app_router.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _orgController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  void _handleRegister() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une organisation'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Inscription FALE ARCHIVES SaaS',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Créez l espace GED sécurisé de votre entreprise ou administration.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Nom complet',
                  hint: 'Ex: Mamadou Diallo',
                  controller: _fullNameController,
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Nom de l organisation / entreprise',
                  hint: 'Ex: Cabinet Conseil SARL',
                  controller: _orgController,
                  prefixIcon: Icons.business_outlined,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Adresse Email professionnelle',
                  hint: 'm.diallo@entreprise.com',
                  controller: _emailController,
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Téléphone',
                  hint: '+221 77 000 00 00',
                  controller: _phoneController,
                  prefixIcon: Icons.phone_outlined,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Mot de passe',
                  hint: '••••••••',
                  controller: _passwordController,
                  isPassword: true,
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Confirmer le mot de passe',
                  hint: '••••••••',
                  controller: _confirmPasswordController,
                  isPassword: true,
                  prefixIcon: Icons.lock_clock_outlined,
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Créer mon espace SaaS',
                  icon: Icons.check_circle_outline,
                  onPressed: _handleRegister,
                  isLoading: _isLoading,
                  isFullWidth: true,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Déjà inscrit ? ', style: TextStyle(fontSize: 13)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Se connecter', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
