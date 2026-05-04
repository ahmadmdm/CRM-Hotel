import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_session.dart';
import 'route_guards.dart';
import 'route_names.dart';

class AppRedirector {
  static String? redirect({
    required AsyncValue<AuthSession?> sessionState,
    required Uri location,
  }) {
    final path = location.path;

    if (sessionState.isLoading && path != RouteNames.splash) {
      return RouteNames.splash;
    }

    final session = sessionState.valueOrNull;
    final isOpenRoute =
        path == RouteNames.splash ||
        path == RouteNames.login ||
        path == RouteNames.forbidden;

    if (session == null) {
      if (path == RouteNames.splash) {
        return RouteNames.login;
      }
      if (isOpenRoute) {
        return null;
      }
      return '${RouteNames.login}?from=${Uri.encodeComponent(path)}';
    }

    if (path == RouteNames.splash || path == RouteNames.login) {
      final from = location.queryParameters['from'];
      if (from != null &&
          from.isNotEmpty &&
          RouteGuards.canAccess(session, from)) {
        return from;
      }
      return session.defaultRoute;
    }

    if (!RouteGuards.canAccess(session, path)) {
      return RouteNames.forbidden;
    }

    return null;
  }
}
