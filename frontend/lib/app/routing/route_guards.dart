import '../../core/auth/auth_session.dart';
import '../../core/auth/permissions.dart';
import 'route_names.dart';

class RouteGuards {
  static bool canAccess(AuthSession session, String location) {
    if (location.startsWith(RouteNames.access)) {
      return session.hasPermission(AppPermission.usersView);
    }
    if (location.startsWith(RouteNames.reports)) {
      return session.hasPermission(AppPermission.reportsView);
    }
    if (location.startsWith(RouteNames.finance)) {
      return session.hasPermission(AppPermission.financeView);
    }
    if (location.startsWith(RouteNames.dashboard)) {
      return session.hasPermission(AppPermission.dashboardView);
    }
    if (location.startsWith(RouteNames.units)) {
      return session.hasPermission(AppPermission.unitsView);
    }
    if (location.startsWith(RouteNames.bookings)) {
      return session.hasPermission(AppPermission.bookingsView);
    }
    if (location.startsWith(RouteNames.crm)) {
      return session.hasPermission(AppPermission.crmView);
    }
    if (location.startsWith(RouteNames.housekeeping)) {
      return session.hasPermission(AppPermission.housekeepingView);
    }
    if (location.startsWith(RouteNames.maintenance)) {
      return session.hasPermission(AppPermission.maintenanceView);
    }

    return true;
  }
}
