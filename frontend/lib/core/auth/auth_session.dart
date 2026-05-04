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
  final Set<UserRole> roles;
  final Set<String> permissions;
  final Set<String> assignedUnitIds;

  bool get hasAssignedUnits => assignedUnitIds.isNotEmpty;

  bool hasRole(UserRole role) => roles.contains(role);

  bool hasAnyRole(Set<UserRole> allowedRoles) {
    for (final role in roles) {
      if (allowedRoles.contains(role)) {
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
    if (hasPermission(AppPermission.financeView)) {
      return RouteNames.finance;
    }
    if (hasPermission(AppPermission.bookingsView)) {
      return RouteNames.bookings;
    }
    if (hasPermission(AppPermission.unitsView)) {
      return RouteNames.units;
    }
    if (hasPermission(AppPermission.crmView)) {
      return RouteNames.crm;
    }
    if (hasPermission(AppPermission.usersView)) {
      return RouteNames.access;
    }
    if (hasPermission(AppPermission.maintenanceView)) {
      return RouteNames.maintenance;
    }
    if (hasPermission(AppPermission.housekeepingView)) {
      return RouteNames.housekeeping;
    }
    return RouteNames.forbidden;
  }
}

Set<String> defaultPermissionCodesForRoles(Set<UserRole> roles) {
  final permissions = <String>{};
  for (final role in roles) {
    switch (role) {
      case UserRole.superAdmin:
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
        });
        break;
      case UserRole.subAdmin:
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
        });
        break;
      case UserRole.financial:
        permissions.addAll(const {
          AppPermission.dashboardView,
          AppPermission.unitsView,
          AppPermission.bookingsView,
          AppPermission.crmView,
          AppPermission.financeView,
          AppPermission.financeManage,
          AppPermission.reportsView,
        });
        break;
      case UserRole.operations:
        permissions.addAll(const {
          AppPermission.dashboardView,
          AppPermission.unitsView,
          AppPermission.bookingsView,
          AppPermission.bookingsManage,
          AppPermission.crmView,
          AppPermission.crmManage,
          AppPermission.reportsView,
        });
        break;
      case UserRole.maintenance:
        permissions.addAll(const {
          AppPermission.maintenanceView,
          AppPermission.maintenanceManage,
        });
        break;
      case UserRole.housekeeping:
        permissions.addAll(const {
          AppPermission.housekeepingView,
          AppPermission.housekeepingComplete,
        });
        break;
    }
  }
  return permissions;
}
