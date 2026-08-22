import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../state/subscription_state.dart';
import '../../models/subscription.dart';
import '../../theme/app_theme.dart';
import '../../widgets/subscription_guard.dart';
import 'plan_selection_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  final SubscriptionState subscriptionState;
  final String organizationId;

  const SubscriptionScreen({
    super.key,
    required this.subscriptionState,
    required this.organizationId,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.subscriptionState.history.isEmpty) {
      widget.subscriptionState.load(widget.organizationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: widget.subscriptionState,
      builder: (context, _) {
        final sub = widget.subscriptionState;
        return Scaffold(
          backgroundColor: isDark ? kDarkBackground : kBackground,
          appBar: AppBar(
            title: Text(
              'Abonnement & Facturation',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? kDarkTextPrimary : kTextPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                ),
                tooltip: 'Actualiser',
                onPressed: () =>
                    widget.subscriptionState.refresh(widget.organizationId),
              ),
            ],
          ),
          body: sub.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () =>
                      widget.subscriptionState.refresh(widget.organizationId),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusCard(sub, isDark),
                        const SizedBox(height: 20),
                        _buildActionButton(sub, isDark),
                        const SizedBox(height: 32),
                        _buildHistorySection(sub, isDark),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  // ─── Carte de statut principal ────────────────────────────────────────────
  Widget _buildStatusCard(SubscriptionState sub, bool isDark) {
    final active = sub.activeTransaction;
    final status = sub.info.status;

    final (gradientColors, iconBg) = switch (status) {
      SubscriptionStatus.paid =>
        active?.isInGracePeriod == true
            ? (
                [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                Colors.white.withValues(alpha: 0.2),
              )
            : (
                [const Color(0xFF059669), const Color(0xFF10B981)],
                Colors.white.withValues(alpha: 0.2),
              ),
      SubscriptionStatus.pending => (
        [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        Colors.white.withValues(alpha: 0.2),
      ),
      _ => (
        [const Color(0xFF475569), const Color(0xFF334155)],
        Colors.white.withValues(alpha: 0.2),
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status == SubscriptionStatus.paid
                      ? Icons.workspace_premium_rounded
                      : Icons.no_accounts_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active?.planName ?? 'Forfait Inactif',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SubscriptionStatusBadge(
                      status: status,
                      daysRemaining: active?.daysRemaining,
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (active != null && status == SubscriptionStatus.paid) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _infoRow(
                    Icons.calendar_today_rounded,
                    'Expire le',
                    active.expiresAt != null
                        ? DateFormat(
                            'dd MMMM yyyy',
                            'fr_FR',
                          ).format(active.expiresAt!)
                        : '—',
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    Icons.timer_rounded,
                    'Jours restants',
                    '${active.daysRemaining} jour(s)',
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    Icons.phone_android_rounded,
                    'Opérateur',
                    active.operator.label,
                  ),
                ],
              ),
            ),
            if (active.isInGracePeriod) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Période de grâce active. Veuillez renouveler afin de conserver l\'accès complet.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF92400E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    ).animate().fade(duration: 350.ms).slideY(begin: 0.1);
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 8),
        Text(
          '$label : ',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Bouton d'action principal ────────────────────────────────────────────
  Widget _buildActionButton(SubscriptionState sub, bool isDark) {
    final isActive = sub.isActive;
    final label = isActive
        ? 'Gérer ou Renouveler l\'abonnement'
        : 'Souscrire à un forfait';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: Icon(
          isActive ? Icons.autorenew_rounded : Icons.workspace_premium_rounded,
          size: 20,
        ),
        label: Text(label),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlanSelectionScreen(
                subscriptionState: sub,
                organizationId: widget.organizationId,
              ),
            ),
          );
          if (mounted) {
            sub.refresh(widget.organizationId);
          }
        },
      ),
    ).animate().fade(delay: 150.ms);
  }

  // ─── Historique des transactions ──────────────────────────────────────────
  Widget _buildHistorySection(SubscriptionState sub, bool isDark) {
    if (sub.history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 44,
                color: isDark ? kDarkTextMuted : kTextMuted,
              ),
              const SizedBox(height: 10),
              Text(
                'Aucune transaction enregistrée',
                style: GoogleFonts.outfit(
                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historique des Factures & Paiements',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? kDarkTextPrimary : kTextPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sub.history.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _TransactionCard(
            tx: sub.history[i],
            isDark: isDark,
          ).animate().fade(delay: Duration(milliseconds: 60 * i)),
        ),
      ],
    );
  }
}

// ─── Carte d'une transaction ─────────────────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  final SubscriptionTransaction tx;
  final bool isDark;

  const _TransactionCard({required this.tx, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (tx.status) {
      SubscriptionStatus.paid => const Color(0xFF10B981),
      SubscriptionStatus.pending => const Color(0xFFF59E0B),
      SubscriptionStatus.failed => const Color(0xFFEF4444),
      _ => isDark ? kDarkTextMuted : const Color(0xFF94A3B8),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? kDarkBorder : kBorderColor),
        boxShadow: isDark ? null : kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tx.operator == PaymentOperator.moov
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.phone_android_rounded,
                  color: tx.operator == PaymentOperator.moov
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.planName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? kDarkTextPrimary : kTextPrimary,
                      ),
                    ),
                    Text(
                      tx.operator.label,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${tx.amount.toStringAsFixed(0)} ${tx.currency}',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? kDarkTextPrimary : kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SubscriptionStatusBadge(status: tx.status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? kDarkBorder : kBorderColor),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 13,
                color: isDark ? kDarkTextMuted : kTextMuted,
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(tx.createdAt),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: isDark ? kDarkTextMuted : kTextMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (tx.transactionReference != null) ...[
                const Spacer(),
                Flexible(
                  child: Text(
                    'Réf: ${tx.transactionReference}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: isDark ? kDarkTextMuted : kTextMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (tx.expiresAt != null && tx.status == SubscriptionStatus.paid) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.event_rounded, size: 13, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  'Expire le ${DateFormat('dd MMMM yyyy', 'fr_FR').format(tx.expiresAt!)}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
