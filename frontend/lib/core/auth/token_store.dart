import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_session.dart';
import 'claims_parser.dart';

abstract class TokenStore {
  Future<AuthSession?> readSession();
  Future<void> writeSession(AuthSession session);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _userIdKey = 'session.userId';
  static const _nameKey = 'session.displayName';
  static const _emailKey = 'session.email';
  static const _accessTokenKey = 'session.accessToken';
  static const _refreshTokenKey = 'session.refreshToken';
  static const _rolesKey = 'session.roles';
  static const _permissionsKey = 'session.permissions';
  static const _assignedUnitsKey = 'session.assignedUnitIds';
  static const _sessionKeys = [
    _userIdKey,
    _nameKey,
    _emailKey,
    _accessTokenKey,
    _refreshTokenKey,
    _rolesKey,
    _permissionsKey,
    _assignedUnitsKey,
  ];

  @override
  Future<AuthSession?> readSession() async {
    final userId = await _storage.read(key: _userIdKey);
    final displayName = await _storage.read(key: _nameKey);
    final email = await _storage.read(key: _emailKey);
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final roles = await _storage.read(key: _rolesKey);
    final permissions = await _storage.read(key: _permissionsKey);
    final assignedUnits = await _storage.read(key: _assignedUnitsKey);

    if (userId == null ||
        displayName == null ||
        email == null ||
        accessToken == null ||
        refreshToken == null ||
        roles == null) {
      return null;
    }

    final parsedRoles = parseRoleCodes(roles.split(','));

    return AuthSession(
      userId: userId,
      displayName: displayName,
      email: email,
      accessToken: accessToken,
      refreshToken: refreshToken,
      roles: parsedRoles,
      permissions: permissions == null
          ? defaultPermissionCodesForRoles(parsedRoles)
          : parsePermissionCodes(permissions.split(',')),
        assignedUnitIds: assignedUnits == null
          ? const <String>{}
          : parseAssignedUnitIds(assignedUnits.split(',')),
    );
  }

  @override
  Future<void> writeSession(AuthSession session) async {
    await _storage.write(key: _userIdKey, value: session.userId);
    await _storage.write(key: _nameKey, value: session.displayName);
    await _storage.write(key: _emailKey, value: session.email);
    await _storage.write(key: _accessTokenKey, value: session.accessToken);
    await _storage.write(key: _refreshTokenKey, value: session.refreshToken);
    await _storage.write(
      key: _rolesKey,
      value: session.roles.join(','),
    );
    await _storage.write(
      key: _permissionsKey,
      value: session.permissions.join(','),
    );
    await _storage.write(
      key: _assignedUnitsKey,
      value: session.assignedUnitIds.join(','),
    );
  }

  @override
  Future<void> clear() async {
    for (final key in _sessionKeys) {
      await _storage.delete(key: key);
    }
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return SecureTokenStore(const FlutterSecureStorage());
});
