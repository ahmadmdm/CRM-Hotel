import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/backend_api_service.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../design_system/components/kpi_card.dart';

final dashboardProvider = FutureProvider<DashboardKpis>((ref) async {
  return ref.read(backendApiProvider).fetchDashboard();
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dashboard = ref.watch(dashboardProvider);
    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          title: l10n.isArabic
              ? 'تعذر تحميل لوحة القيادة'
              : 'Unable to load the dashboard',
          subtitle: '$error',
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
      ),
      data: (data) {
        final needsAttention = <String>[
          if (data.pendingCleaning > 0)
            l10n.isArabic
                ? '${l10n.formatNumber(data.pendingCleaning)} وحدات تحتاج متابعة الإشراف الفندقي.'
                : '${l10n.formatNumber(data.pendingCleaning)} units need housekeeping follow-up.',
          if (data.openTickets > 0)
            l10n.isArabic
                ? '${l10n.formatNumber(data.openTickets)} تذاكر صيانة ما زالت مفتوحة.'
                : '${l10n.formatNumber(data.openTickets)} maintenance tickets are still open.',
          if (data.totalExpenses > data.totalRevenue)
            l10n.isArabic
                ? 'المصروفات الحالية أعلى من الإيراد المسجل.'
                : 'Current expenses are higher than recorded revenue.',
        ];

        return ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.midnight,
                    Color(0xFF243B72),
                    AppColors.sky,
                  ],
                ),
              ),
              child: Wrap(
                spacing: 24,
                runSpacing: 24,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 460,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                          child: Text(
                            l10n.isArabic
                                ? 'ملخص تنفيذي فوري'
                                : 'Executive Snapshot',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          l10n.isArabic
                              ? 'رؤية قيادة أكثر حدة للإشغال والإيراد ونقاط التعثر التشغيلي.'
                              : 'A sharper command view for occupancy, revenue, and operational drag.',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.isArabic
                              ? 'تابع صحة التشغيل لحظياً وحدد أين يجب أن يتدخل الفريق الإداري أو التشغيلي في اللحظة التالية.'
                              : 'Track operational health live and identify where leadership or field teams should intervene next.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _HeroStat(
                        label: l10n.isArabic ? 'الإشغال' : 'Occupancy',
                        value: l10n.formatPercent(data.occupancyRate),
                      ),
                      _HeroStat(
                        label: l10n.isArabic ? 'الإيراد' : 'Revenue',
                        value: l10n.formatCurrency(data.totalRevenue),
                      ),
                      _HeroStat(
                        label: l10n.isArabic ? 'الحجوزات' : 'Bookings',
                        value: l10n.formatNumber(data.activeBookings),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width >= 1024 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.18,
              children: [
                KpiCard(
                  label: l10n.isArabic ? 'الإشغال' : 'Occupancy',
                  value: l10n.formatPercent(data.occupancyRate),
                  accentColor: AppColors.pine,
                ),
                KpiCard(
                  label: l10n.isArabic ? 'الإيراد' : 'Revenue',
                  value: l10n.formatCurrency(data.totalRevenue),
                  accentColor: AppColors.clay,
                ),
                KpiCard(
                  label: l10n.isArabic ? 'بانتظار التنظيف' : 'Pending Cleaning',
                  value: l10n.formatNumber(data.pendingCleaning),
                  accentColor: AppColors.amber,
                ),
                KpiCard(
                  label: l10n.isArabic ? 'التذاكر المفتوحة' : 'Open Tickets',
                  value: l10n.formatNumber(data.openTickets),
                  accentColor: AppColors.rose,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: MediaQuery.sizeOf(context).width >= 1024
                      ? 520
                      : double.infinity,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isArabic ? 'نبض التشغيل' : 'Operational Pulse',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 14),
                          _PulseRow(
                            label: l10n.isArabic ? 'الوحدات' : 'Units',
                            value: l10n.formatNumber(data.totalUnits),
                          ),
                          _PulseRow(
                            label: l10n.isArabic ? 'المشغولة' : 'Occupied',
                            value: l10n.formatNumber(data.occupiedUnits),
                          ),
                          _PulseRow(
                            label: l10n.isArabic
                                ? 'الحجوزات النشطة'
                                : 'Active bookings',
                            value: l10n.formatNumber(data.activeBookings),
                          ),
                          _PulseRow(
                            label: l10n.isArabic ? 'المصروفات' : 'Expenses',
                            value: l10n.formatCurrency(data.totalExpenses),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width >= 1024
                      ? 520
                      : double.infinity,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isArabic
                                ? 'إشارات الجاهزية'
                                : 'Readiness Signals',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 14),
                          if (needsAttention.isEmpty)
                            _ReadinessItem(
                              message: l10n.isArabic
                                  ? 'لا توجد إشارات حرجة حالياً. التوازن التشغيلي جيد.'
                                  : 'No critical signals right now. Operational balance looks healthy.',
                              color: AppColors.pine,
                            ),
                          for (final item in needsAttention)
                            _ReadinessItem(
                              message: item,
                              color: AppColors.rose,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.14),
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
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRow extends StatelessWidget {
  const _PulseRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ReadinessItem extends StatelessWidget {
  const _ReadinessItem({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fiber_manual_record, size: 12, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
