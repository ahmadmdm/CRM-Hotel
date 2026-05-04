import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_engine.dart';

class ConnectivityController extends Notifier<bool> {
  @override
  bool build() {
    Future<void>.microtask(() {
      if (state) {
        unawaited(ref.read(syncEngineProvider).flushPending());
      }
    });
    return true;
  }

  void setOnline(bool value) {
    final wasOnline = state;
    state = value;
    if (!wasOnline && value) {
      unawaited(ref.read(syncEngineProvider).flushPending());
    }
  }

  void toggle() {
    setOnline(!state);
  }
}

final connectivityProvider = NotifierProvider<ConnectivityController, bool>(
  ConnectivityController.new,
);
