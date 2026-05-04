import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import 'auth_session.dart';
import 'claims_parser.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data ?? <String, dynamic>{};
    final user =
        (data['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final roles = parseRoleCodes(
      ((data['roles'] as List?) ?? const []).cast<String>(),
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
      userId: user['id'] as String? ?? '',
      displayName: user['full_name'] as String? ?? email,
      email: user['email'] as String? ?? email,
      accessToken: data['access_token'] as String? ?? '',
      refreshToken: data['refresh_token'] as String? ?? '',
      roles: roles,
      permissions: permissions.isEmpty
          ? defaultPermissionCodesForRoles(roles)
          : permissions,
      assignedUnitIds: assignedUnitIds,
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
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(Dio(createBaseOptions()));
});
