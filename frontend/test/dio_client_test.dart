import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crmhotel_frontend/core/network/backend_api_service.dart';
import 'package:crmhotel_frontend/core/network/dio_client.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    return ResponseBody.fromString(
      '{"items":[]}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('createBaseOptions keeps API requests under api/v1', () {
    final options = createBaseOptions();
    final resolved = Uri.parse(options.baseUrl).resolve('users').toString();

    expect(options.baseUrl, endsWith('/api/v1/'));
    expect(resolved, 'http://127.0.0.1:8000/api/v1/users');
  });

  test('fetchUnits clamps page size to the backend limit', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api/v1/'));
    dio.httpClientAdapter = adapter;
    final api = BackendApiService(dio);

    await api.fetchUnits(pageSize: 200);

    expect(adapter.lastRequestOptions, isNotNull);
    expect(adapter.lastRequestOptions?.queryParameters['page_size'], 100);
  });
}