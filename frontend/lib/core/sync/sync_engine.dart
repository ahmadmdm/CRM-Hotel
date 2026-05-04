import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/backend_api_service.dart';
import 'sync_action.dart';
import 'sync_queue.dart';

class SyncEngine {
  SyncEngine(this.ref);

  final Ref ref;

  Future<void> flushPending() async {
    final actions = ref.read(syncQueueProvider);
    for (final action in actions) {
      if (action.status != SyncActionStatus.pending &&
          action.status != SyncActionStatus.failed) {
        continue;
      }
      ref.read(syncQueueProvider.notifier).markSyncing(action.id);
      try {
        final backendApi = ref.read(backendApiProvider);
        switch (action.actionType) {
          case 'complete_task':
            await backendApi.completeHousekeepingTask(action.entityId);
          case 'resolve_ticket':
            await backendApi.resolveMaintenanceTicket(action.entityId);
          default:
            throw UnsupportedError('Unknown sync action: ${action.actionType}');
        }
        ref.read(syncQueueProvider.notifier).markCompleted(action.id);
      } catch (error) {
        ref.read(syncQueueProvider.notifier).markFailed(action.id, '$error');
      }
    }
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine(ref));
