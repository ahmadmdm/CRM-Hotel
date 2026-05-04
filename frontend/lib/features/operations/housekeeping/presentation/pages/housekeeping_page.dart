import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/localization/app_localizations.dart';
import '../../../../../core/network/backend_api_service.dart';
import '../../../../../core/sync/connectivity_service.dart';
import '../../../../../core/sync/sync_action.dart';
import '../../../../../core/sync/sync_engine.dart';
import '../../../../../core/sync/sync_queue.dart';
import '../../../../../core/widgets/app_error_view.dart';
import '../../../../../design_system/components/status_chip.dart';

final housekeepingTasksProvider = FutureProvider<List<HousekeepingTaskSummary>>(
  (ref) async {
    return ref.read(backendApiProvider).fetchHousekeepingTasks();
  },
);

String _housekeepingUnitLabel(HousekeepingTaskSummary task) {
  final code = task.unitCode;
  final name = task.unitName;
  if (code != null && code.isNotEmpty && name != null && name.isNotEmpty) {
    return '$code · $name';
  }
  if (code != null && code.isNotEmpty) {
    return code;
  }
  return task.unitId;
}

String _housekeepingAssignmentLabel(BuildContext context, HousekeepingTaskSummary task) {
  final l10n = context.l10n;
  final assignee = task.assignedUserName ?? task.assignedUserEmail;
  if (assignee != null && assignee.isNotEmpty) {
    return l10n.isArabic ? 'المسند: $assignee' : 'Assigned: $assignee';
  }
  if (task.assignedTeamName != null && task.assignedTeamName!.isNotEmpty) {
    return l10n.isArabic
        ? 'الفريق: ${task.assignedTeamName}'
        : 'Team: ${task.assignedTeamName}';
  }
  return l10n.isArabic ? 'الإسناد: للجميع' : 'Assignment: Everyone';
}

class HousekeepingPage extends ConsumerWidget {
  const HousekeepingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isOnline = ref.watch(connectivityProvider);
    final tasks = ref.watch(housekeepingTasksProvider);

    return tasks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          title: context.l10n.isArabic
              ? 'تعذر تحميل مهام الإشراف'
              : 'Unable to load housekeeping tasks',
          subtitle: '$error',
          onRetry: () => ref.invalidate(housekeepingTasksProvider),
        ),
      ),
      data: (items) => ListView(
        children: [
          for (final task in items)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(_housekeepingUnitLabel(task)),
                subtitle: Text(
                  '${task.notes ?? (l10n.isArabic ? 'اضغط للإكمال ثم المزامنة.' : 'Tap to complete and sync')}\n${_housekeepingAssignmentLabel(context, task)} · ${l10n.priorityLabel(task.priority)}',
                ),
                trailing: task.status == 'completed'
                    ? StatusChip(
                        label: l10n.genericStatus('completed'),
                        color: Colors.green,
                      )
                    : FilledButton(
                        onPressed: () async {
                          if (!isOnline) {
                            ref
                                .read(syncQueueProvider.notifier)
                                .enqueue(
                                  SyncAction(
                                    id: task.id,
                                    entityType: 'housekeeping_task',
                                    entityId: task.id,
                                    actionType: 'complete_task',
                                    payload: {'taskId': task.id},
                                    createdAt: DateTime.now(),
                                  ),
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.isArabic
                                        ? 'تمت إضافة المهمة إلى قائمة المزامنة المحلية.'
                                        : 'The task was added to the local sync queue.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          await ref
                              .read(backendApiProvider)
                              .completeHousekeepingTask(task.id);
                          ref.invalidate(housekeepingTasksProvider);
                          await ref.read(syncEngineProvider).flushPending();
                        },
                        child: Text(
                          isOnline
                              ? (l10n.isArabic
                                    ? 'تم التنظيف'
                                    : 'Mark cleaned')
                              : (l10n.isArabic
                                    ? 'إضافة للطابور دون اتصال'
                                    : 'Queue offline'),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
