import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/in_app_notification.dart';
import '../models/user_role.dart';
import '../state/notifications_state.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  final NotificationsState notificationsState;
  final AppState appState;

  const NotificationsScreen({
    super.key,
    required this.notificationsState,
    required this.appState,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _onlyUnread = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = widget.appState.currentEmployee;
    final role = user?.role ?? UserRole.employe;
    final userId = user?.id ?? '';

    final notifs = widget.notificationsState.forUser(userId: userId, role: role);
    final displayed = _onlyUnread ? notifs.where((n) => !n.isRead).toList() : notifs;
    final unreadCount = widget.notificationsState.unreadCount(userId: userId, role: role);

    return Scaffold(
      backgroundColor: isDark ? kDarkBackground : kBackground,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? kDarkTextPrimary : kTextPrimary,
          ),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              icon: const Icon(Icons.done_all_rounded, size: 16),
              label: const Text('Tout marquer lu'),
              onPressed: () {
                widget.notificationsState.markAllAsRead(userId: userId, role: role);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Toutes les notifications sont marquées comme lues.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          IconButton(
            icon: Icon(
              Icons.delete_sweep_outlined,
              color: isDark ? kDarkTextSecondary : kTextSecondary,
              size: 22,
            ),
            tooltip: 'Effacer l\'historique',
            onPressed: notifs.isEmpty
                ? null
                : () {
                    widget.notificationsState.clearAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Historique des notifications effacé.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                _filterPill(
                  label: 'Toutes (${notifs.length})',
                  selected: !_onlyUnread,
                  onTap: () => setState(() => _onlyUnread = false),
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _filterPill(
                  label: 'Non lues ($unreadCount)',
                  selected: _onlyUnread,
                  onTap: () => setState(() => _onlyUnread = true),
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child: displayed.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 48,
                            color: isDark ? kDarkTextMuted : kTextMuted,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _onlyUnread ? 'Aucune notification non lue' : 'Aucune notification reçue',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? kDarkTextPrimary : kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Les alertes importantes et rappels apparaîtront ici.',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: isDark ? kDarkTextSecondary : kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: displayed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notif = displayed[index];
                      return _buildNotificationCard(notif, userId, role, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final accent = isDark ? kPrimaryLight : kPrimaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : (isDark ? kDarkCard : kSurface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? accent : (isDark ? kDarkBorder : kBorderColor)),
          boxShadow: selected
              ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))]
              : (isDark ? null : kSoftShadow),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : (isDark ? kDarkTextPrimary : kTextPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(InAppNotification notif, String userId, UserRole role, bool isDark) {
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: kDanger,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      onDismissed: (_) => widget.notificationsState.removeNotification(notif.id),
      child: Container(
        decoration: BoxDecoration(
          color: notif.isRead
              ? (isDark ? kDarkCard : kSurface)
              : (isDark ? const Color(0xFF1E2A4A) : const Color(0xFFEFF6FF)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notif.isRead
                ? (isDark ? kDarkBorder : kBorderColor)
                : kPrimaryLight.withValues(alpha: 0.5),
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: isDark ? null : kSoftShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => widget.notificationsState.markAsRead(notif.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: notif.type.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(notif.type.icon, color: notif.type.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                notif.title,
                                style: GoogleFonts.outfit(
                                  fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                                  fontSize: 14,
                                  color: isDark ? kDarkTextPrimary : kTextPrimary,
                                ),
                              ),
                            ),
                            Text(
                              _formatTime(notif.timestamp),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: isDark ? kDarkTextMuted : kTextMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notif.message,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: isDark ? kDarkTextSecondary : kTextSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: notif.type.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                notif.type.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: notif.type.color,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (!notif.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: kPrimaryLight,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: kPrimaryLight.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    )
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours} h';
    } else {
      return DateFormat('dd/MM HH:mm').format(time);
    }
  }
}
