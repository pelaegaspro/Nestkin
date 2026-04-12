class RoleModel {
  final String householdId;
  final String userId;
  final String role;

  const RoleModel({
    required this.householdId,
    required this.userId,
    required this.role,
  });

  bool get isAdmin => role == 'admin';
  bool get isParent => role == 'parent';
  bool get isChild => role == 'child';
  bool get canManageHousehold => isAdmin || isParent;
  bool get canAssignTasks => isAdmin || isParent;

  factory RoleModel.fromMap(Map<String, dynamic> map) {
    return RoleModel(
      householdId: map['householdId'] ?? '',
      userId: map['userId'] ?? '',
      role: map['role'] ?? 'member',
    );
  }
}
