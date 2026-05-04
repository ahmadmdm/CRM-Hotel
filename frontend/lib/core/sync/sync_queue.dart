import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/isar_service.dart';
import 'sync_action.dart';

class SyncQueue extends Notifier<List<SyncAction>> {
  late final IsarService _isarService;

  @override
  List<SyncAction> build() {
    _isarService = IsarService.instance;
    return _isarService.readSyncQueue();
  }

  void enqueue(SyncAction action) {
    state = [...state, action];
    unawaited(_isarService.upsertSyncAction(action));
  }

  void markSyncing(String id) {
    SyncAction? updatedAction;
    state = [
      for (final action in state)
        if (action.id == id)
          updatedAction = action.copyWith(status: SyncActionStatus.syncing)
        else
          action,
    ];
    if (updatedAction != null) {
      unawaited(_isarService.upsertSyncAction(updatedAction));
    }
  }

  void markCompleted(String id) {
    state = [
      for (final action in state)
        if (action.id != id) action,
    ];
    unawaited(_isarService.deleteSyncAction(id));
  }

  void markFailed(String id, String message) {
    SyncAction? updatedAction;
    state = [
      for (final action in state)
        if (action.id == id)
          updatedAction = action.copyWith(
            status: SyncActionStatus.failed,
            retryCount: action.retryCount + 1,
            lastError: message,
          )
        else
          action,
    ];
    if (updatedAction != null) {
      unawaited(_isarService.upsertSyncAction(updatedAction));
    }
  }
}

final syncQueueProvider = NotifierProvider<SyncQueue, List<SyncAction>>(
  SyncQueue.new,
);
