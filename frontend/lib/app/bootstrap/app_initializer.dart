import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../localization/locale_controller.dart';
import '../localization/locale_storage.dart';
import '../routing/app_router.dart';
import '../theme/app_theme.dart';

class CrmHotelApp extends ConsumerWidget {
  const CrmHotelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(localeControllerProvider, (previous, next) {
      if (previous?.languageCode == next.languageCode) {
        return;
      }
      unawaited(ref.read(localeStorageProvider).writeLocale(next));
    });

    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeControllerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
