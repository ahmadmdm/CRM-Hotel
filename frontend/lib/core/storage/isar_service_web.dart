// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

import '../sync/sync_action.dart';

class IsarService {
  IsarService._();

  static final IsarService instance = IsarService._();

  static const _storageKey = 'crmhotel_sync_queue';

  bool get isReady => true;

  Future<void> initialize() async {}

  List<SyncAction> readSyncQueue() {
    final raw = html.window.localStorage[_storageKey];
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded =
        (jsonDecode(raw) as List<dynamic>)
            .cast<Map>()
            .map((item) => _fromJson(item.cast<String, dynamic>()))
            .toList()
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return decoded;
  }

  Future<void> upsertSyncAction(SyncAction action) async {
    final next = [
      for (final existing in readSyncQueue())
        if (existing.id != action.id) existing,
      action,
    ]..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    _save(next);
  }

  Future<void> deleteSyncAction(String actionId) async {
    final next = [
      for (final action in readSyncQueue())
        if (action.id != actionId) action,
    ];
    _save(next);
  }

  void _save(List<SyncAction> actions) {
    html.window.localStorage[_storageKey] = jsonEncode([
      for (final action in actions)
        {
          'id': action.id,
          'entityType': action.entityType,
          'entityId': action.entityId,
          'actionType': action.actionType,
          'payload': action.payload,
          'createdAt': action.createdAt.toIso8601String(),
          'retryCount': action.retryCount,
          'status': action.status.name,
          'lastError': action.lastError,
        },
    ]);
  }

  SyncAction _fromJson(Map<String, dynamic> json) {
    return SyncAction(
      id: json['id'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      actionType: json['actionType'] as String? ?? '',
      payload: Map<String, Object?>.from(
        (json['payload'] as Map?) ?? const <String, Object?>{},
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      retryCount: json['retryCount'] as int? ?? 0,
      status: syncActionStatusFromName(
        json['status'] as String? ?? SyncActionStatus.pending.name,
      ),
      lastError: json['lastError'] as String?,
    );
  }
}
