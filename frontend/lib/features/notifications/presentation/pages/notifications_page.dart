import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../core/auth/permissions.dart';
import '../../../../core/auth/session_controller.dart';
import '../../../../core/network/backend_api_service.dart';
import '../../../../core/notifications/notification_delivery_coordinator.dart';
import '../../../../core/notifications/onesignal_bridge.dart';
import '../../../../core/widgets/app_error_view.dart';

final notificationsProvider =
    FutureProvider<List<NotificationFeedItem>>((ref) async {
      return ref.read(backendApiProvider).fetchNotifications();
    });

final notificationStatsProvider = FutureProvider<NotificationStats>((ref) async {
  return ref.read(backendApiProvider).fetchNotificationStats();
});

final notificationDeliveryConfigProvider =
    FutureProvider<NotificationDeliveryConfig>((ref) async {
      return ref.read(backendApiProvider).fetchNotificationDeliveryConfig();
    });

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sendingBroadcast = false;
  bool _requestingPush = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationStatsProvider);
    ref.invalidate(notificationDeliveryConfigProvider);
    await Future.wait([
      ref.read(notificationsProvider.future),
      ref.read(notificationStatsProvider.future),
      ref.read(notificationDeliveryConfigProvider.future),
    ]);
  }

  Future<void> _markAllRead() async {
    await ref.read(backendApiProvider).markAllNotificationsRead();
    await _refresh();
  }

  Future<void> _markRead(String notificationId) async {
    await ref.read(backendApiProvider).markNotificationRead(notificationId);
    await _refresh();
  }

  Future<void> _sendBroadcast() async {
    final l10n = context.l10n;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      return;
    }
    setState(() => _sendingBroadcast = true);
    try {
      await ref.read(backendApiProvider).createNotificationBroadcast(
            title: title,
            body: body,
          );
      _titleController.clear();
      _bodyController.clear();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.notificationsBroadcastSent)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sendingBroadcast = false);
      }
    }
  }

  Future<void> _enablePush() async {
    final l10n = context.l10n;
    final session = ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) {
      return;
    }
    setState(() => _requestingPush = true);
    try {
      final granted = await ref
          .read(notificationDeliveryCoordinatorProvider)
          .promptForPush(session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted
                  ? l10n.notificationsPushEnabled
                  : l10n.notificationsPushUnavailable,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _requestingPush = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final canManage =
        session?.hasPermission(AppPermission.notificationsManage) ?? false;
    final notificationsAsync = ref.watch(notificationsProvider);
    final statsAsync = ref.watch(notificationStatsProvider);
    final deliveryConfigAsync = ref.watch(notificationDeliveryConfigProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.notificationsTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  statsAsync.when(
                    loading: () => Text(l10n.loading),
                    error: (_, _) => Text(l10n.notificationsStatsUnavailable),
                    data: (stats) => Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.mark_email_unread_outlined),
                          label: Text(
                            l10n.notificationsUnreadCount(stats.unreadCount),
                          ),
                        ),
                        if (stats.unreadCount > 0)
                          OutlinedButton.icon(
                            onPressed: _markAllRead,
                            icon: const Icon(Icons.done_all_outlined),
                            label: Text(l10n.notificationsMarkAllRead),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          deliveryConfigAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (config) {
              final canUseWebPush = config.enabled && oneSignalBridge.isSupported;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.notificationsPushCardTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        canUseWebPush
                            ? l10n.notificationsPushCardReady
                            : l10n.notificationsPushUnavailable,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: canUseWebPush && !_requestingPush
                            ? _enablePush
                            : null,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: Text(
                          _requestingPush
                              ? l10n.loading
                              : l10n.notificationsEnablePush,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (canManage)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.notificationsBroadcastTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: l10n.notificationsBroadcastSubjectLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bodyController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: l10n.notificationsBroadcastBodyLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _sendingBroadcast ? null : _sendBroadcast,
                      icon: const Icon(Icons.campaign_outlined),
                      label: Text(
                        _sendingBroadcast
                            ? l10n.loading
                            : l10n.notificationsBroadcastAction,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          notificationsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Center(
              child: AppErrorView(
                title: l10n.notificationsLoadErrorTitle,
                subtitle: '$error',
                onRetry: _refresh,
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.notificationsEmptyState),
                  ),
                );
              }
              return Column(
                children: [
                  for (final item in items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: item.isRead
                          ? null
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(_iconForKind(item.kind)),
                        ),
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.body}\n${l10n.notificationKindLabel(item.kind)} • ${_formatTimestamp(l10n, item.createdAt)}',
                        ),
                        isThreeLine: true,
                        trailing: item.isRead
                            ? const Icon(Icons.done_outlined)
                            : TextButton(
                                onPressed: () => _markRead(item.id),
                                child: Text(l10n.notificationsMarkRead),
                              ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'housekeeping':
        return Icons.cleaning_services_outlined;
      case 'maintenance':
        return Icons.build_outlined;
      case 'auth':
        return Icons.login_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  String _formatTimestamp(AppLocalizations l10n, String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }
    return l10n.formatDateTime(parsed);
  }
}