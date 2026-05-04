import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crmhotel_frontend/core/sync/connectivity_service.dart';
import 'package:crmhotel_frontend/core/sync/sync_engine.dart';

class _FakeSyncEngine extends SyncEngine {
  _FakeSyncEngine(super.ref, this.onFlush);

  final void Function() onFlush;

  @override
  Future<void> flushPending() async {
    onFlush();
  }
}

void main() {
  test(
    'connectivity provider flushes pending actions on first online build',
    () async {
      var flushCount = 0;
      final container = ProviderContainer(
        overrides: [
          syncEngineProvider.overrideWith(
            (ref) => _FakeSyncEngine(ref, () => flushCount++),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(connectivityProvider), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(flushCount, 1);
    },
  );

  test(
    'connectivity provider flushes again when the app comes back online',
    () async {
      var flushCount = 0;
      final container = ProviderContainer(
        overrides: [
          syncEngineProvider.overrideWith(
            (ref) => _FakeSyncEngine(ref, () => flushCount++),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(connectivityProvider);
      await Future<void>.delayed(Duration.zero);
      expect(flushCount, 1);

      container.read(connectivityProvider.notifier).setOnline(false);
      await Future<void>.delayed(Duration.zero);
      expect(flushCount, 1);

      container.read(connectivityProvider.notifier).setOnline(true);
      await Future<void>.delayed(Duration.zero);
      expect(flushCount, 2);
    },
  );
}
