import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/mfa_service.dart';
import '../../theme/app_theme.dart';

/// Second facteur exigé à la connexion (§5.5.3).
///
/// Tant que ce code n'est pas validé, la session reste au niveau `aal1` :
/// c'est une connexion inachevée, pas un accès diminué.
class TwoFactorChallengeScreen extends StatefulWidget {
  final Factor factor;

  const TwoFactorChallengeScreen({super.key, required this.factor});

  @override
  State<TwoFactorChallengeScreen> createState() =>
      _TwoFactorChallengeScreenState();
}

class _TwoFactorChallengeScreenState extends State<TwoFactorChallengeScreen> {
  final _codeCtrl = TextEditingController();
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeCtrl.text.trim().length < 6) {
      setState(() => _error = 'Le code comporte six chiffres.');
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await MfaService.instance.verifyChallenge(
        factorId: widget.factor.id,
        code: _codeCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is MfaException ? e.message : 'Vérification impossible : $e';
        _isBusy = false;
        _codeCtrl.clear();
      });
    }
  }

  /// Abandonner le second facteur revient à ne pas être connecté : on ferme
  /// la session plutôt que de laisser une session `aal1` traîner.
  Future<void> _cancel() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: isDark ? kDarkBackground : kBackground,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.verified_user_rounded,
                      size: 48, color: isDark ? kPrimaryLight : kPrimaryColor),
                  const SizedBox(height: 18),
                  Text(
                    'Vérification en deux étapes',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Saisissez le code affiché par votre application '
                    'd\'authentification.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark ? kDarkTextSecondary : kTextSecondary),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexMono(
                        fontSize: 26, letterSpacing: 10),
                    decoration: const InputDecoration(
                      hintText: '000000',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _verify(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 12, height: 1.4, color: kDanger),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isBusy ? null : _verify,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Vérifier'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isBusy ? null : _cancel,
                    child: const Text('Annuler la connexion'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
