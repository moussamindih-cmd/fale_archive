import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/signup_rules.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

/// Inscription d'un employé sur invitation de son entreprise.
///
/// Le sélecteur de poste a disparu de cet écran : le poste et le rôle sont
/// fixés par l'administrateur sur la liste d'autorisation et repris tels quels
/// à la création du compte. Les laisser au choix de l'employé revenait à le
/// laisser se déclarer RH.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _personalEmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;
  String? _errorMessage;

  /// Vrai quand le refus vient de la liste d'autorisation : le message mérite
  /// alors une mise en avant particulière, c'est la seule erreur que
  /// l'utilisateur ne peut pas corriger lui-même.
  bool _notAllowed = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _personalEmailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() {
        _errorMessage = 'Les mots de passe ne correspondent pas.';
        _notAllowed = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _notAllowed = false;
    });

    final appState = AppScope.of(context).appState;
    final result = await appState.registerEmployee(
      fullName: _nameCtrl.text,
      email: _emailCtrl.text,
      personalEmail: _personalEmailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error;
        _notAllowed = result.isNotAllowed;
      });
      return;
    }

    // Le compte naît non confirmé : il n'y a pas de session à ouvrir, et
    // pousser vers l'accueil afficherait un écran vide.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Compte créé'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text(
          'Un lien de confirmation a été envoyé à votre adresse professionnelle. '
          'Confirmez-la, puis connectez-vous.',
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
          onPressed: () => Navigator.pop(context),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      Text(
                        'Rejoindre mon entreprise',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
                      const SizedBox(height: 6),
                      Text(
                        'Votre adresse professionnelle doit avoir été enregistrée '
                        'par l\'administrateur de votre entreprise.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fade(delay: 150.ms).slideY(begin: 0.2),
                      const SizedBox(height: 28),

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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_errorMessage != null) ...[
                                _errorBanner(isDark),
                                const SizedBox(height: 20),
                              ],

                              _label('Email professionnel *', isDark),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  hintText: 'votre.nom@entreprise.com',
                                  prefixIcon: Icon(
                                    Icons.mail_outline_rounded,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) => isValidEmail(v ?? '')
                                    ? null
                                    : 'Email valide requis',
                              ),
                              const SizedBox(height: 16),

                              _label('Nom complet *', isDark),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nameCtrl,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'ex. Amadou Sow',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Nom complet requis'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              _label('Email personnel *', isDark),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _personalEmailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  hintText: 'votre.nom@gmail.com',
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) => isValidEmail(v ?? '')
                                    ? null
                                    : 'Email valide requis',
                              ),
                              const SizedBox(height: 16),

                              _label('Mot de passe *', isDark),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: _obscure1,
                                decoration: InputDecoration(
                                  hintText:
                                      'Au moins $kMinPasswordLength caractères',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure1
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: isDark
                                          ? kDarkTextSecondary
                                          : kTextSecondary,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure1 = !_obscure1),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.length < kMinPasswordLength)
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
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure2
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: isDark
                                          ? kDarkTextSecondary
                                          : kTextSecondary,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure2 = !_obscure2),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Confirmation requise'
                                    : null,
                              ),
                              const SizedBox(height: 28),

                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kPrimaryColor.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 20,
                                        ),
                                  label: Text(
                                    _isLoading
                                        ? 'Création...'
                                        : 'Créer mon compte',
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : _handleRegister,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fade(delay: 250.ms).slideY(begin: 0.1),
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

  Widget _errorBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? kDangerDarkBg.withValues(alpha: 0.3) : kDangerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDanger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _notAllowed ? Icons.gpp_bad_outlined : Icons.error_outline_rounded,
            color: kDanger,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _errorMessage!,
                  style: GoogleFonts.outfit(
                    color: isDark
                        ? Colors.red.shade200
                        : const Color(0xFFDC2626),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_notAllowed) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Si votre entreprise n'est pas encore inscrite, c'est à "
                    'elle de créer son espace en premier.',
                    style: GoogleFonts.outfit(
                      color: isDark
                          ? Colors.red.shade200.withValues(alpha: 0.85)
                          : const Color(0xFFDC2626).withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: -0.1);
  }

  Widget _label(String text, bool isDark) => Text(
    text,
    style: GoogleFonts.outfit(
      fontWeight: FontWeight.w600,
      fontSize: 13,
      color: isDark ? kDarkTextPrimary : kTextPrimary,
    ),
  );
}
