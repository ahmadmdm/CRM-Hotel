import '../../app/routing/route_names.dart';
import 'permissions.dart';

enum UserRole {
  superAdmin,
  subAdmin,
  financial,
  operations,
  maintenance,
  housekeeping,
}

extension UserRoleX on UserRole {
  String get code {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.subAdmin:
        return 'sub_admin';
      case UserRole.financial:
        return 'financial';
      case UserRole.operations:
        return 'operations';
      case UserRole.maintenance:
        return 'maintenance';
      case UserRole.housekeeping:
        return 'housekeeping';
    }
  }

  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.subAdmin:
        return 'Sub-Admin';
      case UserRole.financial:
        return 'Financial';
      case UserRole.operations:
        return 'Operations';
      case UserRole.maintenance:
        return 'Maintenance';
      case UserRole.housekeeping:
        return 'Housekeeping';
    }
  }

  bool get isWorker =>
      this == UserRole.maintenance || this == UserRole.housekeeping;
}

UserRole userRoleFromCode(String code) {
  return UserRole.values.firstWhere(
    (role) => role.code == code,
    orElse: () => UserRole.operations,
  );
}

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.roles,
    required this.permissions,
    this.assignedUnitIds = const <String>{},
  });

  final String userId;
  final String displayName;
  final String email;
  final String accessToken;
  final String refreshToken;
  final Set<String> roles;
  final Set<String> permissions;
  final Set<String> assignedUnitIds;

  bool get hasAssignedUnits => assignedUnitIds.isNotEmpty;

  bool hasRole(UserRole role) => roles.contains(role.code);

  bool hasAnyRole(Set<UserRole> allowedRoles) {
    for (final role in allowedRoles) {
      if (roles.contains(role.code)) {
        return true;
      }
    }
    return false;
  }

  bool hasPermission(String permissionCode) =>
      permissions.contains(permissionCode);

  bool hasAnyPermission(Set<String> permissionCodes) {
    for (final permissionCode in permissionCodes) {
      if (permissions.contains(permissionCode)) {
        return true;
      }
    }
    return false;
  }

  String get defaultRoute {
    if (hasPermission(AppPermission.dashboardView)) {
      return RouteNames.dashboard;
    }
    if (hasPermission(AppPermission.reportsView)) {
      return RouteNames.reports;
    }
    if (hasAnyPermission({
      AppPermission.financeView,
      AppPermission.financeManage,
    })) {
      return RouteNames.finance;
    }
    if (hasAnyPermission({
      AppPermission.bookingsView,
      AppPermission.bookingsManage,
    })) {
      return RouteNames.bookings;
    }
    if (hasAnyPermission({
      AppPermission.unitsView,
      AppPermission.unitsManage,
    })) {
      return RouteNames.units;
    }
    if (hasAnyPermission({
      AppPermission.crmView,
      AppPermission.crmManage,
    })) {
      return RouteNames.crm;
    }
    if (hasAnyPermission({
      AppPermission.usersView,
      AppPermission.usersManageAccess,
    })) {
      return RouteNames.access;
    }
    if (hasAnyPermission({
      AppPermission.maintenanceView,
      AppPermission.maintenanceManage,
    })) {
      return RouteNames.maintenance;
    }
    if (hasAnyPermission({
      AppPermission.housekeepingView,
      AppPermission.housekeepingComplete,
      AppPermission.housekeepingManage,
    })) {
      return RouteNames.housekeeping;
    }
    if (hasAnyPermission({
      AppPermission.notificationsView,
      AppPermission.notificationsManage,
    })) {
      return RouteNames.notifications;
    }
    return RouteNames.forbidden;
  }
}

Set<String> defaultPermissionCodesForRoles(Iterable<String> roleCodes) {
  final permissions = <String>{};
  for (final roleCode in roleCodes) {
    switch (roleCode) {
      case 'super_admin':
        permissions.addAll(const {
          AppPermission.dashboardView,
          AppPermission.unitsView,
          AppPermission.unitsManage,
          AppPermission.bookingsView,
          AppPermission.bookingsManage,
          AppPermission.crmView,
          AppPermission.crmManage,
          AppPermission.financeView,
          AppPermission.financeManage,
          AppPermission.housekeepingView,
          AppPermission.housekeepingComplete,
          AppPermission.housekeepingManage,
          AppPermission.maintenanceView,
          AppPermission.maintenanceManage,
          AppPermission.reportsView,
          AppPermission.usersView,
          AppPermission.usersManageAccess,
          AppPermission.notificationsView,
          AppPermission.notificationsManage,
        });
        break;
      case 'sub_admin':
        permissions.addAll(const {
          AppPermission.dashboardView,
          AppPermission.unitsView,
          AppPermission.unitsManage,
          AppPermission.bookingsView,
          AppPermission.bookingsManage,
          AppPermission.crmView,
          AppPermission.crmManage,
          AppPermission.housekeepingView,
          AppPermission.housekeepingComplete,
          AppPermission.housekeepingManage,
          AppPermission.maintenanceView,
          AppPermission.maintenanceManage,
          AppPermission.reportsView,
          AppPermission.usersView,
          AppPermission.usersManageAccess,
          AppPermission.notificationsView,
          AppPermission.notificationsManage,
        });
        break;
      case 'financial':
        permissions.addAll(const {
          AppPermission.dashboardView,
          AppPermission.unitsView,
          AppPermission.bookingsView,
          AppPermission.crmView,
          AppPermission.financeView,
          AppPermission.financeManage,
          AppPermission.reportsView,
          AppPermission.notificationsView,
        });
        break;
      case 'operations':
        permissions.addAll(const {
          AppPermission.dashboardView,
          AppPermission.unitsView,
          AppPermission.bookingsView,
          AppPermission.bookingsManage,
          AppPermission.crmView,
          AppPermission.crmManage,
          AppPermission.reportsView,
          AppPermission.notificationsView,
        });
        break;
      case 'maintenance':
        permissions.addAll(const {
          AppPermission.maintenanceView,
          AppPermission.maintenanceManage,
          AppPermission.notificationsView,
        });
        break;
      case 'housekeeping':
        permissions.addAll(const {
          AppPermission.housekeepingView,
          AppPermission.housekeepingComplete,
          AppPermission.notificationsView,
        });
        break;
    }
  }
  return permissions;
}
