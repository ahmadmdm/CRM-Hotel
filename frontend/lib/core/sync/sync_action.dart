enum SyncActionStatus { pending, syncing, failed, completed, conflict }

SyncActionStatus syncActionStatusFromName(String value) {
  return SyncActionStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => SyncActionStatus.pending,
  );
}

class SyncAction {
  const SyncAction({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.actionType,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.status = SyncActionStatus.pending,
    this.lastError,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String actionType;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final int retryCount;
  final SyncActionStatus status;
  final String? lastError;

  SyncAction copyWith({
    int? retryCount,
    SyncActionStatus? status,
    String? lastError,
  }) {
    return SyncAction(
      id: id,
      entityType: entityType,
      entityId: entityId,
      actionType: actionType,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
    );
  }
}
