import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/signup_rules.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';

/// Inscription d'une entreprise, en deux étapes.
///
/// 1. L'email de l'entreprise — son domaine devient celui du tenant.
/// 2. Le compte administrateur, obligatoire, sur ce même domaine.
///
/// Les deux étapes partent ensemble à `signup-company` : tant que
/// l'administrateur n'est pas créé, l'organisation n'a personne pour la gérer,
/// et une organisation orpheline bloquerait définitivement son domaine.
class CompanyRegisterScreen extends StatefulWidget {
  const CompanyRegisterScreen({super.key});

  @override
  State<CompanyRegisterScreen> createState() => _CompanyRegisterScreenState();
}

class _CompanyRegisterScreenState extends State<CompanyRegisterScreen> {
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  final _companyNameCtrl = TextEditingController();
  final _companyEmailCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPersonalEmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  int _step = 0;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;
  String? _errorMessage;

  String get _companyDomain => domainOf(_companyEmailCtrl.text);

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _companyEmailCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPersonalEmailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _goToStep2() {
    if (!_step1Key.currentState!.validate()) return;
    setState(() {
      _errorMessage = null;
      _step = 1;
      // Le domaine est imposé : autant l'offrir à la saisie plutôt que de
      // laisser l'utilisateur découvrir la contrainte au moment du refus.
      if (_adminEmailCtrl.text.isEmpty) {
        _adminEmailCtrl.text = '@$_companyDomain';
        _adminEmailCtrl.selection =
            const TextSelection.collapsed(offset: 0);
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_step2Key.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _errorMessage = 'Les mots de passe ne correspondent pas.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final appState = AppScope.of(context).appState;
    final result = await appState.registerCompany(
      companyName: _companyNameCtrl.text,
      companyEmail: _companyEmailCtrl.text,
      adminFullName: _adminNameCtrl.text,
      adminEmail: _adminEmailCtrl.text,
      adminPersonalEmail: _adminPersonalEmailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error;
        // Une entreprise déjà inscrite ou un domaine grand public se corrigent
        // à l'étape 1 : y renvoyer évite de faire chercher le champ fautif.
        if (result.code == 'COMPANY_ALREADY_REGISTERED' ||
            result.code == 'FREE_EMAIL_DOMAIN' ||
            result.code == 'INVALID_COMPANY_EMAIL' ||
            result.code == 'INVALID_COMPANY_NAME') {
          _step = 0;
        }
      });
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Entreprise inscrite'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
          'Un lien de confirmation a été envoyé à ${normalizeEmail(_adminEmailCtrl.text)}. '
          'Confirmez cette adresse, connectez-vous, puis enregistrez les adresses '
          'de vos employés depuis l\'onglet Équipe.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackground : kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? kDarkTextPrimary : kTextPrimary,
            size: 20,
          ),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -120,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAccentColor.withValues(alpha: isDark ? 0.08 : 0.06),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      Text(
                        'Inscrire mon entreprise',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
                      const SizedBox(height: 16),
                      _stepper(isDark),
                      const SizedBox(height: 24),

                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? kDarkCard : kSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? kDarkBorder : kBorderColor,
                            width: 1,
                          ),
                          boxShadow: isDark ? kDarkCardShadow : kCardShadow,
                        ),
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null) ...[
                              _errorBanner(isDark),
                              const SizedBox(height: 20),
                            ],
                            if (_step == 0) _step1(isDark) else _step2(isDark),
                          ],
                        ),
                      ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Étape 1 : l'entreprise ────────────────────────────────────────────

  Widget _step1(bool isDark) {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("Nom de l'entreprise *", isDark),
          const SizedBox(height: 8),
          TextFormField(
            controller: _companyNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'ex. Acme SARL',
              prefixIcon: Icon(Icons.business_outlined, size: 20),
            ),
            validator: (v) => (v == null || v.trim().length < 2)
                ? "Nom de l'entreprise requis"
                : null,
          ),
          const SizedBox(height: 16),

          _label("Email de l'entreprise *", isDark),
          const SizedBox(height: 8),
          TextFormField(
            controller: _companyEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'contact@entreprise.com',
              prefixIcon: Icon(Icons.domain_outlined, size: 20),
            ),
            validator: (v) {
              final value = v ?? '';
              if (!isValidEmail(value)) return 'Email valide requis';
              if (isFreeEmailDomain(value)) {
                return 'Adresse professionnelle requise, pas une messagerie grand public';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          _hint(
            "Le domaine de cette adresse identifiera votre entreprise. Il devra "
            "être celui du compte administrateur créé à l'étape suivante.",
            isDark,
          ),
          const SizedBox(height: 28),

          _primaryButton(
            label: 'Continuer',
            icon: Icons.arrow_forward_rounded,
            onPressed: _goToStep2,
          ),
        ],
      ),
    );
  }

  // ─── Étape 2 : le compte administrateur ────────────────────────────────

  Widget _step2(bool isDark) {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.domain_verification_outlined,
                    size: 18, color: kPrimaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_companyNameCtrl.text.trim()} · @$_companyDomain',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? kDarkTextPrimary : kTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _label('Nom complet de l\'administrateur *', isDark),
          const SizedBox(height: 8),
          TextFormField(
            controller: _adminNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'ex. Amadou Sow',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nom complet requis' : null,
          ),
          const SizedBox(height: 16),

          _label('Email professionnel *', isDark),
          const SizedBox(height: 8),
          TextFormField(
            controller: _adminEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'prenom.nom@$_companyDomain',
              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
            ),
            validator: (v) {
              final value = v ?? '';
              if (!isValidEmail(value)) return 'Email valide requis';
              if (domainOf(value) != _companyDomain) {
                return 'Doit être sur le domaine @$_companyDomain';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          _hint(
            "C'est en confirmant cette adresse que vous prouvez contrôler le "
            'domaine de votre entreprise.',
            isDark,
          ),
          const SizedBox(height: 16),

          _label('Email personnel *', isDark),
          const SizedBox(height: 8),
          TextFormField(
            controller: _adminPersonalEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'votre.nom@gmail.com',
              prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
            ),
            validator: (v) =>
                isValidEmail(v ?? '') ? null : 'Email valide requis',
          ),
          const SizedBox(height: 16),

          _label('Mot de passe *', isDark),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure1,
            decoration: InputDecoration(
              hintText: 'Au moins $kMinPasswordLength caractères',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure1
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                ),
                onPressed: () => setState(() => _obscure1 = !_obscure1),
              ),
            ),
            validator: (v) => (v == null || v.length < kMinPasswordLength)
                ? 'Minimum $kMinPasswordLength caractères'
                : null,
          ),
          const SizedBox(height: 16),

          _label('Confirmer le mot de passe *', isDark),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscure2,
            decoration: InputDecoration(
              hintText: 'Répétez le mot de passe',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure2
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                ),
                onPressed: () => setState(() => _obscure2 = !_obscure2),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Confirmation requise' : null,
          ),
          const SizedBox(height: 28),

          _primaryButton(
            label: _isLoading ? 'Création...' : "Créer l'entreprise",
            icon: Icons.check_circle_outline_rounded,
            onPressed: _isLoading ? null : _handleSubmit,
            loading: _isLoading,
          ),
        ],
      ),
    );
  }

  // ─── Fragments ─────────────────────────────────────────────────────────

  Widget _stepper(bool isDark) {
    Widget dot(int index, String label) {
      final done = _step > index;
      final active = _step == index;
      final color = (done || active)
          ? kPrimaryColor
          : (isDark ? kDarkBorder : kBorderColor);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (done || active) ? kPrimaryColor : Colors.transparent,
              border: Border.all(color: color, width: 1.6),
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check_rounded,
                      size: 15, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? Colors.white
                            : (isDark ? kDarkTextSecondary : kTextSecondary),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: (done || active)
                  ? (isDark ? kDarkTextPrimary : kTextPrimary)
                  : (isDark ? kDarkTextSecondary : kTextSecondary),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(0, 'Entreprise'),
        Container(
          width: 28,
          height: 1.6,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: _step > 0
              ? kPrimaryColor
              : (isDark ? kDarkBorder : kBorderColor),
        ),
        dot(1, 'Administrateur'),
      ],
    ).animate().fade(delay: 150.ms);
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: ElevatedButton.icon(
          icon: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white),
                )
              : Icon(icon, size: 20),
          label: Text(label),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget _errorBanner(bool isDark) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? kDangerDarkBg.withValues(alpha: 0.3) : kDangerBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kDanger.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: kDanger, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage!,
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.red.shade200 : const Color(0xFFDC2626),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ).animate().fade().slideY(begin: -0.1);

  Widget _hint(String text, bool isDark) => Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: isDark ? kDarkTextSecondary : kTextSecondary,
        ),
      );

  Widget _label(String text, bool isDark) => Text(
        text,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: isDark ? kDarkTextPrimary : kTextPrimary,
        ),
      );
}
