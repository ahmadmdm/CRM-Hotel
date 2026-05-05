import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_localizations.dart';
import '../../core/auth/session_controller.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../features/access/presentation/pages/access_management_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/bookings/presentation/pages/bookings_page.dart';
import '../../features/crm/presentation/pages/crm_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/finance/presentation/pages/finance_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/operations/housekeeping/presentation/pages/housekeeping_page.dart';
import '../../features/operations/maintenance/presentation/pages/maintenance_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/units/presentation/pages/units_page.dart';
import '../shell/app_shell.dart';
import '../shell/worker_shell.dart';
import 'app_redirector.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionState = ref.watch(sessionControllerProvider);

  return GoRouter(
    initialLocation: RouteNames.splash,
    redirect: (context, state) =>
        AppRedirector.redirect(sessionState: sessionState, location: state.uri),
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const Scaffold(body: AppLoading()),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) =>
            LoginPage(redirectTo: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: RouteNames.forbidden,
        builder: (context, state) => Scaffold(
          body: Center(
            child: AppErrorView(
              title: context.l10n.forbiddenTitle,
              subtitle: context.l10n.forbiddenSubtitle,
            ),
          ),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(currentLocation: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: RouteNames.dashboard,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: RouteNames.reports,
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: RouteNames.access,
            builder: (context, state) => const AccessManagementPage(),
          ),
          GoRoute(
            path: RouteNames.units,
            builder: (context, state) => const UnitsPage(),
          ),
          GoRoute(
            path: '/app/units/:unitId',
            builder: (context, state) =>
                UnitsPage(selectedUnitId: state.pathParameters['unitId']),
          ),
          GoRoute(
            path: RouteNames.bookings,
            builder: (context, state) => const BookingsPage(),
          ),
          GoRoute(
            path: '/app/bookings/:bookingId',
            builder: (context, state) => BookingsPage(
              selectedBookingId: state.pathParameters['bookingId'],
            ),
          ),
          GoRoute(
            path: RouteNames.crm,
            builder: (context, state) => const CrmPage(),
          ),
          GoRoute(
            path: '/app/crm/:clientId',
            builder: (context, state) =>
                CrmPage(selectedClientId: state.pathParameters['clientId']),
          ),
          GoRoute(
            path: RouteNames.finance,
            builder: (context, state) => const FinancePage(),
          ),
          GoRoute(
            path: RouteNames.notifications,
            builder: (context, state) => const NotificationsPage(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) =>
            WorkerShell(currentLocation: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: RouteNames.housekeeping,
            builder: (context, state) => const HousekeepingPage(),
          ),
          GoRoute(
            path: RouteNames.maintenance,
            builder: (context, state) => const MaintenancePage(),
          ),
        ],
      ),
    ],
  );
});
