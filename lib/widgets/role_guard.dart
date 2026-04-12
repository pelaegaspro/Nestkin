import 'package:flutter/material.dart';

import '../models/role_model.dart';
import '../services/role_repository.dart';

class RoleGuard extends StatelessWidget {
  final String householdId;
  final String userId;
  final bool Function(RoleModel role) allow;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    super.key,
    required this.householdId,
    required this.userId,
    required this.allow,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RoleModel?>(
      stream: RoleRepository().roleStream(householdId: householdId, userId: userId),
      builder: (context, snapshot) {
        final role = snapshot.data;
        if (role != null && allow(role)) {
          return child;
        }

        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}
