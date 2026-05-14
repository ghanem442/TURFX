import 'package:dio/dio.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/backend_error_text.dart';

import '../models/admin_user_model.dart';

class AdminUsersRepository {
  final ApiClient _api;

  AdminUsersRepository(this._api);

  String _extractErrorMessage(Map<String, dynamic> body) {
    final error = body['error'];

    if (error is Map) {
      final msg = error['message'];

      if (msg is Map) {
        final ar = msg['ar']?.toString();
        final en = msg['en']?.toString();

        if (ar != null && ar.trim().isNotEmpty) return ar.trim();
        if (en != null && en.trim().isNotEmpty) return en.trim();
      }

      final plain = error['message']?.toString();
      if (plain != null && plain.trim().isNotEmpty) {
        return humanizeBackendErrorText(plain.trim());
      }

      final code = error['code']?.toString();
      if (code != null && code.trim().isNotEmpty) {
        return humanizeBackendErrorText(code.trim());
      }
    }

    final message = body['message'];
    if (message is Map) {
      final ar = message['ar']?.toString();
      final en = message['en']?.toString();

      if (ar != null && ar.trim().isNotEmpty) return ar.trim();
      if (en != null && en.trim().isNotEmpty) return en.trim();
    }

    final plain = message?.toString();
    if (plain != null && plain.trim().isNotEmpty) {
      return humanizeBackendErrorText(plain.trim());
    }

    return 'Failed to load users';
  }

  Future<List<AdminUserModel>> getUsers({
    int page = 1,
    int limit = 20,
    String? role,
    String? email,
    bool? isVerified,
    bool? isSuspended,
  }) async {
    try {
      final res = await _api.get(
        'admin/users',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (isVerified != null) 'isVerified': isVerified,
          if (isSuspended != null) 'isSuspended': isSuspended,
        },
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid users response');
      }

      final body = Map<String, dynamic>.from(raw);

      if (res.statusCode != null && res.statusCode! >= 400) {
        throw Exception(_extractErrorMessage(body));
      }

      if (body['success'] != true) {
        throw Exception(_extractErrorMessage(body));
      }

      final data = body['data'];
      if (data is! Map) return const [];

      final usersNode = data['users'];
      if (usersNode is! List) return const [];

      return usersNode
          .whereType<Map>()
          .map((e) => AdminUserModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map) {
        throw Exception(_extractErrorMessage(Map<String, dynamic>.from(raw)));
      }
      throw Exception(formatDioFailure(e));
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> suspendUser(String userId) async {
    try {
      final res = await _api.patch(
        'admin/users/$userId/suspend',
        data: {
          'suspendedUntil': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
        },
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is Map && (res.statusCode == null || res.statusCode! >= 400)) {
        throw Exception(_extractErrorMessage(Map<String, dynamic>.from(raw)));
      }
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map) {
        throw Exception(_extractErrorMessage(Map<String, dynamic>.from(raw)));
      }
      throw Exception(formatDioFailure(e));
    }
  }

  Future<void> unsuspendUser(String userId) async {
    try {
      final res = await _api.patch(
        'admin/users/$userId/suspend',
        data: {
          'suspendedUntil': null,
        },
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is Map && (res.statusCode == null || res.statusCode! >= 400)) {
        throw Exception(_extractErrorMessage(Map<String, dynamic>.from(raw)));
      }
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map) {
        throw Exception(_extractErrorMessage(Map<String, dynamic>.from(raw)));
      }
      throw Exception(formatDioFailure(e));
    }
  }
}