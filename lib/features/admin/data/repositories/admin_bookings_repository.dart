import 'package:dio/dio.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/backend_error_text.dart';

import '../models/admin_booking_model.dart';

class AdminBookingsRepository {
  AdminBookingsRepository(this._api);

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
        return humanizeBackendErrorText(plainMsg);
      }

      final details = error['details'];
      if (details is List && details.isNotEmpty) {
        for (final item in details) {
          if (item is Map) {
            final msg = item['message'];
            if (msg is Map) {
              final ar = msg['ar']?.toString();
              final en = msg['en']?.toString();
              if (ar != null && ar.trim().isNotEmpty) return ar;
              if (en != null && en.trim().isNotEmpty) return en;
            }
            final plain = item['message']?.toString();
            if (plain != null && plain.trim().isNotEmpty) {
              return humanizeBackendErrorText(plain);
            }
          } else {
            final plain = item?.toString().trim();
            if (plain != null && plain.isNotEmpty) {
              return humanizeBackendErrorText(plain);
            }
          }
        }
      }
    }

    final message = body['message'];
    if (message is Map) {
      final ar = message['ar']?.toString();
      final en = message['en']?.toString();

      if (ar != null && ar.trim().isNotEmpty) return ar;
      if (en != null && en.trim().isNotEmpty) return en;
    }

    final plain = message?.toString();
    if (plain != null && plain.trim().isNotEmpty) {
      return humanizeBackendErrorText(plain);
    }

    return 'Request failed';
  }

  Future<List<AdminBookingModel>> getBookings({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
    String? fieldId,
    String? ownerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final res = await _api.get(
        'admin/bookings',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (status != null && status.trim().isNotEmpty)
            'status': status.trim(),
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (fieldId != null && fieldId.trim().isNotEmpty)
            'fieldId': fieldId.trim(),
          if (ownerId != null && ownerId.trim().isNotEmpty)
            'ownerId': ownerId.trim(),
          if (startDate != null) 'startDate': _dateOnly(startDate),
          if (endDate != null) 'endDate': _dateOnly(endDate),
        },
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid bookings response');
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

      final bookingsNode = data['bookings'];
      if (bookingsNode is! List) {
        return const [];
      }

      return bookingsNode
          .whereType<Map>()
          .map(
            (e) => AdminBookingModel.fromJson(
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