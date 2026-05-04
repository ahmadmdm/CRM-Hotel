import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crmhotel_frontend/app/routing/app_redirector.dart';
import 'package:crmhotel_frontend/app/routing/route_guards.dart';
import 'package:crmhotel_frontend/app/routing/route_names.dart';
import 'package:crmhotel_frontend/core/auth/auth_session.dart';
import 'package:crmhotel_frontend/core/auth/permissions.dart';

AuthSession _sessionFor(UserRole role) {
  final roles = {role};
  return AuthSession(
    userId: '${role.code}-user',
    displayName: role.label,
    email: '${role.code}@example.com',
    accessToken: 'token',
    refreshToken: 'refresh',
    roles: roles,
    permissions: defaultPermissionCodesForRoles(roles),
  );
}

AuthSession _sessionWithPermissions(Set<String> permissions) {
  return AuthSession(
    userId: 'permission-user',
    displayName: 'Permission User',
    email: 'permission@example.com',
    accessToken: 'token',
    refreshToken: 'refresh',
    roles: const {},
    permissions: permissions,
  );
}

void main() {
  test('each role lands on the expected default route', () {
    expect(_sessionFor(UserRole.superAdmin).defaultRoute, RouteNames.dashboard);
    expect(_sessionFor(UserRole.subAdmin).defaultRoute, RouteNames.dashboard);
    expect(_sessionFor(UserRole.financial).defaultRoute, RouteNames.dashboard);
    expect(_sessionFor(UserRole.operations).defaultRoute, RouteNames.dashboard);
    expect(_sessionFor(UserRole.maintenance).defaultRoute, RouteNames.maintenance);
    expect(_sessionFor(UserRole.housekeeping).defaultRoute, RouteNames.housekeeping);
  });

  test(
    'financial role can access finance but is redirected away from worker routes',
    () {
      final session = _sessionFor(UserRole.financial);

      expect(RouteGuards.canAccess(session, '/app/finance'), isTrue);
      expect(RouteGuards.canAccess(session, '/worker/maintenance'), isFalse);
      expect(
        AppRedirector.redirect(
          sessionState: AsyncValue.data(session),
          location: Uri.parse('/worker/maintenance'),
        ),
        RouteNames.forbidden,
      );
    },
  );

  test('operations role cannot access finance', () {
    final session = _sessionFor(UserRole.operations);

    expect(RouteGuards.canAccess(session, '/app/bookings'), isTrue);
    expect(RouteGuards.canAccess(session, '/app/finance'), isFalse);
    expect(
      AppRedirector.redirect(
        sessionState: AsyncValue.data(session),
        location: Uri.parse('/app/finance'),
      ),
      RouteNames.forbidden,
    );
  });

  test('maintenance and housekeeping are isolated from each other', () {
    final maintenance = _sessionFor(UserRole.maintenance);
    final housekeeping = _sessionFor(UserRole.housekeeping);

    expect(RouteGuards.canAccess(maintenance, '/worker/maintenance'), isTrue);
    expect(RouteGuards.canAccess(maintenance, '/worker/housekeeping'), isFalse);
    expect(RouteGuards.canAccess(housekeeping, '/worker/housekeeping'), isTrue);
    expect(RouteGuards.canAccess(housekeeping, '/worker/maintenance'), isFalse);
  });

  test('sub-admin can access the access-management page', () {
    final session = _sessionFor(UserRole.subAdmin);

    expect(RouteGuards.canAccess(session, RouteNames.access), isTrue);
    expect(
      AppRedirector.redirect(
        sessionState: AsyncValue.data(session),
        location: Uri.parse(
          '${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.access)}',
        ),
      ),
      RouteNames.access,
    );
  });

  test('maintenance cannot access the access-management page', () {
    final session = _sessionFor(UserRole.maintenance);

    expect(RouteGuards.canAccess(session, RouteNames.access), isFalse);
  });

  test(
    'sub-admin cannot access finance after frontend permission alignment',
    () {
      final session = _sessionFor(UserRole.subAdmin);

      expect(RouteGuards.canAccess(session, RouteNames.finance), isFalse);
    },
  );

  test('reports-only permission lands on the reports route', () {
    final session = _sessionWithPermissions({AppPermission.reportsView});

    expect(session.defaultRoute, RouteNames.reports);
    expect(RouteGuards.canAccess(session, RouteNames.reports), isTrue);
  });

  test('users-only permission lands on the access route', () {
    final session = _sessionWithPermissions({AppPermission.usersView});

    expect(session.defaultRoute, RouteNames.access);
    expect(RouteGuards.canAccess(session, RouteNames.access), isTrue);
  });
}
