import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../core/network/backend_api_service.dart';
import '../../../../core/widgets/app_error_view.dart';

final clientsProvider = FutureProvider<List<ClientSummary>>((ref) async {
  return ref.read(backendApiProvider).fetchClients();
});

class CrmPage extends ConsumerWidget {
  const CrmPage({super.key, this.selectedClientId});

  final String? selectedClientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final clients = ref.watch(clientsProvider);
    return clients.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: AppErrorView(
          title: l10n.isArabic ? 'تعذر تحميل العملاء' : 'Unable to load clients',
          subtitle: '$error',
          onRetry: () => ref.invalidate(clientsProvider),
        ),
      ),
      data: (items) => ListView(
        children: [
          if (selectedClientId != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.isArabic
                      ? 'العميل المحدد: $selectedClientId'
                      : 'Selected client: $selectedClientId',
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(
                    label: Text(l10n.isArabic ? 'العميل' : 'Client'),
                  ),
                  DataColumn(label: Text(l10n.emailLabel)),
                  DataColumn(
                    label: Text(l10n.isArabic ? 'الهاتف' : 'Phone'),
                  ),
                  DataColumn(
                    label: Text(l10n.isArabic ? 'الحظر' : 'Blacklist'),
                  ),
                ],
                rows: [
                  for (final client in items)
                    DataRow(
                      cells: [
                        DataCell(Text(client.fullName)),
                        DataCell(Text(client.email)),
                        DataCell(Text(client.phone)),
                        DataCell(
                          Text(client.isBlacklisted ? l10n.yes : l10n.no),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
