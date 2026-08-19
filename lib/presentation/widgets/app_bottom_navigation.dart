import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadNotifications;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadNotifications = 0,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Accueil',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.folder_copy_outlined),
          activeIcon: Icon(Icons.folder_copy),
          label: 'Archives',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.document_scanner_outlined),
          activeIcon: Icon(Icons.document_scanner),
          label: 'Scanner',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            isLabelVisible: unreadNotifications > 0,
            label: Text('$unreadNotifications'),
            child: const Icon(Icons.notifications_outlined),
          ),
          activeIcon: Badge(
            isLabelVisible: unreadNotifications > 0,
            label: Text('$unreadNotifications'),
            child: const Icon(Icons.notifications),
          ),
          label: 'Notifications',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }
}
