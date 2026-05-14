import 'package:dio/dio.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/backend_error_text.dart';

import '../models/admin_system_settings_model.dart';

class AdminSettingsRepository {
  AdminSettingsRepository(this._api);

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

  Future<AdminSystemSettingsModel> getSettings() async {
    try {
      final res = await _api.get(
        'admin/system-settings',
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid settings response');
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
        throw Exception('Settings data not found');
      }

      return AdminSystemSettingsModel.fromJson(data);
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

  Future<void> updateSettings({
    required double globalCommissionPercentage,
    required double depositPercentage,
    required int cancellationRefundWindowHours,
  }) async {
    try {
      final res = await _api.patch(
        'admin/system-settings',
        data: {
          'globalCommissionPercentage': globalCommissionPercentage,
          'depositPercentage': depositPercentage,
          'cancellationRefundWindowHours': cancellationRefundWindowHours,
        },
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid update settings response');
      }

      final body = raw.cast<String, dynamic>();

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