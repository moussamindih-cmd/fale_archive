import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/subscription_state.dart';
import '../models/subscription.dart';
import '../theme/app_theme.dart';

/// Widget guard — un seul point de vérité pour les accès premium.
/// Encapsulez tout widget qui nécessite un abonnement actif.
///
/// Exemple :
/// ```dart
/// SubscriptionGuard(
///   state: subscriptionState,
///   child: ExportPdfButton(),
///   fallback: LockedFeatureBanner(message: 'Abonnez-vous pour exporter en PDF'),
/// )
/// ```
class SubscriptionGuard extends StatelessWidget {
  final SubscriptionState state;
  final Widget child;
  final Widget? fallback;

  const SubscriptionGuard({
    super.key,
    required this.state,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isActive) return child;
    return fallback ?? LockedFeatureBanner(onSubscribe: () {
      // Navigation vers l'écran d'abonnement
      Navigator.of(context).pushNamed('/subscription');
    });
  }
}

/// Bannière affichée quand une fonctionnalité est verrouillée
class LockedFeatureBanner extends StatelessWidget {
  final String? message;
  final VoidCallback? onSubscribe;

  const LockedFeatureBanner({super.key, this.message, this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kPrimaryColor.withValues(alpha: 0.08),
            const Color(0xFF818CF8).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: kPrimaryColor.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: kPrimaryColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'Fonctionnalité Premium',
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kTextPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            message ??
                'Cette fonctionnalité nécessite un abonnement actif.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 14,
                color: kTextSecondary,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          if (onSubscribe != null)
            ElevatedButton.icon(
              onPressed: onSubscribe,
              icon: const Icon(Icons.workspace_premium_rounded, size: 20),
              label: const Text('Voir les formules'),
            ),
        ],
      ),
    );
  }
}

/// Badge de statut d'abonnement (petit widget réutilisable)
class SubscriptionStatusBadge extends StatelessWidget {
  final SubscriptionStatus status;
  final int? daysRemaining;

  const SubscriptionStatusBadge({
    super.key,
    required this.status,
    this.daysRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      SubscriptionStatus.paid => (
          const Color(0xFF10B981),
          Icons.check_circle_rounded,
          daysRemaining != null && daysRemaining! <= 5
              ? 'Expire dans ${daysRemaining}j'
              : 'Actif',
        ),
      SubscriptionStatus.pending => (
          const Color(0xFFF59E0B),
          Icons.pending_rounded,
          'En attente',
        ),
      SubscriptionStatus.failed => (
          const Color(0xFFEF4444),
          Icons.cancel_rounded,
          'Échoué',
        ),
      SubscriptionStatus.expired => (
          const Color(0xFF94A3B8),
          Icons.timer_off_rounded,
          'Expiré',
        ),
      SubscriptionStatus.none => (
          const Color(0xFF94A3B8),
          Icons.remove_circle_outline_rounded,
          'Aucun',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}
