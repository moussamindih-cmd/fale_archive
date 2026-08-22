import 'package:flutter/material.dart';

/// Points de rupture partagés par l'application.
///
/// `HomeScreen` bascule déjà entre barre latérale et barre basse à 800 px ;
/// ces seuils-ci (768 / 1100) servent aux mises en page internes des écrans.
class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static const double mobileBreakpoint = 768;
  static const double desktopBreakpoint = 1100;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) {
      return desktop;
    } else if (width >= mobileBreakpoint && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}
