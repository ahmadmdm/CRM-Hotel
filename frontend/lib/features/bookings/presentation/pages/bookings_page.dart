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
import '../../../units/presentation/pages/units_page.dart';

final bookingsProvider = FutureProvider<List<BookingSummary>>((ref) async {
  return ref.read(backendApiProvider).fetchBookings();
});

Color _bookingStatusColor(String status) {
  switch (status) {
    case 'pending':
      return Colors.blueGrey;
    case 'confirmed':
      return Colors.blue;
    case 'checked_in':
      return Colors.green;
    case 'checked_out':
      return Colors.orange;
    case 'no_show':
      return Colors.deepPurple;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

DateTime? _parseBookingDate(String value) => DateTime.tryParse(value);

String _bookingWindowLabel(BuildContext context, BookingSummary booking) {
  final l10n = context.l10n;
  final checkInAt = _parseBookingDate(booking.checkInAt);
  final checkOutAt = _parseBookingDate(booking.checkOutAt);
  if (checkInAt == null || checkOutAt == null) {
    return '${booking.checkInAt} → ${booking.checkOutAt}';
  }
  return l10n.formatDateRange(checkInAt, checkOutAt);
}

class _BookingSummaryDeck extends StatelessWidget {
  const _BookingSummaryDeck({required this.items});

  final List<BookingSummary> items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final confirmedCount = items.where((item) => item.status == 'confirmed').length;
    final activeStayCount = items.where((item) => item.status == 'checked_in').length;
    final completedCount = items.where((item) => item.status == 'checked_out').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.midnight, AppColors.sky],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.isArabic ? 'دورة حياة الحجوزات' : 'Booking lifecycle',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.isArabic
                ? 'من هنا تتابع التأكيد وتسجيل الدخول والخروج لكل حجز بصياغة واضحة.'
                : 'Track confirmation, check-in, and check-out from one clear lifecycle surface.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _BookingSummaryPill(
                label: l10n.isArabic ? 'الإجمالي' : 'Total',
                value: l10n.formatNumber(items.length),
              ),
              _BookingSummaryPill(
                label: l10n.isArabic ? 'مؤكدة' : 'Confirmed',
                value: l10n.formatNumber(confirmedCount),
              ),
              _BookingSummaryPill(
                label: l10n.isArabic ? 'إقامة حالية' : 'Checked in',
                value: l10n.formatNumber(activeStayCount),
              ),
              _BookingSummaryPill(
                label: l10n.isArabic ? 'مكتملة' : 'Checked out',
                value: l10n.formatNumber(completedCount),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingSummaryPill extends StatelessWidget {
  const _BookingSummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingsPage extends ConsumerWidget {
  const BookingsPage({super.key, this.selectedBookingId});

  final String? selectedBookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canManageBookings =
        session?.hasPermission(AppPermission.bookingsManage) ?? false;
    final bookings = ref.watch(bookingsProvider);
    return bookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          title: l10n.isArabic ? 'تعذر تحميل الحجوزات' : 'Unable to load bookings',
          subtitle: '$error',
          onRetry: () => ref.invalidate(bookingsProvider),
        ),
      ),
      data: (items) => ListView(
        children: [
          _BookingSummaryDeck(items: items),
          if (selectedBookingId != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.isArabic
                      ? 'الحجز المحدد: $selectedBookingId'
                      : 'Selected booking: $selectedBookingId',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final booking in items)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(18),
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
                                '${booking.clientName} · ${booking.bookingReference}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _bookingWindowLabel(context, booking),
                              ),
                              const SizedBox(height: 4),
                              Text(l10n.paymentStatus(booking.paymentStatus)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        StatusChip(
                          label: l10n.bookingStatus(booking.status),
                          color: _bookingStatusColor(booking.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.go('/app/bookings/${booking.id}'),
                          icon: const Icon(Icons.open_in_new_outlined),
                          label: Text(
                            l10n.isArabic ? 'فتح الحجز' : 'Open booking',
                          ),
                        ),
                        if (canManageBookings && booking.status == 'confirmed')
                          FilledButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(backendApiProvider)
                                  .checkInBooking(booking.id);
                              ref.invalidate(bookingsProvider);
                              ref.invalidate(unitsProvider);
                            },
                            icon: const Icon(Icons.login_outlined),
                            label: Text(
                              l10n.isArabic ? 'تسجيل دخول' : 'Check in',
                            ),
                          ),
                        if (canManageBookings && booking.status == 'checked_in')
                          FilledButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(backendApiProvider)
                                  .checkOutBooking(booking.id);
                              ref.invalidate(bookingsProvider);
                              ref.invalidate(unitsProvider);
                            },
                            icon: const Icon(Icons.logout_outlined),
                            label: Text(
                              l10n.isArabic ? 'تسجيل خروج' : 'Check out',
                            ),
                          ),
                      ],
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
