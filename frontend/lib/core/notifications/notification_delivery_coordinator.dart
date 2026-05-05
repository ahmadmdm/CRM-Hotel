import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session.dart';
import '../auth/permissions.dart';
import '../network/backend_api_service.dart';
import 'onesignal_bridge.dart';

class NotificationDeliveryCoordinator {
  NotificationDeliveryCoordinator(this._ref);

  final Ref _ref;
  String? _syncedUserId;

  Future<void> syncSession(AuthSession? session) async {
    if (session == null ||
        !session.hasAnyPermission({
          AppPermission.notificationsView,
          AppPermission.notificationsManage,
        })) {
      _syncedUserId = null;
      await oneSignalBridge.logout();
      return;
    }
    if (_syncedUserId == session.userId) {
      return;
    }
    final config = await _safeFetchConfig();
    if (config == null || !config.enabled || config.appId.isEmpty) {
      _syncedUserId = null;
      return;
    }
    await oneSignalBridge.initialize(
      appId: config.appId,
      serviceWorkerPath: config.serviceWorkerPath,
      serviceWorkerScope: config.serviceWorkerScope,
    );
    await oneSignalBridge.login(session.userId);
    _syncedUserId = session.userId;
  }

  Future<bool> promptForPush(AuthSession session) async {
    final config = await _safeFetchConfig();
    if (config == null || !config.enabled || config.appId.isEmpty) {
      return false;
    }
    await syncSession(session);
    return oneSignalBridge.promptForPush();
  }

  Future<NotificationDeliveryConfig?> _safeFetchConfig() async {
    try {
      return await _ref.read(backendApiProvider).fetchNotificationDeliveryConfig();
    } catch (_) {
      return null;
    }
  }
}

final notificationDeliveryCoordinatorProvider =
    Provider<NotificationDeliveryCoordinator>((ref) {
      return NotificationDeliveryCoordinator(ref);
    });