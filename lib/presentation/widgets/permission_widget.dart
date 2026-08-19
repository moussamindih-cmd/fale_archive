import 'package:flutter/material.dart';
import '../app_state.dart';
import '../../data/models/permission.dart';

class PermissionWidget extends StatelessWidget {
  final AppPermission permission;
  final Widget child;
  final Widget? fallback;
  final AppStateProvider state;

  const PermissionWidget({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    if (state.hasPermission(permission)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}
