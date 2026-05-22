import 'package:flutter/foundation.dart';
import 'package:football/core/errors/api_exception.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/models/bilingual_message.dart';
import 'package:football/core/network/models/fields_response.dart';
import 'package:football/core/network/models/pagination_meta.dart';

import 'models/field_model.dart';

class FieldsRepository {
  final ApiClient api;

  FieldsRepository(this.api);

  Future<FieldsResponse<FieldModel>> getFields({
    int page = 1,
    int limit = 10,
    String? ownerId,
  }) async {
    try {
      debugPrint('GET FIELDS START');

      final res = await api.get(
        'fields',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (ownerId != null && ownerId.isNotEmpty) 'ownerId': ownerId,
        },
      );

      debugPrint('GET FIELDS STATUS = ${res.statusCode}');
      debugPrint('GET FIELDS DATA = ${res.data}');

      return _parseFieldsResponse(res.data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  Future<FieldsResponse<FieldModel>> searchFields({
    String? query,
    double? latitude,
    double? longitude,
    int? radiusKm,
  }) async {
    try {
      final res = await api.get(
        'fields/search',
        queryParameters: {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (radiusKm != null) 'radiusKm': radiusKm,
        },
      );

      debugPrint('SEARCH FIELDS STATUS = ${res.statusCode}');
      debugPrint('SEARCH FIELDS DATA = ${res.data}');

      return _parseFieldsResponse(res.data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  Future<FieldModel> getFieldById(String fieldId) async {
    final id = fieldId.trim();
    if (id.isEmpty) {
      throw Exception('Invalid fieldId');
    }

    final res = await api.get('fields/$id');

    debugPrint('GET FIELD BY ID STATUS = ${res.statusCode}');
    debugPrint('GET FIELD BY ID DATA = ${res.data}');

    final raw = res.data;

    if (raw is! Map<String, dynamic>) {
      throw Exception('Invalid response: expected Map');
    }

    final dataNode = raw['data'];

    if (dataNode is! Map) {
      throw Exception('Invalid response: data is not Map');
    }

    return FieldModel.fromJson(
      Map<String, dynamic>.from(dataNode),
    );
  }

  FieldsResponse<FieldModel> _parseFieldsResponse(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      throw Exception('Invalid response: expected Map');
    }

    final success = raw['success'] == true;

    final dataNode = raw['data'];

    final List<FieldModel> items =
        (dataNode is List)
            ? dataNode
                .map((e) => FieldModel.fromJson(
                    (e as Map).cast<String, dynamic>()))
                .toList()
            : <FieldModel>[];

    final metaNode = raw['meta'];

    final meta =
        (metaNode is Map<String, dynamic>)
            ? PaginationMeta.fromJson(metaNode)
            : const PaginationMeta(
                total: 0,
                page: 1,
                limit: 10,
                totalPages: 0,
              );

    final msgNode = raw['message'];

    final message =
        (msgNode is Map<String, dynamic>)
            ? BilingualMessage.fromJson(msgNode)
            : const BilingualMessage(en: '', ar: '');

    final timestamp = (raw['timestamp'] ?? '').toString();

    return FieldsResponse<FieldModel>(
      success: success,
      data: items,
      meta: meta,
      message: message,
      timestamp: timestamp,
    );
  }
}