import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../services/mfa_service.dart';
import 'auth/forgot_password_screen.dart';
import 'auth/two_factor_challenge_screen.dart';
import 'auth/company_register_screen.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import '../theme/glassmorphism.dart';
import '../widgets/mesh_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final appState = AppScope.of(context).appState;
    await Future.delayed(const Duration(milliseconds: 500));
    final error = await appState.login(_emailCtrl.text, _passwordCtrl.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    } else {
      // Second facteur (§5.5.3). Tant qu'il n'est pas franchi, la session
      // reste au niveau `aal1` : c'est une connexion inachevée.
      final passed = await _resolveSecondFactor();
      if (!mounted) return;
      if (!passed) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Connexion annulée.';
        });
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  /// Présente le défi TOTP si le compte en exige un.
  ///
  /// Retourne `false` si l'utilisateur abandonne : la session est alors
  /// fermée par l'écran de défi, on ne laisse pas traîner de session
  /// partiellement authentifiée.
  Future<bool> _resolveSecondFactor() async {
    try {
      if (!await MfaService.instance.requiresChallenge()) return true;
      final factors = await MfaService.instance.verifiedFactors();
      if (factors.isEmpty) return true;
      if (!mounted) return true;

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TwoFactorChallengeScreen(factor: factors.first),
          fullscreenDialog: true,
        ),
      );
      return result ?? false;
    } catch (_) {
      // Si le MFA n'est pas activé sur le projet Supabase, l'appel échoue :
      // on ne bloque pas la connexion pour autant.
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackground : kBackground,
      body: AnimatedMeshBackground(
        child: Stack(
          children: [
            // Extra Floating Ornaments
            Positioned(
              top: 50,
              left: 50,
              child:
                  GlassContainer(
                        width: 150,
                        height: 150,
                        borderRadius: 75,
                        color: Colors.white.withValues(alpha: 0.1),
                        child: const SizedBox.shrink(),
                      )
                      .animate()
                      .fade(duration: 800.ms)
                      .slideY(
                        begin: 0.1,
                        duration: 1.seconds,
                        curve: Curves.easeInOut,
                      ),
            ),
            Positioned(
              bottom: 80,
              right: 80,
              child:
                  GlassContainer(
                        width: 200,
                        height: 200,
                        borderRadius: 100,
                        color: kPrimaryColor.withValues(alpha: 0.15),
                        child: const SizedBox.shrink(),
                      )
                      .animate()
                      .fade(duration: 800.ms)
                      .slideY(
                        begin: -0.1,
                        duration: 1.seconds,
                        curve: Curves.easeInOut,
                      ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        // SaaS Logo
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF4F46E5),
                                Color(0xFF6366F1),
                                Color(0xFF06B6D4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: kPrimaryColor.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.folder_special_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ).animate().fade(duration: 400.ms).scale(delay: 100.ms),

                        const SizedBox(height: 20),
                        Text(
                          'FALE Archives',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark ? kDarkTextPrimary : kTextPrimary,
                            letterSpacing: -0.5,
                          ),
                        ).animate().fade(delay: 150.ms).slideY(begin: 0.2),
                        const SizedBox(height: 6),
                        Text(
                          'Système d\'archivage & gestion documentaire',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: isDark ? kDarkTextSecondary : kTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
                        const SizedBox(height: 32),

                        // Card form (Glassmorphism)
                        GlassContainer(
                          color: isDark
                              ? const Color(0x33000000)
                              : const Color(0x33FFFFFF),
                          borderRadius: 24,
                          blurX: 20,
                          blurY: 20,
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.all(28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Error banner
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? kDangerDarkBg.withValues(alpha: 0.3)
                                          : kDangerBg,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: kDanger.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: kDanger,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: GoogleFonts.outfit(
                                              color: isDark
                                                  ? Colors.red.shade200
                                                  : const Color(0xFFDC2626),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).animate().fade().slideY(begin: -0.1),
                                  const SizedBox(height: 20),
                                ],

                                Text(
                                  'Adresse Email',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isDark
                                        ? kDarkTextPrimary
                                        : kTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    hintText: 'nom@entreprise.com',
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                      size: 20,
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                      ? 'Email valide requis'
                                      : null,
                                ),

                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Mot de passe',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isDark
                                            ? kDarkTextPrimary
                                            : kTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 20,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                        color: isDark
                                            ? kDarkTextSecondary
                                            : kTextSecondary,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Mot de passe requis'
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
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Se connecter'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fade(delay: 300.ms).slideY(begin: 0.1),

                        const SizedBox(height: 24),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                            child: const Text('Mot de passe oublié ?'),
                          ),
                        ).animate().fade(delay: 350.ms),

                        const SizedBox(height: 8),
                        // Deux parcours distincts : une entreprise crée son
                        // espace et son administrateur ; un employé rejoint une
                        // entreprise déjà inscrite, si son adresse figure sur la
                        // liste tenue par cet administrateur.
                        Column(
                          children: [
                            Text(
                              'Pas encore de compte ?',
                              style: GoogleFonts.outfit(
                                color: isDark
                                    ? kDarkTextSecondary
                                    : kTextSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              icon: const Icon(
                                Icons.business_outlined,
                                size: 18,
                              ),
                              onPressed: () =>
                                  _push(context, const CompanyRegisterScreen()),
                              label: const Text('Inscrire mon entreprise'),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.badge_outlined, size: 18),
                              onPressed: () =>
                                  _push(context, const RegisterScreen()),
                              label: const Text('Rejoindre mon entreprise'),
                            ),
                          ],
                        ).animate().fade(delay: 400.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}
