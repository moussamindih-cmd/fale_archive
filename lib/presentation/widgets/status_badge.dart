import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/document.dart';
import '../../data/models/access_request.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  factory StatusBadge.fromRetention(RetentionStatus status) {
    switch (status) {
      case RetentionStatus.active:
        return const StatusBadge(label: 'Actif', color: AppColors.statusActive);
      case RetentionStatus.expiringSoon:
        return const StatusBadge(label: 'Expire bientôt', color: AppColors.statusExpiring);
      case RetentionStatus.expired:
        return const StatusBadge(label: 'Expiré', color: AppColors.statusExpired);
      case RetentionStatus.toDestroy:
        return const StatusBadge(label: 'À détruire', color: AppColors.accentCrimson);
      case RetentionStatus.destroyed:
        return const StatusBadge(label: 'Détruit', color: AppColors.statusArchived);
    }
  }

  factory StatusBadge.fromConfidentiality(ConfidentialityLevel level) {
    switch (level) {
      case ConfidentialityLevel.publicLevel:
        return const StatusBadge(label: 'Public', color: AppColors.statusActive);
      case ConfidentialityLevel.internal:
        return const StatusBadge(label: 'Interne', color: AppColors.primary);
      case ConfidentialityLevel.confidential:
        return const StatusBadge(label: 'Confidentiel', color: AppColors.accentAmber);
      case ConfidentialityLevel.strictlyConfidential:
        return const StatusBadge(label: 'Strictement Confidentiel', color: AppColors.accentCrimson);
    }
  }

  factory StatusBadge.fromRequestStatus(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return const StatusBadge(label: 'En attente', color: AppColors.statusPending);
      case RequestStatus.approved:
        return const StatusBadge(label: 'Approuvée', color: AppColors.statusActive);
      case RequestStatus.rejected:
        return const StatusBadge(label: 'Refusée', color: AppColors.statusExpired);
      case RequestStatus.expired:
        return const StatusBadge(label: 'Expirée', color: AppColors.statusArchived);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
