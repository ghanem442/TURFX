import 'package:dio/dio.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/backend_error_text.dart';

import '../models/admin_dashboard_model.dart';

class AdminDashboardRepository {
  AdminDashboardRepository(this._api);

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

  Future<AdminDashboardModel> getDashboard() async {
    try {
      final res = await _api.get(
        'admin/dashboard',
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid dashboard response');
      }

      final body = raw.cast<String, dynamic>();

      if (res.statusCode != null && res.statusCode! >= 400) {
        throw Exception(_extractErrorMessage(body));
      }

      if (body['success'] != true) {
        throw Exception(_extractErrorMessage(body));
      }

      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('Dashboard data not found');
      }

      return AdminDashboardModel.fromJson(data);
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