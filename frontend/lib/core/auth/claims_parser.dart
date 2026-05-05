import 'auth_session.dart';

Set<String> parseRoleCodes(Iterable<String> values) {
  return _parseStringSet(values);
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
