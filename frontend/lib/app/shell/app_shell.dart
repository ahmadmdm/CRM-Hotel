import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../localization/locale_switcher.dart';
import '../../core/auth/permissions.dart';
import '../../core/auth/session_controller.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/session_action_menu.dart';
import '../routing/route_names.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  final String currentLocation;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final isCompact = MediaQuery.sizeOf(context).width < 720;
    if (session == null) {
      return Scaffold(body: child);
    }

    final items = <AppNavigationItem>[
      if (session.hasPermission(AppPermission.dashboardView))
        AppNavigationItem(
          label: l10n.dashboardNav,
          icon: Icons.dashboard_outlined,
          route: RouteNames.dashboard,
        ),
      if (session.hasPermission(AppPermission.reportsView))
        AppNavigationItem(
          label: l10n.reportsNav,
          icon: Icons.insights_outlined,
          route: RouteNames.reports,
        ),
      if (session.hasAnyPermission({
        AppPermission.usersView,
        AppPermission.usersManageAccess,
      }))
        AppNavigationItem(
          label: l10n.accessNav,
          icon: Icons.admin_panel_settings_outlined,
          route: RouteNames.access,
        ),
      if (session.hasAnyPermission({
        AppPermission.unitsView,
        AppPermission.unitsManage,
      }))
        AppNavigationItem(
          label: l10n.unitsNav,
          icon: Icons.apartment_outlined,
          route: RouteNames.units,
        ),
      if (session.hasAnyPermission({
        AppPermission.bookingsView,
        AppPermission.bookingsManage,
      }))
        AppNavigationItem(
          label: l10n.bookingsNav,
          icon: Icons.calendar_month_outlined,
          route: RouteNames.bookings,
        ),
      if (session.hasAnyPermission({
        AppPermission.crmView,
        AppPermission.crmManage,
      }))
        AppNavigationItem(
          label: l10n.crmNav,
          icon: Icons.people_outline,
          route: RouteNames.crm,
        ),
      if (session.hasAnyPermission({
        AppPermission.financeView,
        AppPermission.financeManage,
      }))
        AppNavigationItem(
          label: l10n.financeNav,
          icon: Icons.account_balance_wallet_outlined,
          route: RouteNames.finance,
        ),
      if (session.hasAnyPermission({
        AppPermission.notificationsView,
        AppPermission.notificationsManage,
      }))
        AppNavigationItem(
          label: l10n.notificationsNav,
          icon: Icons.notifications_active_outlined,
          route: RouteNames.notifications,
        ),
    ];

    return AppScaffold(
      title: l10n.routeTitleFor(currentLocation),
      currentLocation: currentLocation,
      actions: isCompact
          ? [
              const LocaleMenuButton(compact: true),
              SessionActionMenu(
                displayName: session.displayName,
                subtitle: session.email,
                signOutLabel: l10n.signOut,
                onSignOut: () =>
                    ref.read(sessionControllerProvider.notifier).signOut(),
              ),
            ]
          : [
              const LocaleMenuButton(),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Chip(
                  avatar: const Icon(Icons.verified_user_outlined, size: 18),
                  label: Text(session.displayName),
                ),
              ),
              IconButton(
                tooltip: l10n.signOut,
                onPressed: () =>
                    ref.read(sessionControllerProvider.notifier).signOut(),
                icon: const Icon(Icons.logout),
              ),
            ],
      items: items,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OfflineBanner(key: ValueKey(session.defaultRoute)),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}
