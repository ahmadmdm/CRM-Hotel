import 'auth_session.dart';

Set<UserRole> parseRoleCodes(Iterable<String> values) {
  return values.map(userRoleFromCode).toSet();
}

Set<String> parsePermissionCodes(Iterable<String> values) {
  return _parseStringSet(values);
}

Set<String> parseAssignedUnitIds(Iterable<String> values) {
  return _parseStringSet(values);
}

Set<String> _parseStringSet(Iterable<String> values) {
  return values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
}
