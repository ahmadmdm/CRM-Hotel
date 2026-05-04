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

final maintenanceTicketsProvider =
    FutureProvider<List<MaintenanceTicketSummary>>((ref) async {
      return ref.read(backendApiProvider).fetchMaintenanceTickets();
    });

String _maintenanceUnitLabel(MaintenanceTicketSummary ticket) {
  final code = ticket.unitCode;
  final name = ticket.unitName;
  if (code != null && code.isNotEmpty && name != null && name.isNotEmpty) {
    return '$code · $name';
  }
  if (code != null && code.isNotEmpty) {
    return code;
  }
  return ticket.unitId;
}

String _maintenanceAssignmentLabel(BuildContext context, MaintenanceTicketSummary ticket) {
  final l10n = context.l10n;
  final assignee = ticket.assignedUserName ?? ticket.assignedUserEmail;
  if (assignee != null && assignee.isNotEmpty) {
    return l10n.isArabic ? 'المسند: $assignee' : 'Assigned: $assignee';
  }
  if (ticket.assignedTeamName != null && ticket.assignedTeamName!.isNotEmpty) {
    return l10n.isArabic
        ? 'الفريق: ${ticket.assignedTeamName}'
        : 'Team: ${ticket.assignedTeamName}';
  }
  return l10n.isArabic ? 'الإسناد: للجميع' : 'Assignment: Everyone';
}

class MaintenancePage extends ConsumerWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isOnline = ref.watch(connectivityProvider);
    final tickets = ref.watch(maintenanceTicketsProvider);

    return tickets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          title: l10n.isArabic ? 'تعذر تحميل الصيانة' : 'Unable to load maintenance',
          subtitle: '$error',
          onRetry: () => ref.invalidate(maintenanceTicketsProvider),
        ),
      ),
      data: (items) => ListView(
        children: [
          for (final ticket in items)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(ticket.title),
                subtitle: Text(
                  l10n.isArabic
                    ? 'الوحدة: ${_maintenanceUnitLabel(ticket)} · الأولوية: ${l10n.priorityLabel(ticket.priority)}\n${_maintenanceAssignmentLabel(context, ticket)}'
                    : 'Unit: ${_maintenanceUnitLabel(ticket)} · Priority: ${l10n.priorityLabel(ticket.priority)}\n${_maintenanceAssignmentLabel(context, ticket)}',
                ),
                trailing: ticket.status == 'resolved'
                    ? StatusChip(
                        label: l10n.genericStatus('resolved'),
                        color: Colors.green,
                      )
                    : FilledButton(
                        onPressed: () async {
                          if (!isOnline) {
                            ref
                                .read(syncQueueProvider.notifier)
                                .enqueue(
                                  SyncAction(
                                    id: ticket.id,
                                    entityType: 'maintenance_ticket',
                                    entityId: ticket.id,
                                    actionType: 'resolve_ticket',
                                    payload: {'ticketId': ticket.id},
                                    createdAt: DateTime.now(),
                                  ),
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.isArabic
                                        ? 'تمت إضافة التذكرة إلى قائمة المزامنة المحلية.'
                                        : 'The ticket was added to the local sync queue.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          await ref
                              .read(backendApiProvider)
                              .resolveMaintenanceTicket(ticket.id);
                          ref.invalidate(maintenanceTicketsProvider);
                          await ref.read(syncEngineProvider).flushPending();
                        },
                        child: Text(
                          isOnline
                              ? (l10n.isArabic
                                    ? 'إغلاق التذكرة'
                                    : 'Resolve ticket')
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
