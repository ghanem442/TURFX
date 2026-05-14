import 'package:dio/dio.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/backend_error_text.dart';

class AdminProfileUpdateResult {
  final String id;
  final String email;
  final String? name;
  final String? role;
  final bool isVerified;

  const AdminProfileUpdateResult({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isVerified,
  });

  factory AdminProfileUpdateResult.fromJson(Map<String, dynamic> json) {
    return AdminProfileUpdateResult(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: json['name']?.toString(),
      role: json['role']?.toString(),
      isVerified: json['isVerified'] == true,
    );
  }
}

class AdminAccountRepository {
  AdminAccountRepository(this._api);

  final ApiClient _api;

  String _extractErrorMessage(dynamic raw) {
    if (raw is Map) {
      final error = raw['error'];

      if (error is Map) {
        final msg = error['message'];

        if (msg is Map) {
          final ar = msg['ar']?.toString().trim();
          final en = msg['en']?.toString().trim();

          if (ar != null && ar.isNotEmpty) return ar;
          if (en != null && en.isNotEmpty) return en;
        }

        final plainMsg = error['message']?.toString().trim();
        if (plainMsg != null && plainMsg.isNotEmpty) {
          return humanizeBackendErrorText(plainMsg);
        }

        final code = error['code']?.toString().trim();
        if (code != null && code.isNotEmpty) {
          return humanizeBackendErrorText(code);
        }
      }

      final message = raw['message'];

      if (message is Map) {
        final ar = message['ar']?.toString().trim();
        final en = message['en']?.toString().trim();

        if (ar != null && ar.isNotEmpty) return ar;
        if (en != null && en.isNotEmpty) return en;
      }

      final plain = raw['message']?.toString().trim();
      if (plain != null && plain.isNotEmpty) {
        return humanizeBackendErrorText(plain);
      }
    }

    if (raw is String && raw.trim().isNotEmpty) {
      return humanizeBackendErrorText(raw.trim());
    }

    return 'Request failed';
  }

  Future<AdminProfileUpdateResult> updateProfile({
    String? email,
    String? name,
  }) async {
    final payload = <String, dynamic>{
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    };

    if (payload.isEmpty) {
      throw Exception('At least one field is required');
    }

    try {
      final res = await _api.patch(
        'auth/me',
        data: payload,
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid profile update response');
      }

      final body = Map<String, dynamic>.from(raw);

      if (res.statusCode != null && res.statusCode! >= 400) {
        throw Exception(_extractErrorMessage(body));
      }

      if (body['success'] != true) {
        throw Exception(_extractErrorMessage(body));
      }

      final data = body['data'];
      if (data is! Map) {
        throw Exception('Invalid profile update data');
      }

      return AdminProfileUpdateResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map) {
        throw Exception(_extractErrorMessage(raw));
      }
      throw Exception(formatDioFailure(e));
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await _api.post(
        'auth/change-password',
        data: {
          'currentPassword': currentPassword.trim(),
          'newPassword': newPassword.trim(),
        },
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid change password response');
      }

      final body = Map<String, dynamic>.from(raw);

      if (res.statusCode != null && res.statusCode! >= 400) {
        throw Exception(_extractErrorMessage(body));
      }

      if (body['success'] != true) {
        throw Exception(_extractErrorMessage(body));
      }

      final message = body['message'];
      if (message is Map) {
        final ar = message['ar']?.toString().trim();
        final en = message['en']?.toString().trim();

        if (ar != null && ar.isNotEmpty) return ar;
        if (en != null && en.isNotEmpty) return en;
      }

      final plain = message?.toString().trim();
      if (plain != null && plain.isNotEmpty) {
        return humanizeBackendErrorText(plain);
      }

      return 'Password changed successfully';
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map) {
        throw Exception(_extractErrorMessage(raw));
      }
      throw Exception(formatDioFailure(e));
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}