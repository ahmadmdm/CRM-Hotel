import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../sync/sync_action.dart';
import 'models/sync_action_record.dart';

class IsarService {
  IsarService._();

  static final IsarService instance = IsarService._();

  Isar? _isar;

  bool get isReady => _isar != null;

  Future<void> initialize() async {
    if (_isar != null) {
      return;
    }

    final directory = kIsWeb
        ? ''
        : (await getApplicationDocumentsDirectory()).path;
    _isar = await Isar.open(
      [SyncActionRecordSchema],
      directory: directory,
      name: 'crmhotel_local_store',
    );
  }

  Isar? get _databaseOrNull => _isar;

  Future<Isar> _database() async {
    await initialize();
    return _isar!;
  }

  List<SyncAction> readSyncQueue() {
    final database = _databaseOrNull;
    if (database == null) {
      return const [];
    }

    final records = database.syncActionRecords.where().findAllSync()
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return records.map((record) => record.toDomain()).toList();
  }

  Future<void> upsertSyncAction(SyncAction action) async {
    final database = await _database();
    final record = SyncActionRecord.fromDomain(action);
    await database.writeTxn(() async {
      final existing = await database.syncActionRecords
          .filter()
          .actionIdEqualTo(action.id)
          .findFirst();
      if (existing != null) {
        record.id = existing.id;
      }
      await database.syncActionRecords.put(record);
    });
  }

  Future<void> deleteSyncAction(String actionId) async {
    final database = await _database();
    await database.writeTxn(() async {
      final existing = await database.syncActionRecords
          .filter()
          .actionIdEqualTo(actionId)
          .findFirst();
      if (existing != null) {
        await database.syncActionRecords.delete(existing.id);
      }
    });
  }
}
