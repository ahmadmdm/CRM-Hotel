import 'dart:convert';

import 'package:isar/isar.dart';

import '../../sync/sync_action.dart';

part 'sync_action_record.g.dart';

@collection
class SyncActionRecord {
  Id id = Isar.autoIncrement;

  late String actionId;

  late String entityType;
  late String entityId;
  late String actionType;
  late String payloadJson;
  late DateTime createdAt;
  late String status;
  int retryCount = 0;
  String? lastError;

  SyncAction toDomain() {
    final decodedPayload = jsonDecode(payloadJson) as Map<String, dynamic>;
    final normalizedStatus = status == SyncActionStatus.syncing.name
        ? SyncActionStatus.pending.name
        : status;
    return SyncAction(
      id: actionId,
      entityType: entityType,
      entityId: entityId,
      actionType: actionType,
      payload: Map<String, Object?>.from(decodedPayload),
      createdAt: createdAt,
      retryCount: retryCount,
      status: syncActionStatusFromName(normalizedStatus),
      lastError: lastError,
    );
  }

  static SyncActionRecord fromDomain(SyncAction action) {
    return SyncActionRecord()
      ..actionId = action.id
      ..entityType = action.entityType
      ..entityId = action.entityId
      ..actionType = action.actionType
      ..payloadJson = jsonEncode(action.payload)
      ..createdAt = action.createdAt
      ..status = action.status.name
      ..retryCount = action.retryCount
      ..lastError = action.lastError;
  }
}
