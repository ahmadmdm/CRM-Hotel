import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import 'auth_session.dart';
import 'claims_parser.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  AuthSession _sessionFromAuthPayload(
    Map<String, dynamic> data, {
    required AuthSession fallbackSession,
    String? fallbackEmail,
  }) {
    final user =
        (data['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final roles = parseRoleCodes(
      ((data['roles'] as List?) ?? user['roles'] as List? ?? const [])
          .cast<String>(),
    );
    final permissions = parsePermissionCodes(
      ((data['permissions'] as List?) ??
              user['permissions'] as List? ??
              const [])
          .cast<String>(),
    );
    final assignedUnitIds = parseAssignedUnitIds(
      ((data['assigned_unit_ids'] as List?) ??
              user['assigned_unit_ids'] as List? ??
              const [])
          .cast<String>(),
    );
    return AuthSession(
      userId: user['id'] as String? ?? fallbackSession.userId,
      displayName: user['full_name'] as String? ?? fallbackSession.displayName,
      email: user['email'] as String? ?? fallbackEmail ?? fallbackSession.email,
      accessToken: data['access_token'] as String? ?? fallbackSession.accessToken,
      refreshToken: data['refresh_token'] as String? ?? fallbackSession.refreshToken,
      roles: roles,
      permissions: permissions.isEmpty
          ? defaultPermissionCodesForRoles(roles)
          : permissions,
      assignedUnitIds: assignedUnitIds,
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data ?? <String, dynamic>{};
    return _sessionFromAuthPayload(
      data,
      fallbackSession: AuthSession(
        userId: '',
        displayName: email,
        email: email,
        accessToken: '',
        refreshToken: '',
        roles: const <String>{},
        permissions: const <String>{},
      ),
      fallbackEmail: email,
    );
  }

  Future<AuthSession> me(AuthSession currentSession) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'auth/me',
      options: Options(
        headers: {'Authorization': 'Bearer ${currentSession.accessToken}'},
      ),
    );
    final data = response.data ?? <String, dynamic>{};
    final roles = parseRoleCodes(
      ((data['roles'] as List?) ?? const []).cast<String>(),
    );
    final permissions = parsePermissionCodes(
      ((data['permissions'] as List?) ?? const []).cast<String>(),
    );
    final assignedUnitIds = parseAssignedUnitIds(
      ((data['assigned_unit_ids'] as List?) ?? const []).cast<String>(),
    );
    return AuthSession(
      userId: data['id'] as String? ?? currentSession.userId,
      displayName: data['full_name'] as String? ?? currentSession.displayName,
      email: data['email'] as String? ?? currentSession.email,
      accessToken: currentSession.accessToken,
      refreshToken: currentSession.refreshToken,
      roles: roles,
      permissions: permissions.isEmpty
          ? defaultPermissionCodesForRoles(roles)
          : permissions,
      assignedUnitIds: assignedUnitIds,
    );
  }

  Future<AuthSession> refresh(AuthSession currentSession) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/refresh',
      options: Options(
        headers: {'Authorization': 'Bearer ${currentSession.accessToken}'},
      ),
    );
    final data = response.data ?? <String, dynamic>{};
    return _sessionFromAuthPayload(data, fallbackSession: currentSession);
  }

  Future<void> logout(AuthSession currentSession) async {
    await _dio.post<void>(
      'auth/logout',
      options: Options(
        headers: {'Authorization': 'Bearer ${currentSession.accessToken}'},
      ),
    );
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(Dio(createBaseOptions()));
});
