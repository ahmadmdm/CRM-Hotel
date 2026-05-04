import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/backend_api_service.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../design_system/components/kpi_card.dart';

final reportsProvider = FutureProvider<DashboardKpis>((ref) async {
  return ref.read(backendApiProvider).fetchReportsSummary();
});

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(reportsProvider);

    return summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          title: l10n.isArabic ? 'تعذر تحميل التقارير' : 'Unable to load reports',
          subtitle: '$error',
          onRetry: () => ref.invalidate(reportsProvider),
        ),
      ),
      data: (data) => ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.isArabic ? 'قراءة تنفيذية' : 'Executive Readout',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.isArabic
                        ? 'ملخص سريع للقدرة التشغيلية، حركة الإيراد، ومناطق الانتباه قبل مراجعة التفاصيل اليومية.'
                        : 'A quick readout of operational capacity, revenue movement, and attention zones before the daily deep dive.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 1024 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.28,
            children: [
              KpiCard(
                label: l10n.isArabic ? 'الإيراد' : 'Revenue',
                value: l10n.formatCurrency(data.totalRevenue),
                accentColor: AppColors.clay,
              ),
              KpiCard(
                label: l10n.isArabic ? 'المصروفات' : 'Expenses',
                value: l10n.formatCurrency(data.totalExpenses),
                accentColor: AppColors.rose,
              ),
              KpiCard(
                label: l10n.isArabic ? 'التذاكر المفتوحة' : 'Open Tickets',
                value: l10n.formatNumber(data.openTickets),
                accentColor: AppColors.sky,
              ),
              KpiCard(
                label: l10n.isArabic ? 'الإشغال' : 'Occupancy',
                value: l10n.formatPercent(data.occupancyRate),
                accentColor: AppColors.pine,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _ReportFact(
                    label: l10n.isArabic
                        ? 'الحجوزات النشطة'
                        : 'Active bookings',
                    value: l10n.formatNumber(data.activeBookings),
                  ),
                  _ReportFact(
                    label: l10n.isArabic
                        ? 'بانتظار التنظيف'
                        : 'Pending cleaning',
                    value: l10n.formatNumber(data.pendingCleaning),
                  ),
                  _ReportFact(
                    label: l10n.isArabic
                        ? 'الوحدات المشغولة'
                        : 'Occupied units',
                    value: l10n.formatNumber(data.occupiedUnits),
                  ),
                  _ReportFact(
                    label: l10n.isArabic ? 'إجمالي الوحدات' : 'Total units',
                    value: l10n.formatNumber(data.totalUnits),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportFact extends StatelessWidget {
  const _ReportFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
