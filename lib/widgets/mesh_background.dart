import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import '../theme/app_theme.dart';

class AnimatedMeshBackground extends StatelessWidget {
  final Widget child;

  const AnimatedMeshBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedMeshGradient(
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E1B4B),
                    const Color(0xFF312E81),
                    const Color(0xFF0F172A),
                  ]
                : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE0E7FF),
                    const Color(0xFFF1F5F9),
                    const Color(0xFFE2E8F0),
                  ],
            options: AnimatedMeshGradientOptions(
              speed: 1.5,
              amplitude: 30,
              frequency: 5,
            ),
          ),
        ),
        // A subtle overlay to ensure contrast
        Positioned.fill(
          child: Container(
            color: isDark
                ? Colors.black.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
