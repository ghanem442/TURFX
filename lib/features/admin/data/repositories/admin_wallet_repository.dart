import 'package:dio/dio.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/backend_error_text.dart';

import '../models/admin_wallet_transaction_model.dart';

class AdminWalletRepository {
  AdminWalletRepository(this._api);

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

  String? _normalizeType(String? value) {
    final v = value?.trim().toUpperCase();

    const allowed = {
      'DEPOSIT',
      'WITHDRAWAL',
      'REFUND',
      'BOOKING_PAYMENT',
      'COMMISSION_DEDUCTION',
      'CREDIT',
      'DEBIT',
      'PAYOUT',
    };

    if (v == null || v.isEmpty) return null;
    return allowed.contains(v) ? v : null;
  }

  Future<List<AdminWalletTransactionModel>> getTransactions({
    int page = 1,
    int limit = 20,
    String? userId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final normalizedType = _normalizeType(type);

      final res = await _api.get(
        'admin/wallet/transactions',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (userId != null && userId.trim().isNotEmpty)
            'userId': userId.trim(),
          if (normalizedType != null) 'type': normalizedType,
          if (startDate != null) 'startDate': _dateOnly(startDate),
          if (endDate != null) 'endDate': _dateOnly(endDate),
        },
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid wallet transactions response');
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

      final txNode = data['transactions'];
      if (txNode is! List) {
        return const [];
      }

      return txNode
          .whereType<Map>()
          .map(
            (e) => AdminWalletTransactionModel.fromJson(
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

  String _dateOnly(DateTime date) {
    final local = date.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}