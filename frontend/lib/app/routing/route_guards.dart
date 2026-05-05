import '../../core/auth/auth_session.dart';
import '../../core/auth/permissions.dart';
import 'route_names.dart';

class RouteGuards {
  static bool canAccess(AuthSession session, String location) {
    if (location.startsWith(RouteNames.access)) {
      return session.hasAnyPermission({
        AppPermission.usersView,
        AppPermission.usersManageAccess,
      });
    }
    if (location.startsWith(RouteNames.reports)) {
      return session.hasPermission(AppPermission.reportsView);
    }
    if (location.startsWith(RouteNames.finance)) {
      return session.hasAnyPermission({
        AppPermission.financeView,
        AppPermission.financeManage,
      });
    }
    if (location.startsWith(RouteNames.dashboard)) {
      return session.hasPermission(AppPermission.dashboardView);
    }
    if (location.startsWith(RouteNames.units)) {
      return session.hasAnyPermission({
        AppPermission.unitsView,
        AppPermission.unitsManage,
      });
    }
    if (location.startsWith(RouteNames.bookings)) {
      return session.hasAnyPermission({
        AppPermission.bookingsView,
        AppPermission.bookingsManage,
      });
    }
    if (location.startsWith(RouteNames.crm)) {
      return session.hasAnyPermission({
        AppPermission.crmView,
        AppPermission.crmManage,
      });
    }
    if (location.startsWith(RouteNames.notifications)) {
      return session.hasAnyPermission({
        AppPermission.notificationsView,
        AppPermission.notificationsManage,
      });
    }
    if (location.startsWith(RouteNames.housekeeping)) {
      return session.hasAnyPermission({
        AppPermission.housekeepingView,
        AppPermission.housekeepingComplete,
        AppPermission.housekeepingManage,
      });
    }
    if (location.startsWith(RouteNames.maintenance)) {
      return session.hasAnyPermission({
        AppPermission.maintenanceView,
        AppPermission.maintenanceManage,
      });
    }

    return true;
  }
}
