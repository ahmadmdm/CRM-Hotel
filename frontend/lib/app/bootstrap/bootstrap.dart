import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_initializer.dart';
import '../localization/locale_controller.dart';
import '../localization/locale_storage.dart';
import '../../core/storage/isar_service.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarService.instance.initialize();
  final initialLocale = await loadInitialLocale();
  runApp(
    ProviderScope(
      overrides: [initialLocaleProvider.overrideWithValue(initialLocale)],
      child: const CrmHotelApp(),
    ),
  );
}
