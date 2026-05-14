import 'package:dio/dio.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/models/api_response.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  String _extractErrorMessage(Map<String, dynamic> body) {
    final error = body['error'];

    if (error is Map) {
      final msg = error['message'];

      if (msg is Map) {
        final ar = msg['ar']?.toString();
        final en = msg['en']?.toString();

        if (ar != null && ar.trim().isNotEmpty) return ar;
        if (en != null && en.trim().isNotEmpty) return en;
      }

      final plainMsg = error['message']?.toString();
      if (plainMsg != null && plainMsg.trim().isNotEmpty) {
        return plainMsg;
      }
    }

    final message = body['message']?.toString();
    if (message != null && message.trim().isNotEmpty) {
      return message;
    }

    return 'Request failed';
  }

  ApiResponse<Map<String, dynamic>> _parseSafe(Map<String, dynamic> body) {
    final fixed = Map<String, dynamic>.from(body);

    if (fixed['data'] == null) {
      fixed['data'] = <String, dynamic>{};
    }

    return ApiResponse<Map<String, dynamic>>.fromJson(
      fixed,
      (x) => (x as Map).cast<String, dynamic>(),
    );
  }

  ApiResponse<Map<String, dynamic>> _failure({
    required String message,
    int? statusCode,
    dynamic raw,
  }) {
    return ApiResponse<Map<String, dynamic>>(
      success: false,
      message: statusCode == null ? message : '$message (HTTP $statusCode)',
      data: <String, dynamic>{
        if (statusCode != null) 'statusCode': statusCode,
        if (raw != null) 'raw': raw,
      },
    );
  }

  String _fallbackMessageForStatus(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Access denied';
      case 404:
        return 'Endpoint not found';
      case 409:
        return 'Conflict';
      case 422:
        return 'Invalid input data';
      case 500:
        return 'Server error';
      case 502:
        return 'Server is temporarily unavailable';
      case 503:
        return 'Service unavailable';
      default:
        return 'Request failed';
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> _postRequest(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final res = await _api.post(
        path,
        data: data,
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final statusCode = res.statusCode;
      final raw = res.data;

      if (raw is! Map) {
        return _failure(
          message: _fallbackMessageForStatus(statusCode),
          statusCode: statusCode,
          raw: raw,
        );
      }

      final body = raw.cast<String, dynamic>();

      if (statusCode != null && statusCode >= 400) {
        return _failure(
          message: _extractErrorMessage(body),
          statusCode: statusCode,
          raw: body,
        );
      }

      if (body['success'] != true) {
        return _failure(
          message: _extractErrorMessage(body),
          statusCode: statusCode,
          raw: body,
        );
      }

      return _parseSafe(body);
    } on DioException catch (e) {
      return _failure(
        message: e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
        raw: e.response?.data,
      );
    } catch (e) {
      return _failure(message: 'Unexpected error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> _getRequest(String path) async {
    try {
      final res = await _api.get(
        path,
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final statusCode = res.statusCode;
      final raw = res.data;

      if (raw is! Map) {
        return _failure(
          message: _fallbackMessageForStatus(statusCode),
          statusCode: statusCode,
          raw: raw,
        );
      }

      final body = raw.cast<String, dynamic>();

      if (statusCode != null && statusCode >= 400) {
        return _failure(
          message: _extractErrorMessage(body),
          statusCode: statusCode,
          raw: body,
        );
      }

      if (body['success'] != true) {
        return _failure(
          message: _extractErrorMessage(body),
          statusCode: statusCode,
          raw: body,
        );
      }

      return _parseSafe(body);
    } on DioException catch (e) {
      return _failure(
        message: e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
        raw: e.response?.data,
      );
    } catch (e) {
      return _failure(message: 'Unexpected error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) {
    return _postRequest(
      'auth/login',
      data: {
        'email': email.trim(),
        'password': password,
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> register({
    required String name,
    required String email,
    required String password,
    String? role,
  }) {
    return _postRequest(
      'auth/register',
      data: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> resendVerification({
    required String email,
  }) {
    return _postRequest(
      'auth/resend-verification',
      data: {
        'email': email.trim(),
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> verifyEmail({
    required String token,
  }) {
    return _postRequest(
      'auth/verify-email',
      data: {
        'token': token.trim(),
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> forgotPassword({
    required String email,
  }) {
    return _postRequest(
      'auth/forgot-password',
      data: {
        'email': email.trim(),
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _postRequest(
      'auth/reset-password',
      data: {
        'email': email.trim(),
        'otp': otp.trim(),
        'newPassword': newPassword,
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getDevResetToken({
    required String email,
  }) {
    return _postRequest(
      'auth/dev/get-reset-token',
      data: {
        'email': email.trim(),
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> devAutoVerify({
    required String email,
  }) {
    return _postRequest(
      'auth/dev/auto-verify',
      data: {
        'email': email.trim(),
      },
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getCurrentUser() {
    return _getRequest('users/me');
  }

  Future<ApiResponse<Map<String, dynamic>>> logout() {
    return _postRequest('auth/logout');
  }
}