import 'package:dio/dio.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/backend_error_text.dart';

import '../models/admin_field_model.dart';

class AdminFieldsRepository {
  AdminFieldsRepository(this._api);

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
        if (plainMsg.trim() == 'common.badRequest') {
          return 'الطلب غير صالح أو العملية غير مسموحة للحالة الحالية.';
        }
        return humanizeBackendErrorText(plainMsg.trim());
      }

      final code = error['code']?.toString().trim();
      if (code != null && code.isNotEmpty) {
        switch (code) {
          case 'FIELD_HAS_ACTIVE_BOOKINGS':
            return 'لا يمكن حذف الملعب لوجود حجوزات نشطة عليه. أكمل أو ألغِ الحجوزات أولاً.';
          case 'VALIDATION_ERROR':
            return 'البيانات المرسلة غير صحيحة.';
          default:
            return humanizeBackendErrorText(code);
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

  String? _normalizeStatus(String? value) {
    final v = value?.trim().toUpperCase();

    const allowed = {
      'ACTIVE',
      'INACTIVE',
      'HIDDEN',
      'DISABLED',
      'PENDING_APPROVAL',
      'REJECTED',
      'DELETED',
    };

    if (v == null || v.isEmpty) return null;
    return allowed.contains(v) ? v : null;
  }

  List<AdminFieldModel> _applyLocalFilters(
    List<AdminFieldModel> fields, {
    String? search,
    String? status,
  }) {
    Iterable<AdminFieldModel> result = fields;

    final normalizedStatus = _normalizeStatus(status);

    if (normalizedStatus != null) {
      result = result.where((field) {
        final fieldStatus = (field.status ?? '').trim().toUpperCase();
        final isDeleted = field.deletedAt != null;

        switch (normalizedStatus) {
          case 'DELETED':
            return isDeleted;
          default:
            return !isDeleted && fieldStatus == normalizedStatus;
        }
      });
    }

    final q = search?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      result = result.where((field) {
        final name = field.name.toLowerCase();
        final address = field.address.toLowerCase();
        final ownerName = (field.ownerName ?? '').toLowerCase();
        final ownerEmail = (field.ownerEmail ?? '').toLowerCase();
        final id = field.id.toLowerCase();

        return name.contains(q) ||
            address.contains(q) ||
            ownerName.contains(q) ||
            ownerEmail.contains(q) ||
            id.contains(q);
      });
    }

    return result.toList();
  }

  Future<List<AdminFieldModel>> getFields({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? ownerId,
  }) async {
    try {
      final normalizedStatus = _normalizeStatus(status);

      final res = await _api.get(
        'admin/fields',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (normalizedStatus != null && normalizedStatus != 'DELETED')
            'status': normalizedStatus,
          if (ownerId != null && ownerId.trim().isNotEmpty)
            'ownerId': ownerId.trim(),
        },
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid fields response');
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

      final fieldsNode = data['fields'];
      if (fieldsNode is! List) {
        return const [];
      }

      final fields = fieldsNode
          .whereType<Map>()
          .map((e) => AdminFieldModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      return _applyLocalFilters(
        fields,
        search: search,
        status: normalizedStatus,
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

  Future<void> deleteField(String fieldId) async {
    try {
      final res = await _api.delete(
        'admin/fields/$fieldId',
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid delete response');
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

  Future<void> updateFieldStatus({
    required String fieldId,
    required String status,
  }) async {
    try {
      final normalizedStatus = _normalizeStatus(status);
      if (normalizedStatus == null || normalizedStatus == 'DELETED') {
        throw Exception('Invalid field status');
      }

      final res = await _api.patch(
        'admin/fields/$fieldId/status',
        data: {
          'status': normalizedStatus,
        },
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid status update response');
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