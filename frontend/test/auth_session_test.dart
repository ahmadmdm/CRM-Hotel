import 'package:flutter_test/flutter_test.dart';

import 'package:crmhotel_frontend/core/auth/auth_session.dart';
import 'package:crmhotel_frontend/core/auth/claims_parser.dart';

void main() {
  test('parseAssignedUnitIds trims values and drops empties', () {
    expect(
      parseAssignedUnitIds(const [' unit-1 ', '', 'unit-2', 'unit-1']),
      {'unit-1', 'unit-2'},
    );
  });

  test('AuthSession exposes assigned-unit scope without affecting routing', () {
    final session = AuthSession(
      userId: 'operations-user',
      displayName: 'Operations',
      email: 'operations@example.com',
      accessToken: 'token',
      refreshToken: 'refresh',
      roles: const {UserRole.operations},
      permissions: defaultPermissionCodesForRoles(const {UserRole.operations}),
      assignedUnitIds: const {'unit-101', 'unit-203'},
    );

    expect(session.hasAssignedUnits, isTrue);
    expect(session.assignedUnitIds, {'unit-101', 'unit-203'});
  });
}