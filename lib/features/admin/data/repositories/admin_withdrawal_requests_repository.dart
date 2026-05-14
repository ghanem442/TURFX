import 'package:dio/dio.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/backend_error_text.dart';
import '../models/admin_withdrawal_request_model.dart';

class AdminWithdrawalRequestsRepository {
  AdminWithdrawalRequestsRepository(this._api);

  final ApiClient _api;

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

      final plainMsg = error['message']?.toString();
      if (plainMsg != null && plainMsg.trim().isNotEmpty) {
        return humanizeBackendErrorText(plainMsg.trim());
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

    return 'Request failed';
  }

  String? _normalizeStatus(String? value) {
    final v = value?.trim().toUpperCase();

    const allowed = {
      'PENDING',
      'APPROVED',
      'REJECTED',
      'PROCESSING',
      'COMPLETED',
      'FAILED',
    };

    if (v == null || v.isEmpty) return null;
    return allowed.contains(v) ? v : null;
  }

  Future<List<AdminWithdrawalRequestModel>> getRequests({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final normalizedStatus = _normalizeStatus(status);

      final res = await _api.get(
        'admin/withdrawal-requests',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (normalizedStatus != null) 'status': normalizedStatus,
        },
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid withdrawal requests response');
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
        return const [];
      }

      final node = data['requests'];
      if (node is! List) {
        return const [];
      }

      return node
          .whereType<Map>()
          .map(
            (e) => AdminWithdrawalRequestModel.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
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

  Future<AdminWithdrawalRequestModel> approveRequest(String id) async {
    final requestId = id.trim();
    if (requestId.isEmpty) {
      throw Exception('Invalid request id');
    }

    try {
      final res = await _api.post(
        'admin/withdrawal-requests/$requestId/approve',
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid approve response');
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
        throw Exception('Invalid approve response data');
      }

      return AdminWithdrawalRequestModel.fromJson(
        Map<String, dynamic>.from(data),
      );
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

  Future<AdminWithdrawalRequestModel> rejectRequest({
    required String id,
    required String reason,
  }) async {
    final requestId = id.trim();
    final rejectionReason = reason.trim();

    if (requestId.isEmpty) {
      throw Exception('Invalid request id');
    }
    if (rejectionReason.isEmpty) {
      throw Exception('Rejection reason is required');
    }

    try {
      final res = await _api.post(
        'admin/withdrawal-requests/$requestId/reject',
        data: {
          'reason': rejectionReason,
        },
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid reject response');
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
        throw Exception('Invalid reject response data');
      }

      return AdminWithdrawalRequestModel.fromJson(
        Map<String, dynamic>.from(data),
      );
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
}