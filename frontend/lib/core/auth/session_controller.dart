import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_api.dart';
import 'demo_accounts.dart';
import 'auth_session.dart';
import 'token_store.dart';

class SessionController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final storedSession = await ref.read(tokenStoreProvider).readSession();
    if (storedSession == null) {
      return null;
    }
    try {
      final hydratedSession = await ref.read(authApiProvider).refresh(storedSession);
      await ref.read(tokenStoreProvider).writeSession(hydratedSession);
      return hydratedSession;
    } catch (_) {
      await ref.read(tokenStoreProvider).clear();
      return null;
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      final session = await ref
          .read(authApiProvider)
          .login(email: email, password: password);
      await ref.read(tokenStoreProvider).writeSession(session);
      state = AsyncData(session);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refreshSession() async {
    final currentSession = state.valueOrNull;
    if (currentSession == null) {
      return;
    }
    final hydratedSession = await ref.read(authApiProvider).refresh(currentSession);
    await ref.read(tokenStoreProvider).writeSession(hydratedSession);
    state = AsyncData(hydratedSession);
  }

  Future<void> signInDemo(UserRole role) async {
    final account = demoAccountForRole(role);
    await signIn(account.email, account.password);
  }

  Future<void> signOut() async {
    final currentSession = state.valueOrNull;
    if (currentSession != null) {
      try {
        await ref.read(authApiProvider).logout(currentSession);
      } catch (_) {}
    }
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, AuthSession?>(
      SessionController.new,
    );
