// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:js_util' as js_util;

class OneSignalBridge {
  const OneSignalBridge();

  bool get isSupported => _bridge != null;

  Future<void> initialize({
    required String appId,
    required String serviceWorkerPath,
    required String serviceWorkerScope,
  }) async {
    final bridge = _bridge;
    if (bridge == null || appId.isEmpty) {
      return;
    }
    await js_util.promiseToFuture<Object?>(
      js_util.callMethod(bridge, 'init', [
        js_util.jsify({
          'appId': appId,
          'serviceWorkerPath': serviceWorkerPath,
          'serviceWorkerScope': serviceWorkerScope,
        }),
      ]),
    );
  }

  Future<void> login(String externalId) async {
    final bridge = _bridge;
    if (bridge == null || externalId.isEmpty) {
      return;
    }
    await js_util.promiseToFuture<Object?>(
      js_util.callMethod(bridge, 'login', [externalId]),
    );
  }

  Future<void> logout() async {
    final bridge = _bridge;
    if (bridge == null) {
      return;
    }
    await js_util.promiseToFuture<Object?>(
      js_util.callMethod(bridge, 'logout', const []),
    );
  }

  Future<bool> promptForPush() async {
    final bridge = _bridge;
    if (bridge == null) {
      return false;
    }
    final result = await js_util.promiseToFuture<Object?>(
      js_util.callMethod(bridge, 'promptPush', const []),
    );
    return result == true;
  }

  Object? get _bridge {
    if (!js_util.hasProperty(html.window, 'crmHotelOneSignal')) {
      return null;
    }
    return js_util.getProperty(html.window, 'crmHotelOneSignal');
  }
}

const oneSignalBridge = OneSignalBridge();