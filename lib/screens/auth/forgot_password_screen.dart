import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';

/// Réinitialisation du mot de passe par email.
///
/// L'écran n'existait pas : un utilisateur ayant perdu son mot de passe
/// devait passer par un administrateur.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isBusy = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isBusy = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailCtrl.text.trim().toLowerCase(),
      );
    } catch (_) {
      // Volontairement silencieux : signaler qu'une adresse est inconnue
      // permettrait d'énumérer les comptes existants.
    }

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackground : kBackground,
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: _sent ? _confirmation(isDark) : _form(isDark),
          ),
        ),
      ),
    );
  }

  Widget _form(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_reset_rounded,
              size: 48, color: isDark ? kPrimaryLight : kPrimaryColor),
          const SizedBox(height: 18),
          Text('Réinitialiser le mot de passe',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Nous vous enverrons un lien de réinitialisation à votre adresse '
            'professionnelle.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: isDark ? kDarkTextSecondary : kTextSecondary),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Adresse email professionnelle',
              prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Adresse requise';
              if (!value.contains('@') || !value.contains('.')) {
                return 'Adresse invalide';
              }
              return null;
            },
            onFieldSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isBusy ? null : _send,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Envoyer le lien'),
          ),
        ],
      ),
    );
  }

  Widget _confirmation(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 48, color: kSuccess),
        const SizedBox(height: 18),
        Text('Lien envoyé',
            style: GoogleFonts.outfit(
                fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
          // Formulation volontairement neutre : confirmer qu'un compte
          // existe permettrait d'énumérer les adresses valides.
          'Si un compte est associé à cette adresse, un lien de '
          'réinitialisation vient d\'y être envoyé. Pensez à vérifier vos '
          'indésirables.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: isDark ? kDarkTextSecondary : kTextSecondary),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Retour à la connexion'),
        ),
      ],
    );
  }
}
