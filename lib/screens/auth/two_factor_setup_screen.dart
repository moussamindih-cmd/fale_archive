import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/mfa_service.dart';
import '../../theme/app_theme.dart';

/// Activation et désactivation de l'authentification à deux facteurs (§5.5.3).
class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final _codeCtrl = TextEditingController();

  List<Factor> _factors = [];
  MfaEnrollment? _enrollment;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final factors = await MfaService.instance.verifiedFactors();
      if (!mounted) return;
      setState(() {
        _factors = factors;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is MfaException ? e.message : 'Chargement impossible : $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startEnrollment() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final enrollment = await MfaService.instance.startEnrollment();
      if (!mounted) return;
      setState(() {
        _enrollment = enrollment;
        _isBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is MfaException ? e.message : 'Enrôlement impossible : $e';
        _isBusy = false;
      });
    }
  }

  Future<void> _confirm() async {
    final enrollment = _enrollment;
    if (enrollment == null) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await MfaService.instance.confirmEnrollment(
        factorId: enrollment.factorId,
        code: _codeCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _enrollment = null;
        _isBusy = false;
        _codeCtrl.clear();
      });
      await _load();
      if (!mounted) return;
      _snack('Authentification à deux facteurs activée.', null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is MfaException ? e.message : 'Vérification impossible : $e';
        _isBusy = false;
      });
    }
  }

  Future<void> _disable(Factor factor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Désactiver la double authentification ?'),
        content: const Text(
          'Votre compte ne sera plus protégé que par son mot de passe. '
          'Sur un compte disposant de droits d\'administration, c\'est un '
          'affaiblissement notable.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kDanger),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await MfaService.instance.disable(factor.id);
      if (!mounted) return;
      setState(() => _isBusy = false);
      await _load();
      if (!mounted) return;
      _snack('Double authentification désactivée.', kWarning);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is MfaException ? e.message : 'Désactivation impossible : $e';
        _isBusy = false;
      });
    }
  }

  void _snack(String message, Color? color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackground : kBackground,
      appBar: AppBar(title: const Text('Double authentification')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (_error != null) ...[
                  _banner(_error!, kDanger, Icons.error_outline_rounded),
                  const SizedBox(height: 16),
                ],
                if (_enrollment != null)
                  _enrollmentCard(_enrollment!, isDark)
                else if (_factors.isEmpty)
                  _inactiveCard(isDark)
                else
                  _activeCard(isDark),
              ],
            ),
    );
  }

  Widget _inactiveCard(bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_maybe_outlined, size: 22, color: kWarning),
              const SizedBox(width: 10),
              Text('Non activée',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Un second facteur protège votre compte même si votre mot de '
            'passe est découvert. Vous aurez besoin d\'une application '
            'd\'authentification (Google Authenticator, Authy, ou le '
            'gestionnaire de mots de passe de votre téléphone).',
            style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: isDark ? kDarkTextSecondary : kTextSecondary),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isBusy ? null : _startEnrollment,
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: const Text('Activer'),
          ),
        ],
      ),
    );
  }

  Widget _enrollmentCard(MfaEnrollment enrollment, bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1. Scannez ce code',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              // Fond blanc imposé : un QR code sur fond sombre n'est pas
              // lisible par la plupart des caméras.
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: enrollment.otpAuthUri,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Ou saisissez cette clé manuellement',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  enrollment.formattedSecret,
                  style: GoogleFonts.ibmPlexMono(
                      fontSize: 13, letterSpacing: 0.5),
                ),
              ),
              IconButton(
                tooltip: 'Copier',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: enrollment.secret));
                  _snack('Clé copiée.', null);
                },
              ),
            ],
          ),
          const Divider(height: 28),
          Text('2. Saisissez le code affiché',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            style: GoogleFonts.ibmPlexMono(fontSize: 20, letterSpacing: 6),
            decoration: const InputDecoration(
              hintText: '000000',
              counterText: '',
            ),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _isBusy ? null : _confirm,
                icon: _isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text('Vérifier et activer'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _isBusy
                    ? null
                    : () => setState(() {
                          _enrollment = null;
                          _codeCtrl.clear();
                        }),
                child: const Text('Annuler'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tant que ce code n\'est pas vérifié, rien n\'est activé : '
            'votre compte ne peut pas se retrouver verrouillé sur une '
            'application mal configurée.',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? kDarkTextMuted : kTextMuted),
          ),
        ],
      ),
    );
  }

  Widget _activeCard(bool isDark) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, size: 22, color: kSuccess),
              const SizedBox(width: 10),
              Text('Activée',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Un code sera demandé à chaque connexion, en plus du mot de passe.',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? kDarkTextSecondary : kTextSecondary),
          ),
          const SizedBox(height: 16),
          for (final factor in _factors)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.smartphone_rounded),
              title: Text(factor.friendlyName ?? 'Application d\'authentification'),
              subtitle: Text(
                'Ajoutée le '
                '${factor.createdAt.day.toString().padLeft(2, '0')}/'
                '${factor.createdAt.month.toString().padLeft(2, '0')}/'
                '${factor.createdAt.year}',
              ),
              trailing: TextButton(
                onPressed: _isBusy ? null : () => _disable(factor),
                style: TextButton.styleFrom(foregroundColor: kDanger),
                child: const Text('Désactiver'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(bool isDark, {required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? kDarkCard : kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
        ),
        child: child,
      );

  Widget _banner(String message, Color color, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: GoogleFonts.inter(fontSize: 12, height: 1.4)),
            ),
          ],
        ),
      );
}
