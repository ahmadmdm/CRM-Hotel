import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'interceptors/auth_interceptor.dart';
import 'interceptors/refresh_interceptor.dart';

const _defaultApiBaseUrl = 'http://127.0.0.1:8000/api/v1';
const _configuredApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: _defaultApiBaseUrl,
);

String _normalizedApiBaseUrl() {
  return _configuredApiBaseUrl.endsWith('/')
      ? _configuredApiBaseUrl
  : '$_configuredApiBaseUrl/';
}

BaseOptions createBaseOptions() {
  return BaseOptions(
    baseUrl: _normalizedApiBaseUrl(),
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
  );
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(createBaseOptions());
  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(RefreshInterceptor(ref));
  return dio;
});
