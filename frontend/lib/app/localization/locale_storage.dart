import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class LocaleStorage {
  Future<Locale?> readLocale();
  Future<void> writeLocale(Locale locale);
}

class SecureLocaleStorage implements LocaleStorage {
  const SecureLocaleStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _localeKey = 'app.locale';

  @override
  Future<Locale?> readLocale() async {
    final languageCode = await _storage.read(key: _localeKey);
    if (languageCode == null || languageCode.isEmpty) {
      return null;
    }
    if (languageCode != 'ar' && languageCode != 'en') {
      return null;
    }
    return Locale(languageCode);
  }

  @override
  Future<void> writeLocale(Locale locale) {
    return _storage.write(key: _localeKey, value: locale.languageCode);
  }
}

final localeStorageProvider = Provider<LocaleStorage>((ref) {
  return const SecureLocaleStorage(FlutterSecureStorage());
});

Future<Locale> loadInitialLocale() async {
  final storage = const SecureLocaleStorage(FlutterSecureStorage());
  return await storage.readLocale() ?? const Locale('ar');
}