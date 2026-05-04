import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crmhotel_frontend/app/bootstrap/app_initializer.dart';
import 'package:crmhotel_frontend/app/localization/locale_controller.dart';

void main() {
  testWidgets('App renders Arabic login copy by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: CrmHotelApp()));
    await tester.pumpAndSettle();

    expect(find.text('CrmHotel'), findsWidgets);
    expect(find.textContaining('الدخول'), findsWidgets);
    expect(
      find.text('منصة موحدة لإدارة الحجوزات والوحدات والعمليات والخدمة والصلاحيات في CrmHotel.'),
      findsOneWidget,
    );
    expect(find.text('صلاحيات حسب الدور'), findsOneWidget);
  });

  testWidgets('App renders English login copy when locale is overridden', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [initialLocaleProvider.overrideWithValue(const Locale('en'))],
        child: const CrmHotelApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CrmHotel'), findsWidgets);
    expect(find.text('Sign in'), findsOneWidget);
    expect(
      find.text(
        'A unified CrmHotel workspace for bookings, units, operations, service teams, and access control.',
      ),
      findsOneWidget,
    );
    expect(find.text('Housekeeping and Maintenance'), findsOneWidget);
  });
}
