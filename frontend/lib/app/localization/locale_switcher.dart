import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_localizations.dart';
import 'locale_controller.dart';

class LocaleMenuButton extends ConsumerWidget {
  const LocaleMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final l10n = context.l10n;

    return PopupMenuButton<Locale>(
      tooltip: l10n.language,
      onSelected: (value) => ref.read(localeControllerProvider.notifier).state = value,
      itemBuilder: (context) => [
        PopupMenuItem<Locale>(
          value: const Locale('ar'),
          child: Text(l10n.arabic),
        ),
        PopupMenuItem<Locale>(
          value: const Locale('en'),
          child: Text(l10n.english),
        ),
      ],
      child: Chip(
        avatar: const Icon(Icons.translate, size: 18),
        label: Text(locale.languageCode.toUpperCase()),
      ),
    );
  }
}