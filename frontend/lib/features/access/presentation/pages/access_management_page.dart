import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/permissions.dart';
import '../../../../core/auth/session_controller.dart';
import '../../../../core/network/backend_api_service.dart';
import '../../../../core/widgets/app_error_view.dart';

final accessUsersProvider = FutureProvider<List<AccessUserSummary>>((
  ref,
) async {
  return ref.read(backendApiProvider).fetchAccessUsers();
});

final permissionCatalogProvider = FutureProvider<List<AccessPermissionEntry>>((
  ref,
) async {
  return ref.read(backendApiProvider).fetchPermissionCatalog();
});

final assignableUnitsProvider = FutureProvider<List<UnitSummary>>((ref) async {
  return ref.read(backendApiProvider).fetchUnits(pageSize: 200);
});

final userAccessProvider = FutureProvider.autoDispose
    .family<AccessUserDetail, String>((ref, userId) async {
      return ref.read(backendApiProvider).fetchUserAccess(userId);
    });

final operationTeamsProvider = FutureProvider<List<OperationTeamSummary>>((
  ref,
) async {
  return ref.read(backendApiProvider).fetchOperationTeams();
});

enum PermissionOverrideMode { inherit, allow, deny }

class AccessManagementPage extends ConsumerStatefulWidget {
  const AccessManagementPage({super.key});

  @override
  ConsumerState<AccessManagementPage> createState() =>
      _AccessManagementPageState();
}

class _AccessManagementPageState extends ConsumerState<AccessManagementPage> {
  String? _selectedUserId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final usersAsync = ref.watch(accessUsersProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          title: l10n.isArabic
              ? 'تعذر تحميل المستخدمين'
              : 'Unable to load users',
          subtitle: '$error',
          onRetry: () => ref.invalidate(accessUsersProvider),
        ),
      ),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Text(
              l10n.isArabic
                  ? 'لا يوجد مستخدمون لإدارة الصلاحيات.'
                  : 'There are no users available for access management.',
            ),
          );
        }

        final selectedUserId = _resolveSelectedUserId(users);
        final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
        final auditUserCount = users
            .where((user) => user.email.startsWith('perm-'))
            .length;
        final adminCount = users
            .where(
              (user) => user.roleCodes.any(
                (roleCode) =>
                    roleCode == UserRole.superAdmin.code ||
                    roleCode == UserRole.subAdmin.code,
              ),
            )
            .length;
        final hero = _AccessHero(
          totalUsers: users.length,
          adminUsers: adminCount,
          permissionAuditUsers: auditUserCount,
        );

        if (isDesktop) {
          return Column(
            children: [
              hero,
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 340,
                      child: _UserDirectory(
                        users: users,
                        selectedUserId: selectedUserId,
                        onSelected: _selectUser,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _AccessDetailHost(
                        userId: selectedUserId,
                        users: users,
                        scrollable: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView(
          children: [
            hero,
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: _UserDirectory(
                users: users,
                selectedUserId: selectedUserId,
                onSelected: _selectUser,
                scrollDirection: Axis.horizontal,
              ),
            ),
            const SizedBox(height: 16),
            _AccessDetailHost(
              userId: selectedUserId,
              users: users,
              scrollable: false,
            ),
          ],
        );
      },
    );
  }

  String _resolveSelectedUserId(List<AccessUserSummary> users) {
    final currentSelection = _selectedUserId;
    if (currentSelection != null &&
        users.any((user) => user.id == currentSelection)) {
      return currentSelection;
    }

    final fallbackUserId = users.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedUserId == fallbackUserId) {
        return;
      }
      setState(() {
        _selectedUserId = fallbackUserId;
      });
    });
    return fallbackUserId;
  }

  void _selectUser(String userId) {
    if (_selectedUserId == userId) {
      return;
    }
    setState(() {
      _selectedUserId = userId;
    });
  }
}

class _AccessHero extends StatelessWidget {
  const _AccessHero({
    required this.totalUsers,
    required this.adminUsers,
    required this.permissionAuditUsers,
  });

  final int totalUsers;
  final int adminUsers;
  final int permissionAuditUsers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.midnight, Color(0xFF28406E), AppColors.sky],
        ),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.isArabic ? 'استوديو التحكم بالوصول' : 'Access Control Studio',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.isArabic
                      ? 'راقب الأدوار، راجع الصلاحيات الفعلية، واختبر حسابات التدقيق أحادية الصلاحية من نفس المساحة.'
                      : 'Inspect roles, review effective permissions, and exercise single-permission audit accounts from one surface.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          _AccessHeroStat(
            label: l10n.isArabic ? 'إجمالي المستخدمين' : 'Total users',
            value: l10n.formatNumber(totalUsers),
          ),
          _AccessHeroStat(
            label: l10n.isArabic ? 'حسابات الإدارة' : 'Admin accounts',
            value: l10n.formatNumber(adminUsers),
          ),
          _AccessHeroStat(
            label: l10n.isArabic ? 'حسابات التدقيق' : 'Audit users',
            value: l10n.formatNumber(permissionAuditUsers),
          ),
        ],
      ),
    );
  }
}

class _AccessHeroStat extends StatelessWidget {
  const _AccessHeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserDirectory extends StatelessWidget {
  const _UserDirectory({
    required this.users,
    required this.selectedUserId,
    required this.onSelected,
    this.scrollDirection = Axis.vertical,
  });

  final List<AccessUserSummary> users;
  final String selectedUserId;
  final ValueChanged<String> onSelected;
  final Axis scrollDirection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isHorizontal = scrollDirection == Axis.horizontal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.isArabic ? 'المستخدمون' : 'Users',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.isArabic
                  ? 'اختر مستخدماً لمراجعة الأدوار والصلاحيات الفعلية الخاصة به.'
                  : 'Choose a user to inspect assigned roles and effective permissions.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                scrollDirection: scrollDirection,
                itemCount: users.length,
                separatorBuilder: (context, index) => SizedBox(
                  width: isHorizontal ? 12 : 0,
                  height: isHorizontal ? 0 : 12,
                ),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final selected = user.id == selectedUserId;
                  return SizedBox(
                    width: isHorizontal ? 280 : null,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onSelected(user.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              user.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final roleCode in user.roleCodes)
                                  Chip(
                                    label: Text(l10n.roleLabel(roleCode)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessDetailHost extends ConsumerWidget {
  const _AccessDetailHost({
    required this.userId,
    required this.users,
    required this.scrollable,
  });

  final String userId;
  final List<AccessUserSummary> users;
  final bool scrollable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(permissionCatalogProvider);
    final unitsAsync = ref.watch(assignableUnitsProvider);
    final detailAsync = ref.watch(userAccessProvider(userId));
    final teamsAsync = ref.watch(operationTeamsProvider);
    final actor = ref.watch(sessionControllerProvider).valueOrNull;

    if (actor == null) {
      return const SizedBox.shrink();
    }

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          title: context.l10n.isArabic
              ? 'تعذر تحميل كتالوج الصلاحيات'
              : 'Unable to load the permission catalog',
          subtitle: '$error',
          onRetry: () => ref.invalidate(permissionCatalogProvider),
        ),
      ),
      data: (catalog) => unitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppErrorView(
            title: context.l10n.isArabic
                ? 'تعذر تحميل قائمة الوحدات'
                : 'Unable to load units',
            subtitle: '$error',
            onRetry: () => ref.invalidate(assignableUnitsProvider),
          ),
        ),
        data: (assignableUnits) => detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: AppErrorView(
              title: context.l10n.isArabic
                  ? 'تعذر تحميل تفاصيل المستخدم'
                  : 'Unable to load user details',
              subtitle: '$error',
              onRetry: () => ref.invalidate(userAccessProvider(userId)),
            ),
          ),
          data: (access) => teamsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: AppErrorView(
                title: context.l10n.isArabic
                    ? 'تعذر تحميل الفرق التشغيلية'
                    : 'Unable to load operation teams',
                subtitle: '$error',
                onRetry: () => ref.invalidate(operationTeamsProvider),
              ),
            ),
            data: (teams) {
              final content = <Widget>[
                _UserAccessEditor(
                  key: ValueKey(userId),
                  access: access,
                  catalog: catalog,
                  assignableUnits: assignableUnits,
                  actor: actor,
                  scrollable: false,
                ),
                _OperationTeamsStudio(
                  teams: teams,
                  users: users,
                  assignableUnits: assignableUnits,
                  actor: actor,
                ),
              ];

              if (scrollable) {
                return ListView.separated(
                  itemCount: content.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => content[index],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < content.length; index++) ...[
                    content[index],
                    if (index < content.length - 1) const SizedBox(height: 16),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UserAccessEditor extends ConsumerStatefulWidget {
  const _UserAccessEditor({
    super.key,
    required this.access,
    required this.catalog,
    required this.assignableUnits,
    required this.actor,
    required this.scrollable,
  });

  final AccessUserDetail access;
  final List<AccessPermissionEntry> catalog;
  final List<UnitSummary> assignableUnits;
  final AuthSession actor;
  final bool scrollable;

  @override
  ConsumerState<_UserAccessEditor> createState() => _UserAccessEditorState();
}

class _UserAccessEditorState extends ConsumerState<_UserAccessEditor> {
  late Set<String> _selectedRoleCodes;
  late Set<String> _selectedUnitIds;
  late Map<String, PermissionOverrideMode> _overrideModes;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _hydrateFromAccess(widget.access);
  }

  @override
  void didUpdateWidget(covariant _UserAccessEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_accessSignature(oldWidget.access) != _accessSignature(widget.access)) {
      _hydrateFromAccess(widget.access);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final previewInheritedPermissions = _previewInheritedPermissions();
    final previewEffectivePermissions = _previewEffectivePermissions(
      previewInheritedPermissions,
    );
    final groupedPermissions = <String, List<AccessPermissionEntry>>{};
    for (final permission in widget.catalog) {
      groupedPermissions
          .putIfAbsent(permission.module, () => [])
          .add(permission);
    }
    final modules = groupedPermissions.keys.toList()..sort();
    final sortedUnits = [...widget.assignableUnits]
      ..sort((left, right) => left.code.compareTo(right.code));
    final selectedUnits = sortedUnits
        .where((unit) => _selectedUnitIds.contains(unit.id))
        .toList();
    final canManage = widget.actor.hasPermission(
      AppPermission.usersManageAccess,
    );
    final isSuperAdmin = widget.actor.hasRole(UserRole.superAdmin);
    final isRestrictedSubAdminTarget =
        !isSuperAdmin &&
        (widget.actor.userId == widget.access.id ||
            widget.access.roleCodes.any(
              (roleCode) =>
                  roleCode == UserRole.superAdmin.code ||
                  roleCode == UserRole.subAdmin.code,
            ));

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.access.fullName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.access.email,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(widget.access.isActive ? l10n.active : l10n.inactive),
              avatar: Icon(
                widget.access.isActive
                    ? Icons.check_circle_outline
                    : Icons.pause_circle_outline,
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!canManage)
          _AccessNotice(
            message: l10n.isArabic
                ? 'الحساب الحالي يملك عرض الصلاحيات فقط. التعديل غير متاح لهذا المستخدم.'
                : 'The current account can only view access. Editing is not available for this user.',
          ),
        if (isRestrictedSubAdminTarget)
          _AccessNotice(
            message: l10n.isArabic
                ? 'الإداري الفرعي لا يمكنه تعديل حسابه الشخصي أو حسابات الإدارة العليا.'
                : 'A sub-admin cannot edit their own account or higher-privilege admin accounts.',
          ),
        _SectionCard(
          title: l10n.isArabic ? 'الأدوار المعينة' : 'Assigned Roles',
          subtitle: l10n.isArabic
              ? 'الأدوار تحدد الحزمة الأساسية من الصلاحيات قبل تطبيق أي استثناء فردي.'
              : 'Roles define the baseline permission package before any per-user override is applied.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final role in UserRole.values)
                FilterChip(
                  selected: _selectedRoleCodes.contains(role.code),
                  label: Text(l10n.roleLabel(role.code)),
                  onSelected:
                      _canEditRole(
                        role.code,
                        canManage: canManage,
                        isSuperAdmin: isSuperAdmin,
                        isRestrictedTarget: isRestrictedSubAdminTarget,
                      )
                      ? (selected) => _toggleRole(role.code, selected)
                      : null,
                ),
            ],
          ),
        ),
        _SectionCard(
          title: l10n.isArabic ? 'الوحدات الموجهة' : 'Assigned Units',
          subtitle: l10n.isArabic
              ? 'عند اختيار وحدات، يتم قصر الوحدات والحجوزات والصيانة والنظافة ولوحات المتابعة المرتبطة بها على هذه الوحدات لهذا المستخدم.'
              : 'When units are selected, unit, booking, maintenance, housekeeping, and dashboard/report workflows are narrowed to those units for this user.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Text(
                  selectedUnits.isEmpty
                      ? (l10n.isArabic
                            ? 'لا يوجد تقييد وحدات حالياً. سيبقى الوصول التشغيلي على جميع الوحدات المتاحة.'
                            : 'No unit filter is active. Operational access remains available across all visible units.')
                      : (l10n.isArabic
                            ? 'الوحدات المختارة: ${selectedUnits.map((unit) => unit.code).join('، ')}'
                            : 'Selected units: ${selectedUnits.map((unit) => unit.code).join(', ')}'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),
              if (sortedUnits.isEmpty)
                Text(
                  l10n.isArabic
                      ? 'لا توجد وحدات نشطة متاحة للتعيين حالياً.'
                      : 'There are no active units available for assignment right now.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final unit in sortedUnits)
                      FilterChip(
                        selected: _selectedUnitIds.contains(unit.id),
                        label: Text('${unit.code} · ${unit.name}'),
                        onSelected: _canSave(
                              canManage: canManage,
                              isRestrictedTarget: isRestrictedSubAdminTarget,
                            )
                            ? (selected) => _toggleUnit(unit.id, selected)
                            : null,
                      ),
                  ],
                ),
            ],
          ),
        ),
        _SectionCard(
          title: l10n.isArabic ? 'الوصول الفعلي' : 'Effective Access',
          subtitle: l10n.isArabic
              ? 'هذه الصلاحيات ناتجة عن الأدوار الحالية بعد تطبيق الاستثناءات الفردية.'
              : 'These permissions result from the current roles after applying per-user overrides.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final permissionCode in previewEffectivePermissions)
                Chip(
                  label: Text(permissionCode),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        for (final module in modules)
          _SectionCard(
            title: l10n.moduleLabel(module),
            subtitle: l10n.isArabic
                ? 'اختر توريث أو سماح أو منع لكل صلاحية.'
                : 'Choose Inherit, Allow, or Deny for each permission.',
            child: Column(
              children: [
                for (final permission in groupedPermissions[module]!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PermissionTile(
                      permission: permission,
                      mode:
                          _overrideModes[permission.code] ??
                          PermissionOverrideMode.inherit,
                      inherited: previewInheritedPermissions.contains(
                        permission.code,
                      ),
                      effective: _resolvePermissionEffective(
                        permission.code,
                        previewInheritedPermissions,
                      ),
                      enabled: _canEditPermission(
                        permission.code,
                        canManage: canManage,
                        isSuperAdmin: isSuperAdmin,
                        isRestrictedTarget: isRestrictedSubAdminTarget,
                      ),
                      onChanged: (mode) {
                        setState(() {
                          _overrideModes[permission.code] = mode;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            onPressed:
                !_canSave(
                      canManage: canManage,
                      isRestrictedTarget: isRestrictedSubAdminTarget,
                    ) ||
                    _isSaving
                ? null
                : _saveChanges,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _isSaving
                  ? (l10n.isArabic ? 'جارٍ الحفظ...' : 'Saving...')
                  : (l10n.isArabic
                        ? 'حفظ تغييرات الوصول'
                        : 'Save Access Changes'),
            ),
          ),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: widget.scrollable
            ? SingleChildScrollView(child: content)
            : content,
      ),
    );
  }

  void _hydrateFromAccess(AccessUserDetail access) {
    _selectedRoleCodes = {...access.roleCodes};
    _selectedUnitIds = {...access.assignedUnitIds};
    _overrideModes = {
      for (final permission in widget.catalog)
        permission.code: PermissionOverrideMode.inherit,
    };
    for (final override in access.overrides) {
      _overrideModes[override.permissionCode] = override.effect == 'deny'
          ? PermissionOverrideMode.deny
          : PermissionOverrideMode.allow;
    }
    _errorText = null;
  }

  String _accessSignature(AccessUserDetail access) {
    final parts = <String>[
      ...access.roleCodes.toList()..sort(),
      ...access.assignedUnitIds.map((value) => 'unit:$value').toList()..sort(),
      ...access.overrides
          .map((override) => '${override.permissionCode}:${override.effect}')
          .toList()
        ..sort(),
    ];
    return '${access.id}|${parts.join('|')}';
  }

  bool _canEditRole(
    String roleCode, {
    required bool canManage,
    required bool isSuperAdmin,
    required bool isRestrictedTarget,
  }) {
    if (!canManage || isRestrictedTarget) {
      return false;
    }
    return isSuperAdmin || subAdminAssignableRoleCodes.contains(roleCode);
  }

  bool _canEditPermission(
    String permissionCode, {
    required bool canManage,
    required bool isSuperAdmin,
    required bool isRestrictedTarget,
  }) {
    if (!canManage || isRestrictedTarget) {
      return false;
    }
    return isSuperAdmin ||
        subAdminManageablePermissionCodes.contains(permissionCode);
  }

  bool _canSave({required bool canManage, required bool isRestrictedTarget}) {
    return canManage && !isRestrictedTarget;
  }

  void _toggleRole(String roleCode, bool selected) {
    setState(() {
      if (selected) {
        _selectedRoleCodes.add(roleCode);
      } else {
        _selectedRoleCodes.remove(roleCode);
      }
    });
  }

  void _toggleUnit(String unitId, bool selected) {
    setState(() {
      if (selected) {
        _selectedUnitIds.add(unitId);
      } else {
        _selectedUnitIds.remove(unitId);
      }
    });
  }

  bool _resolvePermissionEffective(
    String permissionCode,
    Set<String> inheritedPermissions,
  ) {
    final mode =
        _overrideModes[permissionCode] ?? PermissionOverrideMode.inherit;
    if (mode == PermissionOverrideMode.allow) {
      return true;
    }
    if (mode == PermissionOverrideMode.deny) {
      return false;
    }
    return inheritedPermissions.contains(permissionCode);
  }

  Set<String> _previewInheritedPermissions() {
    final selectedRoles = <UserRole>{};
    for (final roleCode in _selectedRoleCodes) {
      for (final role in UserRole.values) {
        if (role.code == roleCode) {
          selectedRoles.add(role);
          break;
        }
      }
    }
    return defaultPermissionCodesForRoles(selectedRoles);
  }

  List<String> _previewEffectivePermissions(Set<String> inheritedPermissions) {
    final effectivePermissions = {...inheritedPermissions};
    for (final entry in _overrideModes.entries) {
      switch (entry.value) {
        case PermissionOverrideMode.inherit:
          break;
        case PermissionOverrideMode.allow:
          effectivePermissions.add(entry.key);
          break;
        case PermissionOverrideMode.deny:
          effectivePermissions.remove(entry.key);
          break;
      }
    }
    final permissions = effectivePermissions.toList()..sort();
    return permissions;
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final updated = await ref
          .read(backendApiProvider)
          .updateUserAccess(
            widget.access.id,
            roleCodes: _selectedRoleCodes.toList()..sort(),
            assignedUnitIds: _selectedUnitIds.toList()..sort(),
            overrides: _overrideModes.entries
                .where((entry) => entry.value != PermissionOverrideMode.inherit)
                .map(
                  (entry) => UserPermissionOverrideEntry(
                    permissionCode: entry.key,
                    effect: entry.value == PermissionOverrideMode.deny
                        ? 'deny'
                        : 'allow',
                  ),
                )
                .toList(),
          );
      setState(() {
        _hydrateFromAccess(updated);
      });
      ref.invalidate(accessUsersProvider);
      ref.invalidate(userAccessProvider(widget.access.id));
      if (widget.actor.userId == updated.id) {
        await ref.read(sessionControllerProvider.notifier).refreshSession();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isArabic
                ? 'تم حفظ الصلاحيات بنجاح.'
                : 'Access changes were saved successfully.',
          ),
        ),
      );
    } on DioException catch (error) {
      setState(() {
        _errorText = _extractError(error, context.l10n);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.permission,
    required this.mode,
    required this.inherited,
    required this.effective,
    required this.enabled,
    required this.onChanged,
  });

  final AccessPermissionEntry permission;
  final PermissionOverrideMode mode;
  final bool inherited;
  final bool effective;
  final bool enabled;
  final ValueChanged<PermissionOverrideMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.permissionName(permission.code, permission.name),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.permissionDescription(
                        permission.code,
                        permission.description,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            inherited
                                ? (l10n.isArabic ? 'موروثة' : 'Inherited')
                                : (l10n.isArabic
                                      ? 'غير موروثة'
                                      : 'Not inherited'),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            effective
                                ? (l10n.isArabic ? 'مسموح' : 'Allowed')
                                : (l10n.isArabic ? 'ممنوع' : 'Denied'),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(permission.code),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<PermissionOverrideMode>(
                segments: [
                  ButtonSegment<PermissionOverrideMode>(
                    value: PermissionOverrideMode.inherit,
                    label: Text(l10n.isArabic ? 'توريث' : 'Inherit'),
                  ),
                  ButtonSegment<PermissionOverrideMode>(
                    value: PermissionOverrideMode.allow,
                    label: Text(l10n.isArabic ? 'سماح' : 'Allow'),
                  ),
                  ButtonSegment<PermissionOverrideMode>(
                    value: PermissionOverrideMode.deny,
                    label: Text(l10n.isArabic ? 'منع' : 'Deny'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: enabled
                    ? (selection) => onChanged(selection.first)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _AccessNotice extends StatelessWidget {
  const _AccessNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message),
      ),
    );
  }
}

class _OperationTeamsStudio extends ConsumerWidget {
  const _OperationTeamsStudio({
    required this.teams,
    required this.users,
    required this.assignableUnits,
    required this.actor,
  });

  final List<OperationTeamSummary> teams;
  final List<AccessUserSummary> users;
  final List<UnitSummary> assignableUnits;
  final AuthSession actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canManage = actor.hasPermission(AppPermission.usersManageAccess);
    final sortedTeams = [...teams]
      ..sort(
        (left, right) => '${left.operationType}:${left.name}'.compareTo(
          '${right.operationType}:${right.name}',
        ),
      );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.isArabic
                            ? 'استوديو الفرق التشغيلية'
                            : 'Operational Teams Studio',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.isArabic
                            ? 'عرّف فرق النظافة والصيانة واربط كل فريق بوحداته وأعضائه حتى تظهر تلقائياً في الإسناد.'
                            : 'Define housekeeping and maintenance teams, then tie each one to members and units so they appear automatically in assignment flows.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  FilledButton.icon(
                    onPressed: () => _showOperationTeamEditor(
                      context,
                      ref,
                      users: users,
                      assignableUnits: assignableUnits,
                      actor: actor,
                    ),
                    icon: const Icon(Icons.groups_2_outlined),
                    label: Text(
                      l10n.isArabic ? 'فريق جديد' : 'New team',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (sortedTeams.isEmpty)
              Text(
                l10n.isArabic
                    ? 'لا توجد فرق تشغيلية معرفة حالياً.'
                    : 'No operation teams are defined yet.',
              )
            else
              Column(
                children: [
                  for (var index = 0; index < sortedTeams.length; index++) ...[
                    _OperationTeamCard(
                      team: sortedTeams[index],
                      canManage: canManage,
                      onEdit: () => _showOperationTeamEditor(
                        context,
                        ref,
                        initial: sortedTeams[index],
                        users: users,
                        assignableUnits: assignableUnits,
                        actor: actor,
                      ),
                    ),
                    if (index < sortedTeams.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OperationTeamCard extends StatelessWidget {
  const _OperationTeamCard({
    required this.team,
    required this.canManage,
    required this.onEdit,
  });

  final OperationTeamSummary team;
  final bool canManage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      [
                        _operationTeamTypeLabel(context, team.operationType),
                        if (team.description != null && team.description!.isNotEmpty)
                          team.description!,
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      team.isActive
                          ? (l10n.isArabic ? 'نشط' : 'Active')
                          : (l10n.isArabic ? 'موقوف' : 'Inactive'),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (canManage)
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l10n.isArabic ? 'تعديل' : 'Edit'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.isArabic ? 'الوحدات المغطاة' : 'Covered units',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final unit in team.units)
                Chip(
                  label: Text('${unit.code} · ${unit.name}'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.isArabic ? 'مؤشرات الحمل' : 'Workload KPIs',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(
                  l10n.isArabic
                      ? '${team.kpis.openWorkItems} عناصر مفتوحة'
                      : '${team.kpis.openWorkItems} open items',
                ),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(
                  l10n.isArabic
                      ? '${team.kpis.overdueWorkItems} متأخرة'
                      : '${team.kpis.overdueWorkItems} overdue',
                ),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(
                  l10n.isArabic
                      ? 'إغلاق ${_formatTeamKpiHours(team.kpis.averageCloseHours)} س'
                      : '${_formatTeamKpiHours(team.kpis.averageCloseHours)}h avg close',
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.isArabic ? 'الأعضاء' : 'Members',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final member in team.members)
                Tooltip(
                  message:
                      '${member.email} · ${member.roleCodes.map(l10n.roleLabel).join(', ')}',
                  child: Chip(
                    label: Text(member.fullName),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatTeamKpiHours(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _extractError(DioException error, AppLocalizations l10n) {
  final data = error.response?.data;
  if (data is Map) {
    final message = data['message'] ?? data['detail'];
    if (message != null) {
      return '$message';
    }
  }
  return error.message ??
      (l10n.isArabic
          ? 'تعذر حفظ تغييرات الوصول.'
          : 'Unable to save access changes.');
}

String _operationTeamTypeLabel(BuildContext context, String operationType) {
  final l10n = context.l10n;
  switch (operationType) {
    case 'maintenance':
      return l10n.isArabic ? 'فريق صيانة' : 'Maintenance team';
    case 'housekeeping':
    default:
      return l10n.isArabic ? 'فريق نظافة' : 'Housekeeping team';
  }
}

Future<void> _showOperationTeamEditor(
  BuildContext context,
  WidgetRef ref, {
  OperationTeamSummary? initial,
  required List<AccessUserSummary> users,
  required List<UnitSummary> assignableUnits,
  required AuthSession actor,
}) async {
  final l10n = context.l10n;
  final nameController = TextEditingController(text: initial?.name ?? '');
  final descriptionController = TextEditingController(
    text: initial?.description ?? '',
  );
  var operationType = initial?.operationType ?? 'housekeeping';
  var isActive = initial?.isActive ?? true;
  final selectedUnitIds = {...initial?.unitIds ?? const <String>[]};
  final selectedMemberIds = {...initial?.memberUserIds ?? const <String>[]};
  String? errorText;
  bool saved = false;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(
                initial == null
                    ? (l10n.isArabic ? 'إنشاء فريق تشغيلي' : 'Create operation team')
                    : (l10n.isArabic ? 'تعديل الفريق التشغيلي' : 'Edit operation team'),
              ),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: l10n.isArabic ? 'اسم الفريق' : 'Team name',
                        ),
                      ),
                      TextField(
                        controller: descriptionController,
                        minLines: 2,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: l10n.isArabic ? 'الوصف' : 'Description',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: operationType,
                        decoration: InputDecoration(
                          labelText: l10n.isArabic ? 'نوع الفريق' : 'Team type',
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'housekeeping',
                            child: Text(
                              l10n.isArabic ? 'فريق نظافة' : 'Housekeeping team',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text(
                              l10n.isArabic ? 'فريق صيانة' : 'Maintenance team',
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => operationType = value);
                          }
                        },
                      ),
                      SwitchListTile(
                        value: isActive,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.isArabic ? 'الفريق نشط' : 'Team is active'),
                        onChanged: (value) => setState(() => isActive = value),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.isArabic ? 'الوحدات المغطاة' : 'Covered units',
                        style: Theme.of(dialogContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final unit in assignableUnits)
                            FilterChip(
                              selected: selectedUnitIds.contains(unit.id),
                              label: Text('${unit.code} · ${unit.name}'),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedUnitIds.add(unit.id);
                                  } else {
                                    selectedUnitIds.remove(unit.id);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.isArabic ? 'أعضاء الفريق' : 'Team members',
                        style: Theme.of(dialogContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final user in users.where((item) => item.isActive))
                            Tooltip(
                              message:
                                  '${user.email} · ${user.roleCodes.map(l10n.roleLabel).join(', ')}',
                              child: FilterChip(
                                selected: selectedMemberIds.contains(user.id),
                                label: Text(user.fullName),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedMemberIds.add(user.id);
                                    } else {
                                      selectedMemberIds.remove(user.id);
                                    }
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                      if (errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      setState(() {
                        errorText = l10n.isArabic
                            ? 'اسم الفريق مطلوب.'
                            : 'Team name is required.';
                      });
                      return;
                    }
                    if (selectedUnitIds.isEmpty || selectedMemberIds.isEmpty) {
                      setState(() {
                        errorText = l10n.isArabic
                            ? 'اختر وحدة واحدة على الأقل وعضواً واحداً على الأقل.'
                            : 'Select at least one unit and one member.';
                      });
                      return;
                    }
                    try {
                      final api = ref.read(backendApiProvider);
                      if (initial == null) {
                        await api.createOperationTeam(
                          name: nameController.text.trim(),
                          operationType: operationType,
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                          isActive: isActive,
                          unitIds: selectedUnitIds.toList()..sort(),
                          memberUserIds: selectedMemberIds.toList()..sort(),
                        );
                      } else {
                        await api.updateOperationTeam(
                          initial.id,
                          name: nameController.text.trim(),
                          operationType: operationType,
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                          isActive: isActive,
                          unitIds: selectedUnitIds.toList()..sort(),
                          memberUserIds: selectedMemberIds.toList()..sort(),
                        );
                      }
                      saved = true;
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } on DioException catch (error) {
                      setState(() {
                        errorText = _extractError(error, l10n);
                      });
                    }
                  },
                  child: Text(initial == null ? l10n.create : l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    nameController.dispose();
    descriptionController.dispose();
  }

  if (!saved) {
    return;
  }

  ref.invalidate(operationTeamsProvider);
  final actorAffected = selectedMemberIds.contains(actor.userId) ||
      (initial?.memberUserIds.contains(actor.userId) ?? false);
  if (actorAffected) {
    await ref.read(sessionControllerProvider.notifier).refreshSession();
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.isArabic
              ? 'تم حفظ الفريق التشغيلي.'
              : 'The operation team was saved.',
        ),
      ),
    );
  }
}
