import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final initialLocaleProvider = Provider<Locale>((ref) => const Locale('ar'));

final localeControllerProvider = StateProvider<Locale>(
  (ref) => ref.watch(initialLocaleProvider),
);
