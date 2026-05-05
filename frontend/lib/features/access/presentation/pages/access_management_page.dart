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

final permissionGroupsProvider = FutureProvider<List<AccessPermissionGroup>>((
  ref,
) async {
  return ref.read(backendApiProvider).fetchPermissionGroups();
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
    final actor = ref.watch(sessionControllerProvider).valueOrNull;
    final canManageUsers =
        actor?.hasPermission(AppPermission.usersManageAccess) ?? false;

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
                        canCreateUser: canManageUsers,
                        onCreateUser: canManageUsers
                            ? () => _showCreateUserDialog(context)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _AccessDetailHost(
                        userId: selectedUserId,
                        users: users,
                        onDeleteUser: canManageUsers
                            ? (deletedUserId) =>
                                  _handleDeletedUser(context, deletedUserId, users)
                            : null,
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
                canCreateUser: canManageUsers,
                onCreateUser: canManageUsers
                    ? () => _showCreateUserDialog(context)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            _AccessDetailHost(
              userId: selectedUserId,
              users: users,
              onDeleteUser: canManageUsers
                  ? (deletedUserId) =>
                        _handleDeletedUser(context, deletedUserId, users)
                  : null,
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

  void _handleDeletedUser(
    BuildContext context,
    String deletedUserId,
    List<AccessUserSummary> users,
  ) {
    final remainingUsers = users
        .where((user) => user.id != deletedUserId)
        .toList(growable: false);

    setState(() {
      _selectedUserId = remainingUsers.isEmpty ? null : remainingUsers.first.id;
    });
    ref.invalidate(accessUsersProvider);
    ref.invalidate(userAccessProvider(deletedUserId));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.isArabic
              ? 'تم حذف المستخدم بنجاح.'
              : 'The user was deleted successfully.',
        ),
      ),
    );
  }

  Future<void> _showCreateUserDialog(BuildContext context) async {
    final createdUser = await showDialog<AccessUserDetail>(
      context: context,
      builder: (dialogContext) => const _CreateUserDialog(),
    );
    if (createdUser == null || !mounted) {
      return;
    }

    setState(() {
      _selectedUserId = createdUser.id;
    });
    ref.invalidate(accessUsersProvider);
    ref.invalidate(userAccessProvider(createdUser.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.isArabic
              ? 'تم إنشاء المستخدم بنجاح.'
              : 'The user was created successfully.',
        ),
      ),
    );
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final summaryWidth = constraints.maxWidth < 720
            ? constraints.maxWidth
            : 420.0;

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
                width: summaryWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isArabic
                          ? 'إدارة الوصول والصلاحيات'
                          : 'Access and Permissions',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.isArabic
                          ? 'راجع الأدوار، الصلاحيات الفعلية، والاستثناءات لكل مستخدم من شاشة واحدة.'
                          : 'Review roles, effective permissions, and user-level overrides from one workspace.',
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
      },
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

class _UserDirectory extends ConsumerWidget {
  const _UserDirectory({
    required this.users,
    required this.selectedUserId,
    required this.onSelected,
    this.scrollDirection = Axis.vertical,
    this.canCreateUser = false,
    this.onCreateUser,
  });

  final List<AccessUserSummary> users;
  final String selectedUserId;
  final ValueChanged<String> onSelected;
  final Axis scrollDirection;
  final bool canCreateUser;
  final VoidCallback? onCreateUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isHorizontal = scrollDirection == Axis.horizontal;
    final permissionGroupNames = {
      for (final group in ref.watch(permissionGroupsProvider).valueOrNull ??
          const <AccessPermissionGroup>[])
        group.code: group.name,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.isArabic ? 'المستخدمون' : 'Users',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (canCreateUser)
                  FilledButton.icon(
                    onPressed: onCreateUser,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(
                      l10n.isArabic ? 'إضافة مستخدم' : 'Add user',
                    ),
                  ),
              ],
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
                                    label: Text(
                                      _permissionGroupLabel(
                                        l10n,
                                        roleCode,
                                        permissionGroupNames,
                                      ),
                                    ),
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

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog();

  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  final Set<String> _selectedRoleCodes = <String>{};
  final Set<String> _selectedUnitIds = <String>{};
  final Map<String, PermissionOverrideMode> _overrideModes =
      <String, PermissionOverrideMode>{};
  bool _isActive = true;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unitsAsync = ref.watch(assignableUnitsProvider);
    final permissionCatalogAsync = ref.watch(permissionCatalogProvider);
    final permissionGroupsAsync = ref.watch(permissionGroupsProvider);
    final permissionGroups =
        permissionGroupsAsync.valueOrNull ?? const <AccessPermissionGroup>[];
    final previewInheritedPermissions = _previewInheritedPermissions(
      permissionGroups,
    );

    return AlertDialog(
      title: Text(l10n.isArabic ? 'إضافة مستخدم' : 'Add user'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: l10n.isArabic ? 'الاسم الكامل' : 'Full name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.isArabic ? 'البريد الإلكتروني' : 'Email',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.isArabic ? 'كلمة المرور' : 'Password',
                  helperText: l10n.isArabic
                      ? 'يجب أن تكون 8 أحرف على الأقل.'
                      : 'Use at least 8 characters.',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isActive,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.isArabic ? 'الحساب نشط' : 'Account is active'),
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Text(
                l10n.isArabic ? 'مجموعات الصلاحيات' : 'Permission groups',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.isArabic
                    ? 'اختر مجموعة جاهزة إذا كان هذا المستخدم يتبع نفس صلاحيات مجموعة كاملة مثل فريق الصيانة أو النظافة. يمكنك اختيار أكثر من مجموعة، أو تركها فارغة لمستخدم مستقل.'
                    : 'Choose a reusable bundle when this user should share the same access as a wider group such as maintenance or housekeeping. You can select multiple groups, or leave them empty for a standalone user.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              permissionGroupsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => Text(
                  '$error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                data: (groups) {
                  final sortedGroups = [...groups]
                    ..sort(
                      (left, right) =>
                          '${left.isSystem ? 0 : 1}:${left.name}'.compareTo(
                            '${right.isSystem ? 0 : 1}:${right.name}',
                          ),
                    );
                  final permissionGroupNames = {
                    for (final group in groups) group.code: group.name,
                  };
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final group in sortedGroups)
                        FilterChip(
                          selected: _selectedRoleCodes.contains(group.code),
                          label: Text(
                            _permissionGroupLabel(
                              l10n,
                              group.code,
                              permissionGroupNames,
                            ),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedRoleCodes.add(group.code);
                              } else {
                                _selectedRoleCodes.remove(group.code);
                              }
                            });
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.isArabic
                    ? 'الصلاحيات الفردية لهذا المستخدم'
                    : 'Direct permissions for this user',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.isArabic
                    ? 'استخدم هذا القسم إذا كان المستخدم بلا مجموعة، أو إذا أردت منحه أو منعه صلاحيات محددة فوق مجموعة الصلاحيات.'
                    : 'Use this section when the user should have no group, or when you need to allow or deny specific permissions on top of the selected group.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              permissionCatalogAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => Text(
                  '$error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                data: (catalog) {
                  if (catalog.isEmpty) {
                    return Text(
                      l10n.isArabic
                          ? 'تعذر تحميل كتالوج الصلاحيات حالياً.'
                          : 'The permission catalog could not be loaded right now.',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  }

                  final groupedPermissions =
                      <String, List<AccessPermissionEntry>>{};
                  for (final permission in catalog) {
                    groupedPermissions
                        .putIfAbsent(permission.module, () => [])
                        .add(permission);
                  }
                  final modules = groupedPermissions.keys.toList()..sort();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final permissionCode in _previewEffectivePermissions(
                            previewInheritedPermissions,
                          ))
                            Chip(
                              label: Text(permissionCode),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final module in modules) ...[
                        Text(
                          l10n.moduleLabel(module),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        for (final permission in groupedPermissions[module]!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PermissionTile(
                              permission: permission,
                              mode: _overrideModes[permission.code] ??
                                  PermissionOverrideMode.inherit,
                              inherited: previewInheritedPermissions.contains(
                                permission.code,
                              ),
                              effective: _resolvePermissionEffective(
                                permission.code,
                                previewInheritedPermissions,
                              ),
                              enabled: !_isSaving,
                              onChanged: (mode) {
                                setState(() {
                                  _overrideModes[permission.code] = mode;
                                });
                              },
                            ),
                          ),
                        if (module != modules.last) const SizedBox(height: 4),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.isArabic ? 'الوحدات المبدئية' : 'Initial units',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              unitsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => Text(
                  '$error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                data: (units) {
                  if (units.isEmpty) {
                    return Text(
                      l10n.isArabic
                          ? 'لا توجد وحدات نشطة حالياً. يمكن تعيينها لاحقاً من شاشة الصلاحيات.'
                          : 'No active units are available right now. You can assign them later from the access screen.',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  }

                  final sortedUnits = [...units]
                    ..sort((left, right) => left.code.compareTo(right.code));
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final unit in sortedUnits)
                        FilterChip(
                          selected: _selectedUnitIds.contains(unit.id),
                          label: Text('${unit.code} · ${unit.name}'),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedUnitIds.add(unit.id);
                              } else {
                                _selectedUnitIds.remove(unit.id);
                              }
                            });
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                l10n.isArabic
                    ? 'الفرق التشغيلية للصيانة والنظافة مخصصة لتوزيع المهام على الوحدات، وليست بديلاً عن مجموعات الصلاحيات أو الصلاحيات الفردية أعلاه.'
                    : 'Maintenance and housekeeping operational teams are used for task assignment across units, not as a replacement for the permission groups or direct permissions above.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? l10n.loading : l10n.create),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = l10n.isArabic
            ? 'أكمل الاسم والبريد الإلكتروني وكلمة المرور.'
            : 'Complete the name, email, and password fields.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final created = await ref.read(backendApiProvider).createAccessUser(
            AccessUserCreateInput(
              fullName: fullName,
              email: email,
              password: password,
              isActive: _isActive,
              roleCodes: _selectedRoleCodes.toList()..sort(),
              overrides: _overrideModes.entries
                  .where(
                    (entry) => entry.value != PermissionOverrideMode.inherit,
                  )
                  .map(
                    (entry) => UserPermissionOverrideEntry(
                      permissionCode: entry.key,
                      effect: entry.value == PermissionOverrideMode.deny
                          ? 'deny'
                          : 'allow',
                    ),
                  )
                  .toList(),
              assignedUnitIds: _selectedUnitIds.toList()..sort(),
            ),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(created);
    } on DioException catch (error) {
      setState(() {
        _errorText = _extractError(error, l10n);
        _isSaving = false;
      });
    }
  }

  Set<String> _previewInheritedPermissions(
    Iterable<AccessPermissionGroup> permissionGroups,
  ) {
    final inheritedPermissions = <String>{};
    for (final group in permissionGroups) {
      if (_selectedRoleCodes.contains(group.code)) {
        inheritedPermissions.addAll(group.permissionCodes);
      }
    }
    return inheritedPermissions;
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
}

class _AccessDetailHost extends ConsumerWidget {
  const _AccessDetailHost({
    required this.userId,
    required this.users,
    this.onDeleteUser,
    required this.scrollable,
  });

  final String userId;
  final List<AccessUserSummary> users;
  final ValueChanged<String>? onDeleteUser;
  final bool scrollable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(permissionCatalogProvider);
    final groupsAsync = ref.watch(permissionGroupsProvider);
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
      data: (catalog) => groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: AppErrorView(
            title: context.l10n.isArabic
                ? 'تعذر تحميل مجموعات الصلاحيات'
                : 'Unable to load permission groups',
            subtitle: '$error',
            onRetry: () => ref.invalidate(permissionGroupsProvider),
          ),
        ),
        data: (permissionGroups) => unitsAsync.when(
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
                    permissionGroups: permissionGroups,
                    assignableUnits: assignableUnits,
                    actor: actor,
                    onDeleteUser: onDeleteUser,
                    scrollable: false,
                  ),
                  _PermissionGroupsStudio(
                    permissionGroups: permissionGroups,
                    catalog: catalog,
                    selectedUserId: userId,
                    actor: actor,
                  ),
                  _OperationTeamsStudio(
                    teams: teams,
                    users: users,
                    permissionGroups: permissionGroups,
                    assignableUnits: assignableUnits,
                    actor: actor,
                  ),
                ];

                if (scrollable) {
                  return ListView.separated(
                    itemCount: content.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
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
      ),
    );
  }
}

class _UserAccessEditor extends ConsumerStatefulWidget {
  const _UserAccessEditor({
    super.key,
    required this.access,
    required this.catalog,
    required this.permissionGroups,
    required this.assignableUnits,
    required this.actor,
    this.onDeleteUser,
    required this.scrollable,
  });

  final AccessUserDetail access;
  final List<AccessPermissionEntry> catalog;
  final List<AccessPermissionGroup> permissionGroups;
  final List<UnitSummary> assignableUnits;
  final AuthSession actor;
  final ValueChanged<String>? onDeleteUser;
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
    final permissionGroupNames = {
      for (final group in widget.permissionGroups) group.code: group.name,
    };
    final sortedPermissionGroups = [...widget.permissionGroups]
      ..sort(
        (left, right) =>
            '${left.isSystem ? 0 : 1}:${left.name}'.compareTo(
              '${right.isSystem ? 0 : 1}:${right.name}',
            ),
      );
    final sortedUnits = [...widget.assignableUnits]
      ..sort((left, right) => left.code.compareTo(right.code));
    final selectedUnits = sortedUnits
        .where((unit) => _selectedUnitIds.contains(unit.id))
        .toList();
    final canManage = widget.actor.hasPermission(
      AppPermission.usersManageAccess,
    );
    final isSuperAdmin = widget.actor.hasRole(UserRole.superAdmin);
    final isSelfTarget = widget.actor.userId == widget.access.id;
    final isRestrictedSubAdminTarget =
        !isSuperAdmin &&
      (isSelfTarget ||
            widget.access.roleCodes.any(
              (roleCode) =>
                  roleCode == UserRole.superAdmin.code ||
                  roleCode == UserRole.subAdmin.code,
            ));
    final canDeleteUser =
      canManage &&
      !isSelfTarget &&
      !widget.access.roleCodes.contains(UserRole.superAdmin.code) &&
      (isSuperAdmin ||
        !widget.access.roleCodes.contains(UserRole.subAdmin.code));

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
            if (canDeleteUser) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _confirmDeleteUser,
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.isArabic ? 'حذف المستخدم' : 'Delete User'),
              ),
            ],
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
          title: l10n.isArabic ? 'مجموعات الصلاحيات' : 'Permission Groups',
          subtitle: l10n.isArabic
              ? 'اختر مجموعة جاهزة أو مخصصة، ويمكن إسناد نفس المجموعة لعدة مستخدمين ثم تخصيص مستخدم بعينه من خلال الصلاحيات الفردية في الأسفل.'
              : 'Choose a built-in or custom group. The same group can be assigned to many users, then refined per user with direct permission overrides below.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final group in sortedPermissionGroups)
                FilterChip(
                  selected: _selectedRoleCodes.contains(group.code),
                  label: Text(
                    _permissionGroupLabel(
                      l10n,
                      group.code,
                      permissionGroupNames,
                    ),
                  ),
                  onSelected:
                      _canEditRole(
                        group,
                        canManage: canManage,
                        isSuperAdmin: isSuperAdmin,
                        isRestrictedTarget: isRestrictedSubAdminTarget,
                      )
                      ? (selected) => _toggleRole(group.code, selected)
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
                        onSelected:
                            _canSave(
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
    AccessPermissionGroup permissionGroup, {
    required bool canManage,
    required bool isSuperAdmin,
    required bool isRestrictedTarget,
  }) {
    if (!canManage || isRestrictedTarget) {
      return false;
    }
    return isSuperAdmin ||
        permissionGroup.permissionCodes.every(
          subAdminManageablePermissionCodes.contains,
        );
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
    final inheritedPermissions = <String>{};
    for (final group in widget.permissionGroups) {
      if (_selectedRoleCodes.contains(group.code)) {
        inheritedPermissions.addAll(group.permissionCodes);
      }
    }
    return inheritedPermissions;
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
      ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _confirmDeleteUser() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.isArabic ? 'حذف المستخدم' : 'Delete User'),
        content: Text(
          l10n.isArabic
              ? 'سيتم حذف ${widget.access.fullName} نهائياً مع أدواره واستثناءاته الفردية وربط الوحدات الخاصة به. هل تريد المتابعة؟'
              : 'This will permanently remove ${widget.access.fullName} together with role assignments, per-user overrides, and unit assignments. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref.read(backendApiProvider).deleteAccessUser(widget.access.id);
      ref.invalidate(accessUsersProvider);
      ref.invalidate(userAccessProvider(widget.access.id));
      if (!mounted) {
        return;
      }
      widget.onDeleteUser?.call(widget.access.id);
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = _extractError(error, context.l10n);
        _isSaving = false;
      });
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final useVerticalLayout = constraints.maxWidth < 720;
        final permissionSummary = Column(
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
                        : (l10n.isArabic ? 'غير موروثة' : 'Not inherited'),
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
        );

        final modeSelector = DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<PermissionOverrideMode>(
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
          ),
        );

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: useVerticalLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    permissionSummary,
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: modeSelector,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: permissionSummary),
                    const SizedBox(width: 12),
                    modeSelector,
                  ],
                ),
        );
      },
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

class _PermissionGroupsStudio extends ConsumerWidget {
  const _PermissionGroupsStudio({
    required this.permissionGroups,
    required this.catalog,
    required this.selectedUserId,
    required this.actor,
  });

  final List<AccessPermissionGroup> permissionGroups;
  final List<AccessPermissionEntry> catalog;
  final String selectedUserId;
  final AuthSession actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canManage = actor.hasPermission(AppPermission.usersManageAccess);
    final permissionNameByCode = {
      for (final permission in catalog)
        permission.code: l10n.permissionName(permission.code, permission.name),
    };
    final sortedGroups = [...permissionGroups]
      ..sort(
        (left, right) =>
            '${left.isSystem ? 0 : 1}:${left.name}'.compareTo(
              '${right.isSystem ? 0 : 1}:${right.name}',
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
                            ? 'استوديو مجموعات الصلاحيات'
                            : 'Permission Groups Studio',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.isArabic
                            ? 'أنشئ مجموعة صلاحيات مشتركة لعدة مستخدمين، ثم عدّل صلاحيات المجموعة مرة واحدة لتنعكس على جميع أعضائها.'
                            : 'Create shared permission bundles for multiple users, then update the group once to change access for every assigned member.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  FilledButton.icon(
                    onPressed: () => _showPermissionGroupEditor(
                      context,
                      ref,
                      catalog: catalog,
                      selectedUserId: selectedUserId,
                    ),
                    icon: const Icon(Icons.library_add_outlined),
                    label: Text(
                      l10n.isArabic ? 'مجموعة جديدة' : 'New group',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (sortedGroups.isEmpty)
              Text(
                l10n.isArabic
                    ? 'لا توجد مجموعات صلاحيات معرفة حالياً.'
                    : 'No permission groups are defined yet.',
              )
            else
              Column(
                children: [
                  for (var index = 0; index < sortedGroups.length; index++) ...[
                    _PermissionGroupCard(
                      group: sortedGroups[index],
                      permissionNameByCode: permissionNameByCode,
                      canManage: canManage,
                      onEdit: sortedGroups[index].isSystem
                          ? null
                          : () => _showPermissionGroupEditor(
                                context,
                                ref,
                                initial: sortedGroups[index],
                                catalog: catalog,
                                selectedUserId: selectedUserId,
                              ),
                      onDelete: !sortedGroups[index].isSystem &&
                              sortedGroups[index].memberCount == 0
                          ? () => _confirmDeletePermissionGroup(
                                context,
                                ref,
                                group: sortedGroups[index],
                                selectedUserId: selectedUserId,
                              )
                          : null,
                    ),
                    if (index < sortedGroups.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionGroupCard extends StatelessWidget {
  const _PermissionGroupCard({
    required this.group,
    required this.permissionNameByCode,
    required this.canManage,
    this.onEdit,
    this.onDelete,
  });

  final AccessPermissionGroup group;
  final Map<String, String> permissionNameByCode;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      group.isSystem
                          ? (l10n.isArabic
                                ? 'مجموعة نظام أساسية جاهزة للاستخدام.'
                                : 'Built-in system group ready for reuse.')
                          : (l10n.isArabic
                                ? 'مجموعة مخصصة يمكنك تعديلها وإسنادها لعدد غير محدود من المستخدمين.'
                                : 'Custom group that can be edited and assigned to any number of users.'),
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
                      group.isSystem
                          ? (l10n.isArabic ? 'أساسية' : 'Built-in')
                          : (l10n.isArabic ? 'مخصصة' : 'Custom'),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(
                      l10n.isArabic
                          ? '${l10n.formatNumber(group.memberCount)} مستخدم'
                          : '${group.memberCount} users',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (canManage && onEdit != null)
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l10n.isArabic ? 'تعديل' : 'Edit'),
                    ),
                  if (canManage && !group.isSystem)
                    Tooltip(
                      message: group.memberCount > 0
                          ? (l10n.isArabic
                                ? 'أزل إسناد هذه المجموعة من جميع المستخدمين أولاً قبل الحذف.'
                                : 'Remove this group from all users before deleting it.')
                          : (l10n.isArabic
                                ? 'حذف المجموعة المخصصة'
                                : 'Delete custom group'),
                      child: OutlinedButton.icon(
                        onPressed: group.memberCount > 0 ? null : onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l10n.isArabic ? 'حذف' : 'Delete'),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final permissionCode in group.permissionCodes)
                Chip(
                  label: Text(
                    permissionNameByCode[permissionCode] ?? permissionCode,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OperationTeamsStudio extends ConsumerWidget {
  const _OperationTeamsStudio({
    required this.teams,
    required this.users,
    required this.permissionGroups,
    required this.assignableUnits,
    required this.actor,
  });

  final List<OperationTeamSummary> teams;
  final List<AccessUserSummary> users;
  final List<AccessPermissionGroup> permissionGroups;
  final List<UnitSummary> assignableUnits;
  final AuthSession actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canManage = actor.hasPermission(AppPermission.usersManageAccess);
    final permissionGroupNames = {
      for (final group in permissionGroups) group.code: group.name,
    };
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
                            ? 'عرّف فرق النظافة والصيانة واربط كل فريق بوحداته وأعضائه حتى تظهر تلقائياً في الإسناد. هذه الفرق لتنظيم التشغيل وتوزيع المهام، أما صلاحيات الدخول فتدار من مجموعات الصلاحيات والصلاحيات الفردية بالأعلى.'
                            : 'Define housekeeping and maintenance teams, then tie each one to members and units so they appear automatically in assignment flows. These teams organize operations and task assignment, while sign-in access is managed by the permission groups and direct per-user permissions above.',
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
                    label: Text(l10n.isArabic ? 'فريق جديد' : 'New team'),
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
                      permissionGroupNames: permissionGroupNames,
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
                    if (index < sortedTeams.length - 1)
                      const SizedBox(height: 12),
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
    required this.permissionGroupNames,
    required this.canManage,
    required this.onEdit,
  });

  final OperationTeamSummary team;
  final Map<String, String> permissionGroupNames;
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
                    Text(
                      team.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        _operationTeamTypeLabel(context, team.operationType),
                        if (team.description != null &&
                            team.description!.isNotEmpty)
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
                      '${member.email} · ${member.roleCodes.map((roleCode) => _permissionGroupLabel(l10n, roleCode, permissionGroupNames)).join(', ')}',
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

Future<void> _showPermissionGroupEditor(
  BuildContext context,
  WidgetRef ref, {
  AccessPermissionGroup? initial,
  required List<AccessPermissionEntry> catalog,
  required String selectedUserId,
}) async {
  final l10n = context.l10n;
  final nameController = TextEditingController(text: initial?.name ?? '');
  final selectedPermissionCodes = {...initial?.permissionCodes ?? const <String>[]};
  final groupedPermissions = <String, List<AccessPermissionEntry>>{};
  for (final permission in catalog) {
    groupedPermissions.putIfAbsent(permission.module, () => []).add(permission);
  }
  final modules = groupedPermissions.keys.toList()..sort();
  String? errorText;
  bool saving = false;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(
                initial == null
                    ? (l10n.isArabic
                          ? 'إنشاء مجموعة صلاحيات'
                          : 'Create permission group')
                    : (l10n.isArabic
                          ? 'تعديل مجموعة الصلاحيات'
                          : 'Edit permission group'),
              ),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: l10n.isArabic
                              ? 'اسم المجموعة'
                              : 'Group name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.isArabic
                            ? 'اختر الصلاحيات التي سيتشاركها جميع المستخدمين المسندين لهذه المجموعة.'
                            : 'Choose the permissions that every user assigned to this group should share.',
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      for (final module in modules) ...[
                        Text(
                          l10n.moduleLabel(module),
                          style: Theme.of(dialogContext).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final permission in groupedPermissions[module]!)
                              FilterChip(
                                selected: selectedPermissionCodes.contains(
                                  permission.code,
                                ),
                                label: Text(
                                  l10n.permissionName(
                                    permission.code,
                                    permission.name,
                                  ),
                                ),
                                onSelected: saving
                                    ? null
                                    : (selected) {
                                        setState(() {
                                          if (selected) {
                                            selectedPermissionCodes.add(
                                              permission.code,
                                            );
                                          } else {
                                            selectedPermissionCodes.remove(
                                              permission.code,
                                            );
                                          }
                                        });
                                      },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (errorText != null)
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            setState(() {
                              errorText = l10n.isArabic
                                  ? 'أدخل اسم المجموعة.'
                                  : 'Enter a group name.';
                            });
                            return;
                          }
                          if (selectedPermissionCodes.isEmpty) {
                            setState(() {
                              errorText = l10n.isArabic
                                  ? 'اختر صلاحية واحدة على الأقل.'
                                  : 'Select at least one permission.';
                            });
                            return;
                          }

                          setState(() {
                            saving = true;
                            errorText = null;
                          });

                          try {
                            if (initial == null) {
                              await ref.read(backendApiProvider).createPermissionGroup(
                                    name: name,
                                    permissionCodes: selectedPermissionCodes.toList()
                                      ..sort(),
                                  );
                            } else {
                              await ref.read(backendApiProvider).updatePermissionGroup(
                                    initial.code,
                                    name: name,
                                    permissionCodes: selectedPermissionCodes.toList()
                                      ..sort(),
                                  );
                            }
                            ref.invalidate(permissionGroupsProvider);
                            ref.invalidate(userAccessProvider(selectedUserId));
                            await ref
                                .read(sessionControllerProvider.notifier)
                                .refreshSession();
                            if (!dialogContext.mounted) {
                              return;
                            }
                            Navigator.of(dialogContext).pop();
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.isArabic
                                      ? 'تم حفظ مجموعة الصلاحيات بنجاح.'
                                      : 'The permission group was saved successfully.',
                                ),
                              ),
                            );
                          } on DioException catch (error) {
                            setState(() {
                              errorText = _extractError(error, l10n);
                              saving = false;
                            });
                          }
                        },
                  child: Text(
                    saving ? l10n.loading : (initial == null ? l10n.create : (l10n.isArabic ? 'حفظ' : 'Save')),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    nameController.dispose();
  }
}

Future<void> _confirmDeletePermissionGroup(
  BuildContext context,
  WidgetRef ref, {
  required AccessPermissionGroup group,
  required String selectedUserId,
}) async {
  final l10n = context.l10n;
  var isDeleting = false;
  String? errorText;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(
              l10n.isArabic ? 'حذف مجموعة الصلاحيات' : 'Delete permission group',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.isArabic
                      ? 'سيتم حذف المجموعة "${group.name}" نهائياً لأنها غير مسندة لأي مستخدم حالياً.'
                      : 'The group "${group.name}" will be deleted permanently because it is not currently assigned to any user.',
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.isArabic
                      ? 'لن يمكن حذف أي مجموعة مخصصة مرتبطة بمستخدمين حتى يتم فك الإسناد أولاً.'
                      : 'Custom groups assigned to users cannot be deleted until all user assignments are removed.',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDeleting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setState(() {
                          isDeleting = true;
                          errorText = null;
                        });
                        try {
                          await ref
                              .read(backendApiProvider)
                              .deletePermissionGroup(group.code);
                          ref.invalidate(permissionGroupsProvider);
                          ref.invalidate(userAccessProvider(selectedUserId));
                          if (!dialogContext.mounted) {
                            return;
                          }
                          Navigator.of(dialogContext).pop();
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.isArabic
                                    ? 'تم حذف مجموعة الصلاحيات بنجاح.'
                                    : 'The permission group was deleted successfully.',
                              ),
                            ),
                          );
                        } on DioException catch (error) {
                          setState(() {
                            errorText = _extractError(error, l10n);
                            isDeleting = false;
                          });
                        }
                      },
                child: Text(
                  isDeleting
                      ? l10n.loading
                      : (l10n.isArabic ? 'تأكيد الحذف' : 'Confirm delete'),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

String _formatTeamKpiHours(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _permissionGroupLabel(
  AppLocalizations l10n,
  String roleCode,
  Map<String, String> permissionGroupNames,
) {
  return permissionGroupNames[roleCode] ?? l10n.roleLabel(roleCode);
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
                    ? (l10n.isArabic
                          ? 'إنشاء فريق تشغيلي'
                          : 'Create operation team')
                    : (l10n.isArabic
                          ? 'تعديل الفريق التشغيلي'
                          : 'Edit operation team'),
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
                              l10n.isArabic
                                  ? 'فريق نظافة'
                                  : 'Housekeeping team',
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
                        title: Text(
                          l10n.isArabic ? 'الفريق نشط' : 'Team is active',
                        ),
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
                          for (final user in users.where(
                            (item) => item.isActive,
                          ))
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
  final actorAffected =
      selectedMemberIds.contains(actor.userId) ||
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
