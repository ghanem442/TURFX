import 'package:dio/dio.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/backend_error_text.dart';

import '../models/admin_payment_model.dart';

class AdminPaymentsRepository {
  AdminPaymentsRepository(this._api);

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

      final details = error['details'];
      if (details is List && details.isNotEmpty) {
        for (final item in details) {
          if (item is Map) {
            final detailMsg = item['message'];

            if (detailMsg is Map) {
              final ar = detailMsg['ar']?.toString();
              final en = detailMsg['en']?.toString();

              if (ar != null && ar.trim().isNotEmpty) return ar.trim();
              if (en != null && en.trim().isNotEmpty) return en.trim();
            }

            final plain = item['message']?.toString();
            if (plain != null && plain.trim().isNotEmpty) {
              return humanizeBackendErrorText(plain.trim());
            }
          } else {
            final plain = item?.toString().trim();
            if (plain != null && plain.isNotEmpty) return humanizeBackendErrorText(plain);
          }
        }
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

  Future<List<AdminPaymentModel>> getPendingPayments({
    int page = 1,
    int limit = 20,
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final res = await _api.get(
        'admin/payments/pending-verification',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (paymentMethod != null && paymentMethod.trim().isNotEmpty)
            'paymentMethod': paymentMethod.trim(),
          if (startDate != null) 'startDate': startDate.toUtc().toIso8601String(),
          if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
        },
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid pending payments response');
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

      final paymentsNode = data['payments'];
      if (paymentsNode is! List) return const [];

      return paymentsNode
          .whereType<Map>()
          .map(
            (e) => AdminPaymentModel.fromJson(
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

  Future<void> approvePayment({
    required String paymentId,
  }) async {
    try {
      final res = await _api.post(
        'admin/payments/$paymentId/approve',
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

  Future<void> rejectPayment({
    required String paymentId,
    required String reason,
  }) async {
    try {
      final res = await _api.post(
        'admin/payments/$paymentId/reject',
        data: {
          'reason': reason.trim(),
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