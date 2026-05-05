import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../localization/locale_switcher.dart';
import '../../core/auth/permissions.dart';
import '../../core/auth/session_controller.dart';
import '../../core/sync/connectivity_service.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/session_action_menu.dart';
import '../routing/route_names.dart';

class WorkerShell extends ConsumerWidget {
  const WorkerShell({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  final String currentLocation;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isOnline = ref.watch(connectivityProvider);
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final isCompact = MediaQuery.sizeOf(context).width < 720;
    if (session == null) {
      return Scaffold(body: child);
    }

    final items = <AppNavigationItem>[
      if (session.hasAnyPermission({
        AppPermission.housekeepingView,
        AppPermission.housekeepingComplete,
        AppPermission.housekeepingManage,
      }))
        AppNavigationItem(
          label: l10n.housekeepingNav,
          icon: Icons.cleaning_services_outlined,
          route: RouteNames.housekeeping,
        ),
      if (session.hasAnyPermission({
        AppPermission.maintenanceView,
        AppPermission.maintenanceManage,
      }))
        AppNavigationItem(
          label: l10n.maintenanceNav,
          icon: Icons.build_outlined,
          route: RouteNames.maintenance,
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
                isOnline: isOnline,
                goOnlineLabel: l10n.goOnline,
                goOfflineLabel: l10n.goOffline,
                onToggleConnectivity: () {
                  ref.read(connectivityProvider.notifier).toggle();
                },
                onSignOut: () =>
                    ref.read(sessionControllerProvider.notifier).signOut(),
              ),
            ]
          : [
              const LocaleMenuButton(),
              IconButton(
                tooltip: isOnline ? l10n.goOffline : l10n.goOnline,
                onPressed: () {
                  ref.read(connectivityProvider.notifier).toggle();
                },
                icon: Icon(isOnline ? Icons.wifi : Icons.wifi_off),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Chip(
                  avatar: const Icon(Icons.badge_outlined, size: 18),
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
          const OfflineBanner(),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}
