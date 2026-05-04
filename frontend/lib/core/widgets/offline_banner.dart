import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/theme/app_colors.dart';
import '../sync/connectivity_service.dart';
import '../sync/sync_queue.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isOnline = ref.watch(connectivityProvider);
    final pendingCount = ref.watch(
      syncQueueProvider.select(
        (actions) =>
            actions.where((action) => action.status.name != 'completed').length,
      ),
    );

    if (isOnline && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    final message = isOnline
      ? l10n.connectionRestoredMessage(pendingCount)
      : l10n.offlineModeMessage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isOnline
            ? AppColors.pine.withValues(alpha: 0.10)
            : AppColors.amber.withValues(alpha: 0.16),
        border: Border.all(
          color: isOnline
              ? AppColors.pine.withValues(alpha: 0.18)
              : AppColors.amber.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: isOnline ? AppColors.pine : AppColors.amber,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
