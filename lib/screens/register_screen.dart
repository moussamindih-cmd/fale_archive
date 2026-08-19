import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../state/app_state.dart';
import '../state/candidates_state.dart';
import '../state/logistics_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';

const List<String> kJobTitles = [
  'Secrétaire',
  'Comptable',
  'Gestionnaire',
  'Conseiller Principal',
  'Conseiller Adjoint',
];

class RegisterScreen extends StatefulWidget {
  final AppState appState;
  final CandidatesState candidatesState;
  final LogisticsState logisticsState;

  const RegisterScreen({
    super.key,
    required this.appState,
    required this.candidatesState,
    required this.logisticsState,
  });

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
  String? _selectedJob;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;
  String? _errorMessage;

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
    if (_selectedJob == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner votre poste.');
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _errorMessage = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    await Future.delayed(const Duration(milliseconds: 600));
    final error = await widget.appState.register(
      fullName: _nameCtrl.text,
      email: _emailCtrl.text,
      personalEmail: _personalEmailCtrl.text,
      password: _passwordCtrl.text,
      jobTitle: _selectedJob ?? '',
    );
    if (!mounted) return;
    if (error == 'REQUIRE_CONFIRMATION') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmation requise'),
          content: const Text('Un lien de confirmation a été envoyé à votre adresse email professionnelle. Veuillez vérifier votre boîte de réception avant de vous connecter.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Fermer le dialogue
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    } else if (error != null) {
      setState(() { _isLoading = false; _errorMessage = error; });
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => HomeScreen(
            appState: widget.appState,
            candidatesState: widget.candidatesState,
            logisticsState: widget.logisticsState,
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
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
          // Ambient Glows
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      Text(
                        'Créer un compte',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
                      const SizedBox(height: 6),
                      Text(
                        'Rejoignez l\'espace documentaire d\'entreprise',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fade(delay: 150.ms).slideY(begin: 0.2),
                      const SizedBox(height: 28),

                      // Sélecteur de poste
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Poste au sein de l\'entreprise *',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isDark ? kDarkTextPrimary : kTextPrimary,
                          ),
                        ),
                      ).animate().fade(delay: 200.ms),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.start,
                        children: kJobTitles.map((job) {
                          final selected = _selectedJob == job;
                          final color = jobColor(job);
                          return GestureDetector(
                            onTap: () => setState(() => _selectedJob = job),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? color
                                    : (isDark ? kDarkCard : Colors.white),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? color
                                      : (isDark ? kDarkBorder : kBorderColor),
                                  width: selected ? 1.8 : 1,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : (isDark ? null : kSoftShadow),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    jobIcon(job),
                                    size: 16,
                                    color: selected
                                        ? Colors.white
                                        : (isDark ? kDarkTextSecondary : color),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    job,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : (isDark ? kDarkTextPrimary : kTextPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ).animate().fade(delay: 250.ms).slideY(begin: 0.1),
                      const SizedBox(height: 24),

                      // Formulaire
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
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark ? kDangerDarkBg.withValues(alpha: 0.3) : kDangerBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: kDanger.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
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
                                ).animate().fade().slideY(begin: -0.1),
                                const SizedBox(height: 20),
                              ],

                              _label('Nom complet *', isDark),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nameCtrl,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'ex. Amadou Sow',
                                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom complet requis' : null,
                              ),
                              const SizedBox(height: 16),

                              _label('Email professionnel *', isDark),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  hintText: 'votre@entreprise.com',
                                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                                ),
                                validator: (v) {
                                  if (v == null || !v.contains('@')) return 'Email valide requis';
                                  final domain = v.split('@').last.toLowerCase();
                                  const freeDomains = [
                                    'gmail.com', 'yahoo.com', 'yahoo.fr', 'hotmail.com',
                                    'hotmail.fr', 'outlook.com', 'outlook.fr', 'live.com',
                                    'live.fr', 'icloud.com', 'me.com', 'mac.com',
                                    'msn.com', 'aol.com', 'orange.fr', 'free.fr',
                                    'sfr.fr', 'bbox.fr', 'laposte.net', 'ymail.com'
                                  ];
                                  if (freeDomains.contains(domain)) {
                                    return 'Veuillez utiliser un email professionnel';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              _label('Email personnel *', isDark),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _personalEmailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  hintText: 'votre.nom@gmail.com',
                                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty || !v.contains('@')) {
                                    return 'Email valide requis';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              _label('Mot de passe *', isDark),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: _obscure1,
                                decoration: InputDecoration(
                                  hintText: 'Au moins 6 caractères',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                                    ),
                                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                                  ),
                                ),
                                validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 caractères' : null,
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
                                      _obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                                    ),
                                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Confirmation requise' : null,
                              ),
                              const SizedBox(height: 28),

                              Container(
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
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                        )
                                      : const Icon(Icons.check_circle_outline_rounded, size: 20),
                                  label: Text(_isLoading ? 'Création...' : 'Créer mon compte'),
                                  onPressed: _isLoading ? null : _handleRegister,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fade(delay: 350.ms).slideY(begin: 0.1),
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

  Widget _label(String text, bool isDark) => Text(
    text,
    style: GoogleFonts.outfit(
      fontWeight: FontWeight.w600,
      fontSize: 13,
      color: isDark ? kDarkTextPrimary : kTextPrimary,
    ),
  );
}
