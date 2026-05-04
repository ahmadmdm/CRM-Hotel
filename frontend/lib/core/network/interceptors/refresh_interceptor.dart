import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session_controller.dart';

class RefreshInterceptor extends Interceptor {
  RefreshInterceptor(this.ref);

  final Ref ref;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      ref.read(sessionControllerProvider.notifier).signOut();
    }
    handler.next(err);
  }
}
