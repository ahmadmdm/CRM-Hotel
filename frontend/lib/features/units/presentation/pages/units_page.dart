import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/auth/permissions.dart';
import '../../../../core/auth/session_controller.dart';
import '../../../../core/network/backend_api_service.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../design_system/components/status_chip.dart';

final unitsProvider = FutureProvider<List<UnitSummary>>((ref) async {
  return ref.read(backendApiProvider).fetchUnits();
});

final unitAmenitiesCatalogProvider = FutureProvider<List<AmenityOption>>((
  ref,
) async {
  return ref.read(backendApiProvider).fetchUnitAmenitiesCatalog();
});

final unitDetailProvider = FutureProvider.autoDispose
    .family<UnitDetail, String>((ref, unitId) async {
      return ref.read(backendApiProvider).fetchUnitDetail(unitId);
    });

final unitBookingsProvider = FutureProvider.autoDispose
    .family<List<BookingSummary>, String>((ref, unitId) async {
      final bookings = await ref.read(backendApiProvider).fetchBookings();
      return bookings.where((booking) => booking.unitId == unitId).toList()
        ..sort((left, right) => right.checkInAt.compareTo(left.checkInAt));
    });

const _allAssigneesValue = '__all__';

Color _unitStatusColor(String status) {
  switch (status) {
    case 'vacant':
    case 'ready':
      return Colors.green;
    case 'reserved':
      return Colors.amber;
    case 'occupied':
      return Colors.blue;
    case 'pending_cleaning':
      return Colors.orange;
    case 'maintenance':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

String _assignmentTargetLabel(
  BuildContext context,
  AssignableUserSummary assignee,
) {
  final l10n = context.l10n;
  if (assignee.isTeam) {
    return l10n.isArabic
        ? 'فريق ${assignee.name} · ${assignee.memberUserIds.length} أعضاء'
        : 'Team ${assignee.name} · ${assignee.memberUserIds.length} members';
  }
  if (assignee.email != null && assignee.email!.isNotEmpty) {
    return '${assignee.fullName} · ${assignee.email}';
  }
  return assignee.fullName;
}

String _assignmentSelectionValue({String? userId, String? teamId}) {
  return userId ?? teamId ?? _allAssigneesValue;
}

String? _selectedAssignedUserId(
  List<AssignableUserSummary> assignees,
  String selectedValue,
) {
  if (selectedValue == _allAssigneesValue) {
    return null;
  }
  final selected = assignees.cast<AssignableUserSummary?>().firstWhere(
    (item) => item?.id == selectedValue,
    orElse: () => null,
  );
  if (selected == null || selected.isTeam) {
    return null;
  }
  return selected.id;
}

String? _selectedAssignedTeamId(
  List<AssignableUserSummary> assignees,
  String selectedValue,
) {
  if (selectedValue == _allAssigneesValue) {
    return null;
  }
  final selected = assignees.cast<AssignableUserSummary?>().firstWhere(
    (item) => item?.id == selectedValue,
    orElse: () => null,
  );
  if (selected == null || !selected.isTeam) {
    return null;
  }
  return selected.id;
}

class UnitsPage extends ConsumerWidget {
  const UnitsPage({super.key, this.selectedUnitId});

  final String? selectedUnitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitsProvider);
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canManageUnits =
        session?.hasPermission(AppPermission.unitsManage) ?? false;
    final canViewBookings =
      session?.hasPermission(AppPermission.bookingsView) ?? false;
    final canManageBookings =
      session?.hasPermission(AppPermission.bookingsManage) ?? false;
    final canManageHousekeeping =
      session?.hasPermission(AppPermission.housekeepingManage) ?? false;
    final canManageMaintenance =
      session?.hasPermission(AppPermission.maintenanceManage) ?? false;

    return units.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          title: l10n.isArabic ? 'تعذر تحميل الوحدات' : 'Unable to load units',
          subtitle: '$error',
          onRetry: () => ref.invalidate(unitsProvider),
        ),
      ),
      data: (items) => ListView(
        children: [
          if (canManageUnits)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: () => _showUnitEditor(context, ref),
                icon: const Icon(Icons.add_business_outlined),
                label: Text(
                  l10n.isArabic ? 'إضافة وحدة جديدة' : 'Add new unit',
                ),
              ),
            ),
          const SizedBox(height: 16),
          _InventoryOverviewDeck(items: items),
          if (selectedUnitId != null) ...[
            const SizedBox(height: 16),
            _UnitDetailSection(
              unitId: selectedUnitId!,
              canManageUnits: canManageUnits,
              canViewBookings: canViewBookings,
              canManageBookings: canManageBookings,
              canManageHousekeeping: canManageHousekeeping,
              canManageMaintenance: canManageMaintenance,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final unit in items)
                SizedBox(
                  width: 320,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => context.go('/app/units/${unit.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (unit.coverImageUrl != null ||
                                unit.coverImagePath != null)
                              _UnitCoverPreview(
                                imageUrl: unit.coverImageUrl,
                                fallbackLabel: unit.coverImagePath ?? unit.name,
                              ),
                            if (unit.coverImageUrl != null ||
                                unit.coverImagePath != null)
                              const SizedBox(height: 12),
                            Text(
                              '${unit.code} · ${unit.name}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            StatusChip(
                              label: l10n.unitStatus(unit.status),
                              color: _unitStatusColor(unit.status),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              l10n.isArabic
                                  ? '${unit.city} · ${l10n.formatCurrency(unit.nightlyRate)} / ليلة'
                                  : '${unit.city} · ${l10n.formatCurrency(unit.nightlyRate)} / night',
                            ),
                            if (unit.amenityCodes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final amenity in unit.amenityCodes)
                                    Chip(
                                      label: Text(
                                        _amenityLabel(context, amenity),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryOverviewDeck extends StatelessWidget {
  const _InventoryOverviewDeck({required this.items});

  final List<UnitSummary> items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final availableCount = items
        .where((unit) => unit.status == 'ready' || unit.status == 'vacant')
        .length;
    final reservedCount = items.where((unit) => unit.status == 'reserved').length;
    final occupiedCount = items.where((unit) => unit.status == 'occupied').length;
    final serviceCount = items
        .where(
          (unit) =>
              unit.status == 'pending_cleaning' || unit.status == 'maintenance',
        )
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.midnight, AppColors.ink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.isArabic ? 'لوحة إشغال الوحدات' : 'Unit inventory deck',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.isArabic
                ? 'راقب الوحدات الفارغة والمشغولة والمحجوزة والمتوقفة للخدمة من سطح واحد.'
                : 'Track vacant, occupied, reserved, and service-blocked units from one surface.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InventoryStatCard(
                label: l10n.isArabic ? 'الفارغة / الجاهزة' : 'Vacant / Ready',
                value: l10n.formatNumber(availableCount),
                accent: AppColors.pine,
              ),
              _InventoryStatCard(
                label: l10n.isArabic ? 'محجوزة' : 'Reserved',
                value: l10n.formatNumber(reservedCount),
                accent: AppColors.amber,
              ),
              _InventoryStatCard(
                label: l10n.isArabic ? 'مشغولة' : 'Occupied',
                value: l10n.formatNumber(occupiedCount),
                accent: AppColors.sky,
              ),
              _InventoryStatCard(
                label: l10n.isArabic ? 'متوقفة للخدمة' : 'Service blocked',
                value: l10n.formatNumber(serviceCount),
                accent: AppColors.rose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryStatCard extends StatelessWidget {
  const _InventoryStatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitDetailSection extends ConsumerWidget {
  const _UnitDetailSection({
    required this.unitId,
    required this.canManageUnits,
    required this.canViewBookings,
    required this.canManageBookings,
    required this.canManageHousekeeping,
    required this.canManageMaintenance,
  });

  final String unitId;
  final bool canManageUnits;
  final bool canViewBookings;
  final bool canManageBookings;
  final bool canManageHousekeeping;
  final bool canManageMaintenance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final detail = ref.watch(unitDetailProvider(unitId));

    return detail.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppErrorView(
            title: context.l10n.isArabic
                ? 'تعذر تحميل تفاصيل الوحدة'
                : 'Unable to load unit details',
            subtitle: '$error',
            onRetry: () => ref.invalidate(unitDetailProvider(unitId)),
          ),
        ),
      ),
      data: (unit) {
        final canShowOperations =
            canViewBookings ||
            canManageBookings ||
            canManageHousekeeping ||
            canManageMaintenance;

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
                          '${unit.code} · ${unit.name}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.isArabic
                              ? '${unit.city}، ${unit.country} · ${l10n.formatCurrency(unit.nightlyRate, currencyCode: unit.currency)} / ليلة'
                              : '${unit.city}, ${unit.country} · ${l10n.formatCurrency(unit.nightlyRate, currencyCode: unit.currency)} / night',
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: l10n.unitStatus(unit.status),
                    color: _unitStatusColor(unit.status),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    label: l10n.isArabic ? 'السعة' : 'Capacity',
                    value: '${unit.capacity}',
                  ),
                  _MetricCard(
                    label: l10n.isArabic ? 'غرف النوم' : 'Bedrooms',
                    value: '${unit.bedrooms}',
                  ),
                  _MetricCard(
                    label: l10n.isArabic ? 'الحمامات' : 'Bathrooms',
                    value: '${unit.bathrooms}',
                  ),
                  _MetricCard(
                    label: l10n.isArabic ? 'شهري' : 'Monthly',
                    value: l10n.formatCurrency(
                      unit.monthlyRate,
                      currencyCode: unit.currency,
                    ),
                  ),
                  _MetricCard(
                    label: l10n.isArabic ? 'إهلاك شهري' : 'Monthly depreciation',
                    value: l10n.formatCurrency(
                      unit.monthlyDepreciation,
                      currencyCode: unit.currency,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.isArabic ? 'المرافق' : 'Amenities',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (unit.amenities.isEmpty)
                Text(
                  l10n.isArabic
                      ? 'لا توجد مرافق مرتبطة حالياً.'
                      : 'No amenities are linked right now.',
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final amenity in unit.amenities)
                      Chip(
                        label: Text(_amenityLabel(context, amenity.name)),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                l10n.isArabic ? 'الصور' : 'Images',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (unit.images.isEmpty)
                Text(
                  l10n.isArabic
                      ? 'لا توجد صور محفوظة لهذه الوحدة.'
                      : 'No media files are stored for this unit.',
                )
              else
                Column(
                  children: [
                    for (final image in unit.images)
                      _UnitImageTile(
                        unitId: unit.id,
                        image: image,
                        canManage: canManageUnits,
                      ),
                  ],
                ),
              if (canShowOperations) ...[
                const Divider(height: 32),
                Text(
                  l10n.isArabic ? 'مركز أوامر الوحدة' : 'Unit operations cockpit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.isArabic
                      ? 'ابدأ الحجز أو أنشئ أوامر النظافة والصيانة أو أعد إسنادها مباشرة من هذه الوحدة.'
                      : 'Launch bookings, create service orders, and reassign them directly from this unit.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (canManageBookings)
                      FilledButton.icon(
                        onPressed: () => _showCreateBookingDialog(context, ref, unit),
                        icon: const Icon(Icons.event_available_outlined),
                        label: Text(
                          l10n.isArabic ? 'حجز هذه الوحدة' : 'Book this unit',
                        ),
                      ),
                    if (canManageHousekeeping)
                      OutlinedButton.icon(
                        onPressed: () => _showCreateHousekeepingDialog(context, ref, unit),
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: Text(
                          l10n.isArabic ? 'أمر تنظيف جديد' : 'New cleaning order',
                        ),
                      ),
                    if (canManageHousekeeping)
                      OutlinedButton.icon(
                        onPressed: () => _showAssignHousekeepingDialog(context, ref, unit),
                        icon: const Icon(Icons.person_search_outlined),
                        label: Text(
                          l10n.isArabic ? 'إسناد تنظيف' : 'Assign cleaning',
                        ),
                      ),
                    if (canManageMaintenance)
                      OutlinedButton.icon(
                        onPressed: () => _showCreateMaintenanceDialog(context, ref, unit),
                        icon: const Icon(Icons.build_outlined),
                        label: Text(
                          l10n.isArabic ? 'تذكرة صيانة جديدة' : 'New maintenance ticket',
                        ),
                      ),
                    if (canManageMaintenance)
                      OutlinedButton.icon(
                        onPressed: () => _showAssignMaintenanceDialog(context, ref, unit),
                        icon: const Icon(Icons.assignment_ind_outlined),
                        label: Text(
                          l10n.isArabic ? 'إسناد صيانة' : 'Assign maintenance',
                        ),
                      ),
                  ],
                ),
              ],
              if (canManageUnits) ...[
                const Divider(height: 32),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () =>
                          _showUnitEditor(context, ref, initial: unit),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        l10n.isArabic ? 'تعديل الوحدة' : 'Edit unit',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showAddImageDialog(context, ref, unit.id),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(
                        l10n.isArabic ? 'رفع ملف أو صورة' : 'Upload file or image',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _confirmDeactivateUnit(context, ref, unit.id),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        l10n.isArabic ? 'تعطيل الوحدة' : 'Deactivate unit',
                      ),
                    ),
                  ],
                ),
              ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _UnitCoverPreview extends StatelessWidget {
  const _UnitCoverPreview({
    required this.imageUrl,
    required this.fallbackLabel,
  });

  final String? imageUrl;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 160,
        width: double.infinity,
        color: Colors.blueGrey.shade50,
        child: imageUrl == null
            ? _UnitPreviewFallback(label: fallbackLabel)
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _UnitPreviewFallback(label: fallbackLabel),
              ),
      ),
    );
  }
}

class _UnitPreviewFallback extends StatelessWidget {
  const _UnitPreviewFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.image_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _UnitImageTile extends ConsumerWidget {
  const _UnitImageTile({
    required this.unitId,
    required this.image,
    required this.canManage,
  });

  final String unitId;
  final UnitImageAsset image;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      children: [
        if (image.isImage && image.publicUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.network(
                  image.publicUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _UnitPreviewFallback(label: image.displayName),
                ),
              ),
            ),
          ),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            image.isCover ? Icons.star : Icons.attach_file_outlined,
          ),
          title: Text(image.displayName),
          subtitle: Text(
            l10n.isArabic
                ? 'المسار: ${image.filePath} · الترتيب: ${image.sortOrder}'
                : 'Path: ${image.filePath} · Sort order: ${image.sortOrder}',
          ),
          trailing: canManage
              ? IconButton(
                  tooltip: l10n.isArabic ? 'حذف الملف' : 'Delete file',
                  onPressed: () =>
                      _confirmDeleteUnitImage(context, ref, unitId, image),
                  icon: const Icon(Icons.delete_outline),
                )
              : null,
        ),
      ],
    );
  }
}

Future<void> _showUnitEditor(
  BuildContext context,
  WidgetRef ref, {
  UnitDetail? initial,
}) async {
  final l10n = context.l10n;
  final catalog = await ref.read(unitAmenitiesCatalogProvider.future);
  if (!context.mounted) {
    return;
  }
  final codeController = TextEditingController(text: initial?.code ?? '');
  final nameController = TextEditingController(text: initial?.name ?? '');
  final cityController = TextEditingController(text: initial?.city ?? '');
  final countryController = TextEditingController(
    text: initial?.country ?? (l10n.isArabic ? 'المملكة العربية السعودية' : 'Saudi Arabia'),
  );
  final nightlyRateController = TextEditingController(
    text: (initial?.nightlyRate ?? 0).toStringAsFixed(0),
  );
  final monthlyRateController = TextEditingController(
    text: (initial?.monthlyRate ?? 0).toStringAsFixed(0),
  );
  final monthlyDepreciationController = TextEditingController(
    text: (initial?.monthlyDepreciation ?? 0).toStringAsFixed(0),
  );
  final capacityController = TextEditingController(
    text: '${initial?.capacity ?? 1}',
  );
  final bedroomsController = TextEditingController(
    text: '${initial?.bedrooms ?? 1}',
  );
  final bathroomsController = TextEditingController(
    text: '${initial?.bathrooms ?? 1}',
  );
  final smartLockController = TextEditingController(
    text: initial?.smartLockCodeEncrypted ?? '',
  );
  final formKey = GlobalKey<FormState>();
  final selectedAmenities =
      initial?.amenities.map((amenity) => amenity.code).toSet() ?? <String>{};
  var selectedStatus = initial?.status ?? 'ready';
  var isActive = initial?.isActive ?? true;
  String? createdUnitId;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(
                initial == null
                    ? (l10n.isArabic ? 'إضافة وحدة' : 'Add unit')
                    : (l10n.isArabic ? 'تعديل الوحدة' : 'Edit unit'),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: codeController,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'الرمز' : 'Code',
                          ),
                          enabled: initial == null,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? (l10n.isArabic
                                    ? 'هذا الحقل مطلوب'
                                    : 'This field is required')
                              : null,
                        ),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'الاسم' : 'Name',
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? (l10n.isArabic
                                    ? 'هذا الحقل مطلوب'
                                    : 'This field is required')
                              : null,
                        ),
                        TextFormField(
                          controller: cityController,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'المدينة' : 'City',
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? (l10n.isArabic
                                    ? 'هذا الحقل مطلوب'
                                    : 'This field is required')
                              : null,
                        ),
                        TextFormField(
                          controller: countryController,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'الدولة' : 'Country',
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'الحالة' : 'Status',
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'ready',
                              child: Text(l10n.unitStatus('ready')),
                            ),
                            DropdownMenuItem(
                              value: 'occupied',
                              child: Text(l10n.unitStatus('occupied')),
                            ),
                            DropdownMenuItem(
                              value: 'pending_cleaning',
                              child: Text(l10n.unitStatus('pending_cleaning')),
                            ),
                            DropdownMenuItem(
                              value: 'maintenance',
                              child: Text(l10n.unitStatus('maintenance')),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedStatus = value);
                            }
                          },
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: nightlyRateController,
                                decoration: InputDecoration(
                                  labelText: l10n.isArabic
                                      ? 'السعر الليلي'
                                      : 'Nightly rate',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: monthlyRateController,
                                decoration: InputDecoration(
                                  labelText: l10n.isArabic
                                      ? 'السعر الشهري'
                                      : 'Monthly rate',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: monthlyDepreciationController,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic
                                ? 'الإهلاك الشهري'
                                : 'Monthly depreciation',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: capacityController,
                                decoration: InputDecoration(
                                  labelText: l10n.isArabic
                                      ? 'السعة'
                                      : 'Capacity',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: bedroomsController,
                                decoration: InputDecoration(
                                  labelText: l10n.isArabic
                                      ? 'غرف النوم'
                                      : 'Bedrooms',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: bathroomsController,
                                decoration: InputDecoration(
                                  labelText: l10n.isArabic
                                      ? 'الحمامات'
                                      : 'Bathrooms',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: smartLockController,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic
                                ? 'رمز القفل الذكي'
                                : 'Smart lock code',
                          ),
                        ),
                        SwitchListTile(
                          value: isActive,
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.active),
                          onChanged: (value) =>
                              setState(() => isActive = value),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.isArabic ? 'المرافق' : 'Amenities',
                          style: Theme.of(dialogContext).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final amenity in catalog)
                              FilterChip(
                                label: Text(
                                  _amenityLabel(dialogContext, amenity.name),
                                ),
                                selected: selectedAmenities.contains(
                                  amenity.code,
                                ),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedAmenities.add(amenity.code);
                                    } else {
                                      selectedAmenities.remove(amenity.code);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
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
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    final backendApi = ref.read(backendApiProvider);
                    final payload = <String, dynamic>{
                      'code': codeController.text.trim(),
                      'name': nameController.text.trim(),
                      'city': cityController.text.trim(),
                      'country': countryController.text.trim(),
                      'status': selectedStatus,
                      'nightly_rate':
                          double.tryParse(nightlyRateController.text.trim()) ??
                          0,
                      'monthly_rate':
                          double.tryParse(monthlyRateController.text.trim()) ??
                          0,
                        'monthly_depreciation':
                          double.tryParse(
                          monthlyDepreciationController.text.trim(),
                          ) ??
                          0,
                      'capacity':
                          int.tryParse(capacityController.text.trim()) ?? 1,
                      'bedrooms':
                          int.tryParse(bedroomsController.text.trim()) ?? 1,
                      'bathrooms':
                          int.tryParse(bathroomsController.text.trim()) ?? 1,
                      'smart_lock_code_encrypted':
                          smartLockController.text.trim().isEmpty
                          ? null
                          : smartLockController.text.trim(),
                      'is_active': isActive,
                    };

                    if (initial == null) {
                      final created = await backendApi.createUnit({
                        ...payload,
                        'amenity_codes': selectedAmenities.toList()..sort(),
                        'images': const <Map<String, dynamic>>[],
                      });
                      createdUnitId = created.id;
                    } else {
                      await backendApi.updateUnit(initial.id, payload);
                      await backendApi.updateUnitAmenities(
                        initial.id,
                        selectedAmenities.toList()..sort(),
                      );
                    }

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
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
    codeController.dispose();
    nameController.dispose();
    cityController.dispose();
    countryController.dispose();
    nightlyRateController.dispose();
    monthlyRateController.dispose();
    monthlyDepreciationController.dispose();
    capacityController.dispose();
    bedroomsController.dispose();
    bathroomsController.dispose();
    smartLockController.dispose();
  }

  ref.invalidate(unitsProvider);
  if (initial != null) {
    ref.invalidate(unitDetailProvider(initial.id));
  }
  if (createdUnitId != null && context.mounted) {
    context.go('/app/units/$createdUnitId');
  }
}

Future<void> _showCreateBookingDialog(
  BuildContext context,
  WidgetRef ref,
  UnitDetail unit,
) async {
  final l10n = context.l10n;
  final guestNameController = TextEditingController();
  final guestPhoneController = TextEditingController();
  final totalAmountController = TextEditingController(
    text: unit.nightlyRate.toStringAsFixed(0),
  );
  final guestCountController = TextEditingController(text: '1');
  final formKey = GlobalKey<FormState>();
  final now = DateTime.now();
  final initialCheckIn = DateTime(now.year, now.month, now.day + 1, 14);
  var checkInAt = initialCheckIn;
  var checkOutAt = DateTime(
    initialCheckIn.year,
    initialCheckIn.month,
    initialCheckIn.day + 1,
    11,
  );
  String? errorMessage;
  String? createdBookingId;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            Future<void> pickBookingDate({required bool isCheckIn}) async {
              final selectedDate = await showDatePicker(
                context: dialogContext,
                initialDate: isCheckIn ? checkInAt : checkOutAt,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: DateTime(now.year + 2),
              );
              if (selectedDate == null) {
                return;
              }
              setState(() {
                if (isCheckIn) {
                  checkInAt = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    14,
                  );
                  if (!checkOutAt.isAfter(checkInAt)) {
                    checkOutAt = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day + 1,
                      11,
                    );
                  }
                } else {
                  checkOutAt = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    11,
                  );
                }
                errorMessage = null;
              });
            }

            return AlertDialog(
              title: Text(
                l10n.isArabic
                    ? 'حجز ${unit.code} · ${unit.name}'
                    : 'Book ${unit.code} · ${unit.name}',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: guestNameController,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic
                                ? 'اسم الضيف'
                                : 'Guest name',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? (l10n.isArabic
                                    ? 'هذا الحقل مطلوب'
                                    : 'This field is required')
                              : null,
                        ),
                        TextFormField(
                          controller: guestPhoneController,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic
                                ? 'رقم الهاتف'
                                : 'Phone number',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? (l10n.isArabic
                                    ? 'هذا الحقل مطلوب'
                                    : 'This field is required')
                              : null,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: guestCountController,
                                decoration: InputDecoration(
                                  labelText: l10n.isArabic
                                      ? 'عدد الضيوف'
                                      : 'Guests',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: totalAmountController,
                                decoration: InputDecoration(
                                  labelText: l10n.isArabic
                                      ? 'إجمالي الحجز'
                                      : 'Booking total',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l10n.isArabic ? 'تاريخ الدخول' : 'Check-in',
                          ),
                          subtitle: Text(l10n.formatDateTime(checkInAt)),
                          trailing: OutlinedButton(
                            onPressed: () => pickBookingDate(isCheckIn: true),
                            child: Text(l10n.isArabic ? 'اختيار' : 'Choose'),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l10n.isArabic ? 'تاريخ الخروج' : 'Check-out',
                          ),
                          subtitle: Text(l10n.formatDateTime(checkOutAt)),
                          trailing: OutlinedButton(
                            onPressed: () => pickBookingDate(isCheckIn: false),
                            child: Text(l10n.isArabic ? 'اختيار' : 'Choose'),
                          ),
                        ),
                        if (errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Theme.of(dialogContext).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
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
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    if (!checkOutAt.isAfter(checkInAt)) {
                      setState(() {
                        errorMessage = l10n.isArabic
                            ? 'يجب أن يكون الخروج بعد الدخول.'
                            : 'Check-out must be after check-in.';
                      });
                      return;
                    }
                    try {
                      final createdBooking = await ref
                          .read(backendApiProvider)
                          .createBooking(
                            unitId: unit.id,
                            clientName: guestNameController.text.trim(),
                            clientPhone: guestPhoneController.text.trim(),
                            checkInAt: checkInAt,
                            checkOutAt: checkOutAt,
                            guestCount:
                                int.tryParse(guestCountController.text.trim()) ?? 1,
                            totalAmount:
                                double.tryParse(totalAmountController.text.trim()) ??
                                unit.nightlyRate,
                          );
                      createdBookingId = createdBooking.id;
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (error) {
                      setState(() => errorMessage = '$error');
                    }
                  },
                  child: Text(l10n.create),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    guestNameController.dispose();
    guestPhoneController.dispose();
    totalAmountController.dispose();
    guestCountController.dispose();
  }

  if (createdBookingId == null) {
    return;
  }

  ref.invalidate(unitsProvider);
  ref.invalidate(unitDetailProvider(unit.id));
  ref.invalidate(unitBookingsProvider(unit.id));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.isArabic
              ? 'تم إنشاء الحجز وتحويل الوحدة إلى حالة محجوزة.'
              : 'The booking was created and the unit moved to reserved.',
        ),
      ),
    );
    context.go('/app/bookings/$createdBookingId');
  }
}

Future<void> _showCreateHousekeepingDialog(
  BuildContext context,
  WidgetRef ref,
  UnitDetail unit,
) async {
  final l10n = context.l10n;
  final assignees = await ref
      .read(backendApiProvider)
      .fetchHousekeepingAssignees(unitId: unit.id);
  if (!context.mounted) {
    return;
  }
  final notesController = TextEditingController();
  var selectedPriority = 'normal';
  var selectedAssignee = _allAssigneesValue;
  var created = false;
  String? errorMessage;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(
                l10n.isArabic
                    ? 'أمر تنظيف لـ ${unit.code} · ${unit.name}'
                    : 'Cleaning order for ${unit.code} · ${unit.name}',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedPriority,
                        decoration: InputDecoration(
                          labelText: l10n.isArabic ? 'الأولوية' : 'Priority',
                        ),
                        items: const ['low', 'normal', 'high', 'urgent']
                            .map(
                              (priority) => DropdownMenuItem(
                                value: priority,
                                child: Text(l10n.priorityLabel(priority)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedPriority = value);
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedAssignee,
                        decoration: InputDecoration(
                          labelText: l10n.isArabic ? 'الإسناد' : 'Assignment',
                        ),
                        items: [
                          DropdownMenuItem(
                            value: _allAssigneesValue,
                            child: Text(
                              l10n.isArabic
                                  ? 'لجميع فريق النظافة في الوحدة'
                                  : 'All housekeeping staff on this unit',
                            ),
                          ),
                          ...assignees.map(
                            (assignee) => DropdownMenuItem(
                              value: assignee.id,
                              child: Text(_assignmentTargetLabel(dialogContext, assignee)),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedAssignee = value);
                          }
                        },
                      ),
                      TextField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: l10n.isArabic ? 'ملاحظات' : 'Notes',
                        ),
                      ),
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            errorMessage!,
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
                    try {
                      await ref.read(backendApiProvider).createHousekeepingTask(
                        unitId: unit.id,
                        priority: selectedPriority,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                        assignedUserId: _selectedAssignedUserId(
                          assignees,
                          selectedAssignee,
                        ),
                        assignedTeamId: _selectedAssignedTeamId(
                          assignees,
                          selectedAssignee,
                        ),
                      );
                      created = true;
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (error) {
                      setState(() => errorMessage = '$error');
                    }
                  },
                  child: Text(l10n.create),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    notesController.dispose();
  }

  if (!created) {
    return;
  }

  ref.invalidate(unitsProvider);
  ref.invalidate(unitDetailProvider(unit.id));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.isArabic
              ? 'تم إنشاء أمر النظافة.'
              : 'The cleaning order was created.',
        ),
      ),
    );
  }
}

Future<void> _showAssignHousekeepingDialog(
  BuildContext context,
  WidgetRef ref,
  UnitDetail unit,
) async {
  final l10n = context.l10n;
  final backendApi = ref.read(backendApiProvider);
  final tasks = (await backendApi.fetchHousekeepingTasks())
      .where((task) => task.unitId == unit.id && task.status != 'completed')
      .toList();
  final assignees = await backendApi.fetchHousekeepingAssignees(unitId: unit.id);
  if (!context.mounted) {
    return;
  }
  if (tasks.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.isArabic
              ? 'لا توجد أوامر تنظيف مفتوحة لهذه الوحدة حالياً.'
              : 'There are no open cleaning orders for this unit right now.',
        ),
      ),
    );
    return;
  }
  var selectedTaskId = tasks.first.id;
  var selectedAssignee = _assignmentSelectionValue(
    userId: tasks.first.assignedUserId,
    teamId: tasks.first.assignedTeamId,
  );
  var updated = false;
  String? errorMessage;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(
              l10n.isArabic ? 'إسناد أمر تنظيف' : 'Assign cleaning order',
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedTaskId,
                    decoration: InputDecoration(
                      labelText: l10n.isArabic ? 'الأمر' : 'Order',
                    ),
                    items: tasks
                        .map(
                          (task) => DropdownMenuItem(
                            value: task.id,
                            child: Text(
                              '${l10n.priorityLabel(task.priority)} · ${task.notes ?? (l10n.isArabic ? 'بدون ملاحظات' : 'No notes')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      final selectedTask = tasks.firstWhere(
                        (task) => task.id == value,
                      );
                      setState(() {
                        selectedTaskId = value;
                        selectedAssignee = _assignmentSelectionValue(
                          userId: selectedTask.assignedUserId,
                          teamId: selectedTask.assignedTeamId,
                        );
                      });
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: selectedAssignee,
                    decoration: InputDecoration(
                      labelText: l10n.isArabic ? 'إلى' : 'Assign to',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _allAssigneesValue,
                        child: Text(
                          l10n.isArabic
                              ? 'الجميع في هذه الوحدة'
                              : 'Everyone on this unit',
                        ),
                      ),
                      ...assignees.map(
                        (assignee) => DropdownMenuItem(
                          value: assignee.id,
                          child: Text(_assignmentTargetLabel(dialogContext, assignee)),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedAssignee = value);
                      }
                    },
                  ),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await backendApi.assignHousekeepingTask(
                      selectedTaskId,
                      assignedUserId: _selectedAssignedUserId(
                        assignees,
                        selectedAssignee,
                      ),
                      assignedTeamId: _selectedAssignedTeamId(
                        assignees,
                        selectedAssignee,
                      ),
                    );
                    updated = true;
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } catch (error) {
                    setState(() => errorMessage = '$error');
                  }
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      );
    },
  );

  if (!updated) {
    return;
  }

  ref.invalidate(unitsProvider);
  ref.invalidate(unitDetailProvider(unit.id));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.isArabic
              ? 'تم تحديث إسناد أمر النظافة.'
              : 'The cleaning assignment was updated.',
        ),
      ),
    );
  }
}

Future<void> _showCreateMaintenanceDialog(
  BuildContext context,
  WidgetRef ref,
  UnitDetail unit,
) async {
  final l10n = context.l10n;
  final assignees = await ref
      .read(backendApiProvider)
      .fetchMaintenanceAssignees(unitId: unit.id);
  if (!context.mounted) {
    return;
  }
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var selectedPriority = 'normal';
  var selectedAssignee = _allAssigneesValue;
  var created = false;
  String? errorMessage;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(
                l10n.isArabic
                    ? 'تذكرة صيانة لـ ${unit.code} · ${unit.name}'
                    : 'Maintenance ticket for ${unit.code} · ${unit.name}',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'العنوان' : 'Title',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? (l10n.isArabic
                                    ? 'هذا الحقل مطلوب'
                                    : 'This field is required')
                              : null,
                        ),
                        TextField(
                          controller: descriptionController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'الوصف' : 'Description',
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: selectedPriority,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'الأولوية' : 'Priority',
                          ),
                          items: const ['low', 'normal', 'high', 'urgent']
                              .map(
                                (priority) => DropdownMenuItem(
                                  value: priority,
                                  child: Text(l10n.priorityLabel(priority)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedPriority = value);
                            }
                          },
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: selectedAssignee,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'الإسناد' : 'Assignment',
                          ),
                          items: [
                            DropdownMenuItem(
                              value: _allAssigneesValue,
                              child: Text(
                                l10n.isArabic
                                    ? 'لجميع فريق الصيانة في الوحدة'
                                    : 'All maintenance staff on this unit',
                              ),
                            ),
                            ...assignees.map(
                              (assignee) => DropdownMenuItem(
                                value: assignee.id,
                                child: Text(
                                  _assignmentTargetLabel(dialogContext, assignee),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedAssignee = value);
                            }
                          },
                        ),
                        if (errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(
                                color: Theme.of(dialogContext).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
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
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    try {
                      await ref.read(backendApiProvider).createMaintenanceTicket(
                        unitId: unit.id,
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        priority: selectedPriority,
                        assignedUserId: _selectedAssignedUserId(
                          assignees,
                          selectedAssignee,
                        ),
                        assignedTeamId: _selectedAssignedTeamId(
                          assignees,
                          selectedAssignee,
                        ),
                      );
                      created = true;
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (error) {
                      setState(() => errorMessage = '$error');
                    }
                  },
                  child: Text(l10n.create),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    titleController.dispose();
    descriptionController.dispose();
  }

  if (!created) {
    return;
  }

  ref.invalidate(unitsProvider);
  ref.invalidate(unitDetailProvider(unit.id));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.isArabic
              ? 'تم إنشاء تذكرة الصيانة.'
              : 'The maintenance ticket was created.',
        ),
      ),
    );
  }
}

Future<void> _showAssignMaintenanceDialog(
  BuildContext context,
  WidgetRef ref,
  UnitDetail unit,
) async {
  final l10n = context.l10n;
  final backendApi = ref.read(backendApiProvider);
  final tickets = (await backendApi.fetchMaintenanceTickets())
      .where((ticket) => ticket.unitId == unit.id && ticket.status != 'resolved')
      .toList();
  final assignees = await backendApi.fetchMaintenanceAssignees(unitId: unit.id);
  if (!context.mounted) {
    return;
  }
  if (tickets.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.isArabic
              ? 'لا توجد تذاكر صيانة مفتوحة لهذه الوحدة حالياً.'
              : 'There are no open maintenance tickets for this unit right now.',
        ),
      ),
    );
    return;
  }
  var selectedTicketId = tickets.first.id;
  var selectedAssignee = _assignmentSelectionValue(
    userId: tickets.first.assignedUserId,
    teamId: tickets.first.assignedTeamId,
  );
  var updated = false;
  String? errorMessage;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(
              l10n.isArabic ? 'إسناد تذكرة صيانة' : 'Assign maintenance ticket',
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedTicketId,
                    decoration: InputDecoration(
                      labelText: l10n.isArabic ? 'التذكرة' : 'Ticket',
                    ),
                    items: tickets
                        .map(
                          (ticket) => DropdownMenuItem(
                            value: ticket.id,
                            child: Text(
                              '${ticket.title} · ${l10n.priorityLabel(ticket.priority)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      final selectedTicket = tickets.firstWhere(
                        (ticket) => ticket.id == value,
                      );
                      setState(() {
                        selectedTicketId = value;
                        selectedAssignee = _assignmentSelectionValue(
                          userId: selectedTicket.assignedUserId,
                          teamId: selectedTicket.assignedTeamId,
                        );
                      });
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: selectedAssignee,
                    decoration: InputDecoration(
                      labelText: l10n.isArabic ? 'إلى' : 'Assign to',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _allAssigneesValue,
                        child: Text(
                          l10n.isArabic
                              ? 'الجميع في هذه الوحدة'
                              : 'Everyone on this unit',
                        ),
                      ),
                      ...assignees.map(
                        (assignee) => DropdownMenuItem(
                          value: assignee.id,
                          child: Text(_assignmentTargetLabel(dialogContext, assignee)),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedAssignee = value);
                      }
                    },
                  ),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await backendApi.assignMaintenanceTicket(
                      selectedTicketId,
                      assignedUserId: _selectedAssignedUserId(
                        assignees,
                        selectedAssignee,
                      ),
                      assignedTeamId: _selectedAssignedTeamId(
                        assignees,
                        selectedAssignee,
                      ),
                    );
                    updated = true;
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } catch (error) {
                    setState(() => errorMessage = '$error');
                  }
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      );
    },
  );

  if (!updated) {
    return;
  }

  ref.invalidate(unitsProvider);
  ref.invalidate(unitDetailProvider(unit.id));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.isArabic
              ? 'تم تحديث إسناد تذكرة الصيانة.'
              : 'The maintenance assignment was updated.',
        ),
      ),
    );
  }
}

Future<void> _showAddImageDialog(
  BuildContext context,
  WidgetRef ref,
  String unitId,
) async {
  final l10n = context.l10n;
  final sortOrderController = TextEditingController(text: '0');
  var isCover = false;
  PlatformFile? selectedFile;
  String? validationMessage;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(
                l10n.isArabic
                    ? 'رفع ملف أو صورة للوحدة'
                    : 'Upload a file or image for the unit',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: false,
                        withData: true,
                        type: FileType.any,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setState(() {
                          selectedFile = result.files.single;
                          validationMessage = null;
                        });
                      }
                    },
                    icon: const Icon(Icons.attach_file_outlined),
                    label: Text(
                      selectedFile == null
                          ? (l10n.isArabic ? 'اختيار ملف' : 'Choose file')
                          : (l10n.isArabic ? 'تغيير الملف' : 'Change file'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (selectedFile != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(selectedFile!.name),
                      subtitle: Text(
                        '${selectedFile!.size} ${l10n.isArabic ? 'بايت' : 'bytes'}',
                      ),
                    )
                  else
                    Text(
                      l10n.isArabic
                          ? 'لم يتم اختيار أي ملف بعد.'
                          : 'No file has been selected yet.',
                    ),
                  TextField(
                    controller: sortOrderController,
                    decoration: InputDecoration(
                      labelText: l10n.isArabic ? 'الترتيب' : 'Sort order',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SwitchListTile(
                    value: isCover,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.isArabic
                          ? 'استخدامها كصورة غلاف'
                          : 'Use as cover image',
                    ),
                    onChanged: (value) => setState(() => isCover = value),
                  ),
                  if (validationMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        validationMessage!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    if (selectedFile == null) {
                      setState(
                        () => validationMessage = l10n.isArabic
                            ? 'اختر ملفاً أولاً.'
                            : 'Choose a file first.',
                      );
                      return;
                    }
                    await ref
                        .read(backendApiProvider)
                        .uploadUnitImage(
                          unitId,
                          selectedFile!,
                          isCover: isCover,
                          sortOrder:
                              int.tryParse(sortOrderController.text.trim()) ??
                              0,
                        );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(l10n.upload),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    sortOrderController.dispose();
  }

  ref.invalidate(unitsProvider);
  ref.invalidate(unitDetailProvider(unitId));
}

Future<void> _confirmDeleteUnitImage(
  BuildContext context,
  WidgetRef ref,
  String unitId,
  UnitImageAsset image,
) async {
  final l10n = context.l10n;
  final shouldDelete =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.isArabic ? 'حذف الملف' : 'Delete file'),
          content: Text(
            l10n.isArabic
                ? 'سيتم حذف ${image.displayName} نهائياً من التخزين المحلي.'
                : '${image.displayName} will be deleted permanently from local storage.',
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
      ) ??
      false;

  if (!shouldDelete) {
    return;
  }

  await ref.read(backendApiProvider).deleteUnitImage(unitId, image.id);
  ref.invalidate(unitsProvider);
  ref.invalidate(unitDetailProvider(unitId));
}

Future<void> _confirmDeactivateUnit(
  BuildContext context,
  WidgetRef ref,
  String unitId,
) async {
  final l10n = context.l10n;
  final shouldDeactivate =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            l10n.isArabic ? 'تعطيل الوحدة' : 'Deactivate unit',
          ),
          content: Text(
            l10n.isArabic
                ? 'سيتم إخفاء الوحدة من القائمة النشطة مع الاحتفاظ ببياناتها الحالية.'
                : 'The unit will be hidden from the active list while keeping its current data intact.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.deactivate),
            ),
          ],
        ),
      ) ??
      false;

  if (!shouldDeactivate) {
    return;
  }

  await ref.read(backendApiProvider).deactivateUnit(unitId);
  ref.invalidate(unitsProvider);
  ref.invalidate(unitDetailProvider(unitId));
  if (context.mounted) {
    context.go('/app/units');
  }
}

String _amenityLabel(BuildContext context, String value) {
  final l10n = context.l10n;
  switch (value) {
    case 'wifi':
    case 'Wi-Fi':
      return l10n.isArabic ? 'واي فاي' : 'Wi-Fi';
    case 'smart_lock':
    case 'Smart Lock':
      return l10n.isArabic ? 'قفل ذكي' : 'Smart lock';
    case 'parking':
    case 'Parking':
      return l10n.isArabic ? 'موقف سيارات' : 'Parking';
    case 'balcony':
    case 'Balcony':
      return l10n.isArabic ? 'شرفة' : 'Balcony';
    default:
      return value.replaceAll('_', ' ');
  }
}
