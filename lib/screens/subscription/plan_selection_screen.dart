import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../state/subscription_state.dart';
import '../../models/subscription.dart';
import '../../theme/app_theme.dart';
import '../../widgets/centered_form_body.dart';
import '../../widgets/glass_form_card.dart';
import '../../widgets/mesh_background.dart';

/// Écran de choix de formule et d'opérateur de paiement.
class PlanSelectionScreen extends StatefulWidget {
  final SubscriptionState subscriptionState;
  final String organizationId;

  const PlanSelectionScreen({
    super.key,
    required this.subscriptionState,
    required this.organizationId,
  });

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  String? _selectedPlanId;
  PaymentOperator? _selectedOperator;
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.subscriptionState.plans.isEmpty) {
      widget.subscriptionState.load(widget.organizationId);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePay() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlanId == null) {
      _showSnack('Veuillez sélectionner une formule.');
      return;
    }
    if (_selectedOperator == null) {
      _showSnack('Veuillez choisir un opérateur.');
      return;
    }

    final error = await widget.subscriptionState.initiatePayment(
      organizationId: widget.organizationId,
      planId: _selectedPlanId!,
      operator: _selectedOperator!,
      phoneNumber: _phoneCtrl.text.trim(),
    );

    if (!mounted) return;
    if (error != null) {
      _showSnack(error, isError: true);
    }
    // Si succès → naviguer vers l'écran de confirmation/attente
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFEF4444) : kPrimaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.subscriptionState,
      builder: (context, _) {
        final sub = widget.subscriptionState;
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Choisir une formule'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: AnimatedMeshBackground(
            child: SafeArea(
              child: sub.isPaying
                  ? _buildPayingState(sub)
                  : sub.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildSelectionContent(sub),
            ),
          ),
        );
      },
    );
  }

  // ─── État "paiement en cours" ─────────────────────────────────────────────

  Widget _buildPayingState(SubscriptionState sub) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = sub.pollStatus;
    final (icon, color, title, subtitle) = switch (status) {
      SubscriptionStatus.paid => (
        Icons.check_circle_rounded,
        const Color(0xFF10B981),
        'Paiement confirmé !',
        'Votre abonnement est maintenant actif.',
      ),
      SubscriptionStatus.failed => (
        Icons.cancel_rounded,
        const Color(0xFFEF4444),
        'Paiement échoué',
        'La transaction n\'a pas pu être complétée. Veuillez réessayer.',
      ),
      _ => (
        Icons.pending_rounded,
        const Color(0xFFF59E0B),
        'Paiement en cours...',
        'Validez la demande sur votre téléphone via ${_selectedOperator?.label ?? 'votre opérateur'}.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status == SubscriptionStatus.pending)
              CircularProgressIndicator(color: color)
            else
              Icon(icon, size: 80, color: color),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: isDark ? kDarkTextSecondary : kTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (status == SubscriptionStatus.pending) ...[
              const SizedBox(height: 40),
              Text(
                'Vérification automatique toutes les 8 secondes',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
            if (status == SubscriptionStatus.paid ||
                status == SubscriptionStatus.failed) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ],
        ).animate().fade(duration: 300.ms),
      ),
    );
  }

  // ─── Sélection de la formule ──────────────────────────────────────────────

  Widget _buildSelectionContent(SubscriptionState sub) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CenteredFormBody(
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(inputDecorationTheme: glassInputDecorationTheme(isDark)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Formules disponibles',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ).animate().fade(duration: 300.ms),
              const SizedBox(height: 16),

              // Liste des plans
              ...sub.plans.asMap().entries.map((entry) {
                final plan = entry.value;
                final idx = entry.key;
                return _PlanCard(
                  plan: plan,
                  isSelected: _selectedPlanId == plan.id,
                  onTap: () => setState(() => _selectedPlanId = plan.id),
                ).animate().fade(delay: Duration(milliseconds: 100 * idx));
              }),

              const SizedBox(height: 32),

              Text(
                'Opérateur de paiement',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ).animate().fade(delay: 300.ms),
              const SizedBox(height: 16),

              Row(
                children: PaymentOperator.values.map((op) {
                  final selected = _selectedOperator == op;
                  final opColor = op == PaymentOperator.moov
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedOperator = op),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: EdgeInsets.only(
                          right: op == PaymentOperator.moov ? 8 : 0,
                        ),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: selected
                              ? opColor.withValues(alpha: 0.1)
                              : Colors.white.withValues(
                                  alpha: isDark ? 0.06 : 0.5,
                                ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? opColor
                                : Colors.white.withValues(
                                    alpha: isDark ? 0.1 : 0.7,
                                  ),
                            width: selected ? 2 : 1.5,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: opColor.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : kSoftShadow,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.phone_android_rounded,
                              size: 36,
                              color: opColor,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              op.label,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: selected
                                    ? opColor
                                    : (isDark
                                          ? kDarkTextPrimary
                                          : kTextPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ).animate().fade(delay: 400.ms),

              const SizedBox(height: 28),

              Text(
                'Votre numéro de téléphone',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
              ).animate().fade(delay: 450.ms),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '6XXXXXXXX',
                  prefixIcon: Icon(Icons.phone_android_rounded, size: 22),
                  prefixText: '+235 ',
                ),
                validator: (v) {
                  if (v == null || v.length < 8) {
                    return 'Numéro invalide (minimum 8 chiffres)';
                  }
                  return null;
                },
              ).animate().fade(delay: 500.ms),

              const SizedBox(height: 32),

              // Bouton payer
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_rounded, size: 20),
                  label: const Text('Procéder au paiement sécurisé'),
                  onPressed: sub.isPaying ? null : _handlePay,
                ),
              ).animate().fade(delay: 600.ms),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shield_rounded,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Paiement sécurisé via CinetPay — vos données ne quittent jamais votre téléphone',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Carte de formule ─────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planColor = switch (plan.name.toLowerCase()) {
      'starter' => const Color(0xFF10B981),
      'pro' => kPrimaryColor,
      'entreprise' => const Color(0xFFF59E0B),
      _ => kPrimaryColor,
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? planColor.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: isDark ? 0.06 : 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? planColor
                : Colors.white.withValues(alpha: isDark ? 0.1 : 0.7),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: planColor.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : kSoftShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? planColor
                          : (isDark ? kDarkTextPrimary : kTextPrimary),
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: planColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                plan.description,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${plan.amount.toStringAsFixed(0)} ${plan.currency}',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: planColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '/ ${plan.durationDays} jours',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: kTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: plan.features.map((f) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: planColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 12, color: planColor),
                      const SizedBox(width: 4),
                      Text(
                        SubscriptionPlan.featureLabel(f),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: planColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
