import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/theme/app_colors.dart';
import 'ambient_background.dart';

class AppNavigationItem {
  const AppNavigationItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.currentLocation,
    required this.items,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final String currentLocation;
  final List<AppNavigationItem> items;
  final List<Widget> actions;
  final Widget child;

  int _currentIndexFor(List<AppNavigationItem> navigationItems) {
    final index = navigationItems.indexWhere(
      (item) => currentLocation.startsWith(item.route),
    );
    return index < 0 ? 0 : index;
  }

  List<AppNavigationItem> get _mobileItems => items.take(4).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;

    if (items.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(title), actions: actions),
        body: AmbientBackground(child: SafeArea(child: child)),
      );
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AmbientBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 290,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFDF9F2), Color(0xFFF1E5D7)],
                      ),
                      border: Border.all(color: AppColors.mist),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [AppColors.midnight, AppColors.sky],
                            ),
                          ),
                          child: const Icon(
                            Icons.hotel_class,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'CrmHotel',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.shellSidebarIntro,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.slate),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.76),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 18,
                                color: AppColors.clay,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.shellCommandDeck,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final selected = currentLocation.startsWith(
                                item.route,
                              );
                              return InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => context.go(item.route),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: selected
                                        ? const LinearGradient(
                                            colors: [
                                              AppColors.midnight,
                                              AppColors.sky,
                                            ],
                                          )
                                        : null,
                                    color: selected
                                        ? null
                                        : Colors.white.withValues(alpha: 0.62),
                                    border: Border.all(
                                      color: selected
                                          ? Colors.transparent
                                          : AppColors.mist,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        item.icon,
                                        color: selected
                                            ? Colors.white
                                            : AppColors.ink,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: selected
                                                    ? Colors.white
                                                    : AppColors.ink,
                                              ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_outward,
                                        size: 18,
                                        color: selected
                                            ? Colors.white
                                            : AppColors.slate,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppColors.mist),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.shellWorkspaceIntro,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppColors.slate),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              ...actions,
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: AppColors.mist),
                            ),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final mobileItems = _mobileItems;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.midnight, AppColors.sky],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.hotel_class, color: Colors.white, size: 28),
                  const SizedBox(height: 16),
                  Text(
                    'CrmHotel',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  selected: currentLocation.startsWith(item.route),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(item.route);
                  },
                ),
              ),
          ],
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: mobileItems.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: NavigationBar(
                  selectedIndex: _currentIndexFor(mobileItems),
                  onDestinationSelected: (index) =>
                      context.go(mobileItems[index].route),
                  destinations: [
                    for (final item in mobileItems)
                      NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.label,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
