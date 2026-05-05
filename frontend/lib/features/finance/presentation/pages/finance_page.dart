import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/backend_api_service.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../design_system/components/kpi_card.dart';

enum _FinancePeriodOption { month, quarter, year }

extension on _FinancePeriodOption {
  String get apiValue {
    switch (this) {
      case _FinancePeriodOption.month:
        return 'month';
      case _FinancePeriodOption.quarter:
        return 'quarter';
      case _FinancePeriodOption.year:
        return 'year';
    }
  }
}

class _FinanceQuery {
  const _FinanceQuery({required this.period, required this.anchorDate});

  final _FinancePeriodOption period;
  final DateTime anchorDate;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _FinanceQuery &&
        other.period == period &&
        other.anchorDate.year == anchorDate.year &&
        other.anchorDate.month == anchorDate.month &&
        other.anchorDate.day == anchorDate.day;
  }

  @override
  int get hashCode =>
      Object.hash(period, anchorDate.year, anchorDate.month, anchorDate.day);
}

final financeProvider = FutureProvider.family<FinanceSnapshot, _FinanceQuery>((
  ref,
  query,
) async {
  return ref
      .read(backendApiProvider)
      .fetchFinance(
        period: query.period.apiValue,
        anchorDate: query.anchorDate,
      );
});

class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key});

  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage> {
  _FinancePeriodOption _period = _FinancePeriodOption.month;
  DateTime _anchorDate = DateTime.now();

  _FinanceQuery get _query => _FinanceQuery(
    period: _period,
    anchorDate: DateTime(_anchorDate.year, _anchorDate.month, 1),
  );

  void _refreshFinance() {
    ref.invalidate(financeProvider(_query));
  }

  void _shiftPeriod(int delta) {
    setState(() {
      switch (_period) {
        case _FinancePeriodOption.month:
          _anchorDate = DateTime(
            _anchorDate.year,
            _anchorDate.month + delta,
            1,
          );
        case _FinancePeriodOption.quarter:
          _anchorDate = DateTime(
            _anchorDate.year,
            _anchorDate.month + (delta * 3),
            1,
          );
        case _FinancePeriodOption.year:
          _anchorDate = DateTime(_anchorDate.year + delta, 1, 1);
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCreatePaymentDialog() async {
    final l10n = context.l10n;
    final api = ref.read(backendApiProvider);
    try {
      final bookings = await api.fetchBookings();
      final units = await api.fetchUnits();
      if (!mounted) {
        return;
      }
      if (bookings.isEmpty) {
        _showMessage(
          l10n.isArabic
              ? 'لا توجد حجوزات متاحة لتسجيل الإيراد.'
              : 'No bookings are available for revenue recording.',
        );
        return;
      }

      final unitsById = {for (final unit in units) unit.id: unit};
      var selectedBookingId = bookings.first.id;
      var method = 'cash';
      final amountController = TextEditingController();
      final referenceController = TextEditingController();
      var isSaving = false;

      final created = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final selectedBooking = bookings.firstWhere(
                (item) => item.id == selectedBookingId,
              );
              final selectedUnit = unitsById[selectedBooking.unitId];
              return AlertDialog(
                title: Text(
                  l10n.isArabic
                      ? 'تسجيل إيراد / دفعة'
                      : 'Record revenue / payment',
                ),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedBookingId,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'الحجز' : 'Booking',
                          ),
                          items: [
                            for (final booking in bookings)
                              DropdownMenuItem(
                                value: booking.id,
                                child: Text(
                                  '${booking.bookingReference} · ${booking.clientName}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setDialogState(
                                    () => selectedBookingId = value,
                                  );
                                },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          selectedUnit == null
                              ? ''
                              : '${selectedUnit.code} · ${selectedUnit.name}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: amountController,
                          enabled: !isSaving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'المبلغ' : 'Amount',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: method,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic
                                ? 'طريقة الدفع'
                                : 'Payment method',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text('Cash'),
                            ),
                            DropdownMenuItem(
                              value: 'card',
                              child: Text('Card'),
                            ),
                            DropdownMenuItem(
                              value: 'bank_transfer',
                              child: Text('Bank transfer'),
                            ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setDialogState(() => method = value);
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: referenceController,
                          enabled: !isSaving,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic
                                ? 'مرجع العملية'
                                : 'Reference',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: Text(l10n.isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final amount = double.tryParse(
                              amountController.text.trim(),
                            );
                            if (amount == null || amount <= 0) {
                              _showMessage(
                                l10n.isArabic
                                    ? 'أدخل مبلغًا صحيحًا أكبر من صفر.'
                                    : 'Enter a valid amount greater than zero.',
                              );
                              return;
                            }
                            setDialogState(() => isSaving = true);
                            try {
                              await api.createPayment(
                                bookingId: selectedBookingId,
                                amount: amount,
                                method: method,
                                referenceNo:
                                    referenceController.text.trim().isEmpty
                                    ? null
                                    : referenceController.text.trim(),
                              );
                              if (!dialogContext.mounted) {
                                return;
                              }
                              Navigator.of(dialogContext).pop(true);
                            } catch (error) {
                              if (!mounted) {
                                return;
                              }
                              setDialogState(() => isSaving = false);
                              _showMessage(_financeActionError(error, l10n));
                            }
                          },
                    child: Text(l10n.isArabic ? 'حفظ' : 'Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      amountController.dispose();
      referenceController.dispose();
      if (created == true && mounted) {
        _refreshFinance();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_financeActionError(error, l10n));
    }
  }

  Future<void> _showCreateExpenseDialog() async {
    final l10n = context.l10n;
    final api = ref.read(backendApiProvider);
    try {
      final units = await api.fetchUnits();
      if (!mounted) {
        return;
      }
      if (units.isEmpty) {
        _showMessage(
          l10n.isArabic ? 'لا توجد وحدات متاحة.' : 'No units are available.',
        );
        return;
      }

      var selectedUnitId = units.first.id;
      final categoryController = TextEditingController(text: 'maintenance');
      final descriptionController = TextEditingController();
      final amountController = TextEditingController();
      var isSaving = false;

      final created = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(
                  l10n.isArabic
                      ? 'تسجيل مصروف تشغيلي'
                      : 'Record operating expense',
                ),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedUnitId,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'الوحدة' : 'Unit',
                          ),
                          items: [
                            for (final unit in units)
                              DropdownMenuItem(
                                value: unit.id,
                                child: Text('${unit.code} · ${unit.name}'),
                              ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setDialogState(() => selectedUnitId = value);
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: categoryController,
                          enabled: !isSaving,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'الفئة' : 'Category',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          enabled: !isSaving,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'الوصف' : 'Description',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: amountController,
                          enabled: !isSaving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'المبلغ' : 'Amount',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: Text(l10n.isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final amount = double.tryParse(
                              amountController.text.trim(),
                            );
                            if (amount == null || amount <= 0) {
                              _showMessage(
                                l10n.isArabic
                                    ? 'أدخل مبلغًا صحيحًا أكبر من صفر.'
                                    : 'Enter a valid amount greater than zero.',
                              );
                              return;
                            }
                            final category = categoryController.text.trim();
                            if (category.isEmpty) {
                              _showMessage(
                                l10n.isArabic
                                    ? 'أدخل فئة المصروف.'
                                    : 'Enter an expense category.',
                              );
                              return;
                            }
                            setDialogState(() => isSaving = true);
                            try {
                              await api.createExpense(
                                unitId: selectedUnitId,
                                category: category,
                                amount: amount,
                                description:
                                    descriptionController.text.trim().isEmpty
                                    ? null
                                    : descriptionController.text.trim(),
                              );
                              if (!dialogContext.mounted) {
                                return;
                              }
                              Navigator.of(dialogContext).pop(true);
                            } catch (error) {
                              if (!mounted) {
                                return;
                              }
                              setDialogState(() => isSaving = false);
                              _showMessage(_financeActionError(error, l10n));
                            }
                          },
                    child: Text(l10n.isArabic ? 'حفظ' : 'Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      categoryController.dispose();
      descriptionController.dispose();
      amountController.dispose();
      if (created == true && mounted) {
        _refreshFinance();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_financeActionError(error, l10n));
    }
  }

  Future<void> _showCreateAssetDialog() async {
    final l10n = context.l10n;
    final api = ref.read(backendApiProvider);
    try {
      final units = await api.fetchUnits();
      if (!mounted) {
        return;
      }
      if (units.isEmpty) {
        _showMessage(
          l10n.isArabic ? 'لا توجد وحدات متاحة.' : 'No units are available.',
        );
        return;
      }

      var selectedUnitId = units.first.id;
      final nameController = TextEditingController();
      final categoryController = TextEditingController(text: 'equipment');
      final acquisitionController = TextEditingController();
      final residualController = TextEditingController(text: '0');
      final lifeController = TextEditingController(text: '12');
      final notesController = TextEditingController();
      var isSaving = false;

      final created = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(
                  l10n.isArabic
                      ? 'تسجيل أصل رأسمالي'
                      : 'Register capital asset',
                ),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedUnitId,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'الوحدة' : 'Unit',
                          ),
                          items: [
                            for (final unit in units)
                              DropdownMenuItem(
                                value: unit.id,
                                child: Text('${unit.code} · ${unit.name}'),
                              ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setDialogState(() => selectedUnitId = value);
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          enabled: !isSaving,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic
                                ? 'اسم الأصل'
                                : 'Asset name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: categoryController,
                          enabled: !isSaving,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'التصنيف' : 'Category',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: acquisitionController,
                          enabled: !isSaving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.isArabic
                                ? 'قيمة الشراء'
                                : 'Acquisition cost',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: residualController,
                          enabled: !isSaving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.isArabic
                                ? 'القيمة المتبقية'
                                : 'Residual value',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: lifeController,
                          enabled: !isSaving,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic
                                ? 'العمر بالأشهر'
                                : 'Useful life in months',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          enabled: !isSaving,
                          decoration: InputDecoration(
                            labelText: l10n.isArabic ? 'ملاحظات' : 'Notes',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: Text(l10n.isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final acquisition = double.tryParse(
                              acquisitionController.text.trim(),
                            );
                            final residual =
                                double.tryParse(
                                  residualController.text.trim(),
                                ) ??
                                0;
                            final usefulLife = int.tryParse(
                              lifeController.text.trim(),
                            );
                            if (nameController.text.trim().isEmpty ||
                                categoryController.text.trim().isEmpty ||
                                acquisition == null ||
                                acquisition <= 0 ||
                                usefulLife == null ||
                                usefulLife <= 0) {
                              _showMessage(
                                l10n.isArabic
                                    ? 'أكمل بيانات الأصل بقيم صحيحة.'
                                    : 'Complete the asset details with valid values.',
                              );
                              return;
                            }
                            setDialogState(() => isSaving = true);
                            try {
                              await api.createAsset(
                                unitId: selectedUnitId,
                                name: nameController.text.trim(),
                                category: categoryController.text.trim(),
                                acquisitionCost: acquisition,
                                residualValue: residual,
                                usefulLifeMonths: usefulLife,
                                notes: notesController.text.trim().isEmpty
                                    ? null
                                    : notesController.text.trim(),
                              );
                              if (!dialogContext.mounted) {
                                return;
                              }
                              Navigator.of(dialogContext).pop(true);
                            } catch (error) {
                              if (!mounted) {
                                return;
                              }
                              setDialogState(() => isSaving = false);
                              _showMessage(_financeActionError(error, l10n));
                            }
                          },
                    child: Text(l10n.isArabic ? 'حفظ' : 'Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      nameController.dispose();
      categoryController.dispose();
      acquisitionController.dispose();
      residualController.dispose();
      lifeController.dispose();
      notesController.dispose();
      if (created == true && mounted) {
        _refreshFinance();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_financeActionError(error, l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finance = ref.watch(financeProvider(_query));
    return finance.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          title: l10n.isArabic
              ? 'تعذر تحميل المالية'
              : 'Unable to load finance',
          subtitle: '$error',
          onRetry: _refreshFinance,
        ),
      ),
      data: (snapshot) {
        final totalPayments = snapshot.costCenters.fold<double>(
          0,
          (sum, item) => sum + item.revenue,
        );
        final totalExpenses = snapshot.costCenters.fold<double>(
          0,
          (sum, item) => sum + item.expenses,
        );
        final totalCapitalExpenditure = snapshot.costCenters.fold<double>(
          0,
          (sum, item) => sum + item.capitalExpenditure,
        );
        final totalDepreciation = snapshot.costCenters.fold<double>(
          0,
          (sum, item) => sum + item.depreciation,
        );
        final totalProfitLoss = snapshot.costCenters.fold<double>(
          0,
          (sum, item) => sum + item.profitLoss,
        );
        final screenWidth = MediaQuery.sizeOf(context).width;
        final crossAxisCount = screenWidth >= 1440
            ? 5
            : screenWidth >= 960
            ? 3
            : 1;
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.ink, AppColors.pine],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.isArabic
                        ? 'لوحة التدفق المالي'
                        : 'Financial flow deck',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.isArabic
                        ? 'راجع الإيراد والمصروف والإهلاك وصافي النتيجة لكل وحدة خلال الفترة المحددة.'
                        : 'Review revenue, expenses, depreciation, and net result for each unit in the selected period.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final period in _FinancePeriodOption.values)
                        ChoiceChip(
                          label: Text(_periodOptionLabel(context, period)),
                          selected: _period == period,
                          onSelected: (selected) {
                            if (!selected) {
                              return;
                            }
                            setState(() => _period = period);
                          },
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              color: Colors.white,
                              onPressed: () => _shiftPeriod(-1),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text(
                              _periodLabel(context, _period, _anchorDate),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              color: Colors.white,
                              onPressed: () => _shiftPeriod(1),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _showCreatePaymentDialog,
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(l10n.isArabic ? 'إيراد' : 'Revenue'),
                      ),
                      FilledButton.icon(
                        onPressed: _showCreateExpenseDialog,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: Text(l10n.isArabic ? 'مصروف' : 'Expense'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showCreateAssetDialog,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: Text(
                          l10n.isArabic ? 'أصل رأسمالي' : 'Capital asset',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.6,
              children: [
                KpiCard(
                  label: l10n.isArabic
                      ? 'الإيراد المحقق'
                      : 'Recognized revenue',
                  value: l10n.formatCurrency(totalPayments),
                  accentColor: AppColors.pine,
                ),
                KpiCard(
                  label: l10n.isArabic
                      ? 'المصروفات المباشرة'
                      : 'Direct expenses',
                  value: l10n.formatCurrency(totalExpenses),
                  accentColor: AppColors.amber,
                ),
                KpiCard(
                  label: l10n.isArabic
                      ? 'الإنفاق الرأسمالي'
                      : 'Capital expenditure',
                  value: l10n.formatCurrency(totalCapitalExpenditure),
                  accentColor: AppColors.sky,
                ),
                KpiCard(
                  label: l10n.isArabic ? 'إهلاك الفترة' : 'Period depreciation',
                  value: l10n.formatCurrency(totalDepreciation),
                  accentColor: AppColors.rose,
                ),
                KpiCard(
                  label: l10n.isArabic ? 'صافي المحفظة' : 'Portfolio net',
                  value: l10n.formatCurrency(totalProfitLoss),
                  accentColor: totalProfitLoss >= 0
                      ? AppColors.sky
                      : AppColors.rose,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      l10n.isArabic
                          ? 'مراكز التكلفة حسب الوحدة'
                          : 'Unit cost centers',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      l10n.isArabic
                          ? 'كل بطاقة تجمع الإيراد، التشغيل، الإنفاق الرأسمالي، والإهلاك للوحدة نفسها.'
                          : 'Each card rolls revenue, operating costs, capex, and depreciation into the same unit view.',
                    ),
                  ),
                  if (snapshot.costCenters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        l10n.isArabic
                            ? 'لا توجد وحدات ظاهرة ضمن النطاق المالي الحالي.'
                            : 'No units are visible within the current finance scope.',
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              l10n.isArabic
                                  ? 'سجل الأصول الرأسمالية'
                                  : 'Capital asset register',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              l10n.isArabic
                                  ? 'الأصول النشطة أو المسجلة ضمن الفترة المختارة مع أثر الإهلاك الخاص بها.'
                                  : 'Assets active in or registered within the selected period, along with their depreciation impact.',
                            ),
                          ),
                          if (snapshot.assets.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Text(
                                l10n.isArabic
                                    ? 'لا توجد أصول ضمن هذه الفترة.'
                                    : 'No assets were found for this period.',
                              ),
                            )
                          else
                            for (final asset in snapshot.assets)
                              ListTile(
                                title: Text(
                                  '${asset.unitCode} · ${asset.name}',
                                ),
                                subtitle: Text(
                                  [
                                    asset.category,
                                    _formatDate(context, asset.commissionedAt),
                                    l10n.isArabic
                                        ? '${asset.usefulLifeMonths} شهر'
                                        : '${asset.usefulLifeMonths} months',
                                  ].join(' • '),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      l10n.formatCurrency(
                                        asset.acquisitionCost,
                                        currencyCode: 'SAR',
                                      ),
                                    ),
                                    Text(
                                      l10n.isArabic
                                          ? 'إهلاك ${l10n.formatCurrency(asset.periodDepreciation)}'
                                          : 'Dep ${l10n.formatCurrency(asset.periodDepreciation)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final center in snapshot.costCenters)
                          _CostCenterCard(center: center),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      l10n.isArabic ? 'المدفوعات' : 'Payments',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final payment in snapshot.payments)
                    ListTile(
                      title: Text(
                        l10n.isArabic
                            ? 'دفعة · ${l10n.paymentMethodLabel(payment.method)}'
                            : 'Payment · ${l10n.paymentMethodLabel(payment.method)}',
                      ),
                      subtitle: Text(
                        [
                          if (payment.unitCode != null &&
                              payment.unitCode!.isNotEmpty)
                            '${payment.unitCode} · ${payment.unitName ?? ''}'
                                .trim(),
                          l10n.paymentStatus(payment.status),
                          _formatDate(context, payment.createdAt),
                        ].where((item) => item.isNotEmpty).join(' • '),
                      ),
                      trailing: Text(
                        l10n.formatCurrency(
                          payment.amount,
                          currencyCode: payment.currency,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      l10n.isArabic ? 'المصروفات' : 'Expenses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final expense in snapshot.expenses)
                    ListTile(
                      title: Text(
                        l10n.isArabic
                            ? 'مصروف · ${l10n.expenseCategoryLabel(expense.category)}'
                            : 'Expense · ${l10n.expenseCategoryLabel(expense.category)}',
                      ),
                      subtitle: Text(
                        [
                          if (expense.unitCode != null &&
                              expense.unitCode!.isNotEmpty)
                            '${expense.unitCode} · ${expense.unitName ?? ''}'
                                .trim(),
                          expense.description,
                          _formatDate(context, expense.createdAt),
                        ].where((item) => item.isNotEmpty).join(' • '),
                      ),
                      trailing: Text(
                        l10n.formatCurrency(
                          expense.amount,
                          currencyCode: expense.currency,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CostCenterCard extends StatelessWidget {
  const _CostCenterCard({required this.center});

  final UnitCostCenterSummary center;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPositive = center.profitLoss >= 0;
    return Container(
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isPositive
              ? [AppColors.pine.withValues(alpha: 0.14), Colors.white]
              : [AppColors.rose.withValues(alpha: 0.14), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${center.unitCode} · ${center.unitName}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(
                  isPositive
                      ? (l10n.isArabic ? 'مربحة' : 'Profitable')
                      : (l10n.isArabic ? 'تحت الضغط' : 'Under pressure'),
                ),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(
                  l10n.isArabic
                      ? '${center.paymentCount} دفعات'
                      : '${center.paymentCount} payments',
                ),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(
                  l10n.isArabic
                      ? '${center.assetCount} أصول'
                      : '${center.assetCount} assets',
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CostLine(
            label: l10n.isArabic ? 'الإيراد' : 'Revenue',
            value: l10n.formatCurrency(
              center.revenue,
              currencyCode: center.currency,
            ),
          ),
          _CostLine(
            label: l10n.isArabic ? 'المصروف' : 'Expenses',
            value: l10n.formatCurrency(
              center.expenses,
              currencyCode: center.currency,
            ),
          ),
          _CostLine(
            label: l10n.isArabic ? 'الإنفاق الرأسمالي' : 'Capital expenditure',
            value: l10n.formatCurrency(
              center.capitalExpenditure,
              currencyCode: center.currency,
            ),
          ),
          _CostLine(
            label: l10n.isArabic ? 'الإهلاك' : 'Depreciation',
            value: l10n.formatCurrency(
              center.depreciation,
              currencyCode: center.currency,
            ),
          ),
          const Divider(height: 20),
          _CostLine(
            label: l10n.isArabic ? 'صافي الربح/الخسارة' : 'Profit / Loss',
            value: l10n.formatCurrency(
              center.profitLoss,
              currencyCode: center.currency,
            ),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _CostLine extends StatelessWidget {
  const _CostLine({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

String _periodOptionLabel(BuildContext context, _FinancePeriodOption period) {
  final l10n = context.l10n;
  switch (period) {
    case _FinancePeriodOption.month:
      return l10n.isArabic ? 'شهري' : 'Monthly';
    case _FinancePeriodOption.quarter:
      return l10n.isArabic ? 'ربعي' : 'Quarterly';
    case _FinancePeriodOption.year:
      return l10n.isArabic ? 'سنوي' : 'Yearly';
  }
}

String _periodLabel(
  BuildContext context,
  _FinancePeriodOption period,
  DateTime anchorDate,
) {
  final l10n = context.l10n;
  switch (period) {
    case _FinancePeriodOption.month:
      return '${anchorDate.month.toString().padLeft(2, '0')}/${anchorDate.year}';
    case _FinancePeriodOption.quarter:
      final quarter = ((anchorDate.month - 1) ~/ 3) + 1;
      return l10n.isArabic
          ? 'الربع $quarter · ${anchorDate.year}'
          : 'Q$quarter · ${anchorDate.year}';
    case _FinancePeriodOption.year:
      return '${anchorDate.year}';
  }
}

String _formatDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatShortDate(date);
}

String _financeActionError(Object error, AppLocalizations l10n) {
  final message = error.toString();
  if (message.isEmpty) {
    return l10n.isArabic
        ? 'تعذر تنفيذ العملية المالية.'
        : 'Unable to complete the finance action.';
  }
  return message;
}
