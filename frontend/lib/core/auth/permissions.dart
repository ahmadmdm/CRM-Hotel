abstract final class AppPermission {
  static const dashboardView = 'dashboard.view';
  static const unitsView = 'units.view';
  static const unitsManage = 'units.manage';
  static const bookingsView = 'bookings.view';
  static const bookingsManage = 'bookings.manage';
  static const crmView = 'crm.view';
  static const crmManage = 'crm.manage';
  static const financeView = 'finance.view';
  static const financeManage = 'finance.manage';
  static const housekeepingView = 'housekeeping.view';
  static const housekeepingComplete = 'housekeeping.complete';
  static const housekeepingManage = 'housekeeping.manage';
  static const maintenanceView = 'maintenance.view';
  static const maintenanceManage = 'maintenance.manage';
  static const reportsView = 'reports.view';
  static const usersView = 'users.view';
  static const usersManageAccess = 'users.manage_access';
}

const subAdminAssignableRoleCodes = <String>{
  'financial',
  'operations',
  'maintenance',
  'housekeeping',
};

const subAdminManageablePermissionCodes = <String>{
  AppPermission.dashboardView,
  AppPermission.unitsView,
  AppPermission.bookingsView,
  AppPermission.bookingsManage,
  AppPermission.crmView,
  AppPermission.crmManage,
  AppPermission.financeView,
  AppPermission.financeManage,
  AppPermission.reportsView,
  AppPermission.housekeepingView,
  AppPermission.housekeepingComplete,
  AppPermission.housekeepingManage,
  AppPermission.maintenanceView,
  AppPermission.maintenanceManage,
};
