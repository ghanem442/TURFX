import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/features/bookings/data/models/booking_model.dart';
import 'package:football/features/bookings/data/models/time_slot_model.dart';
import 'package:football/features/fields/data/models/create_field_request.dart';
import 'package:football/features/fields/data/models/create_field_response_model.dart';
import 'package:football/features/owner/data/models/owner_bulk_slot_models.dart';
import 'package:football/features/owner/data/models/owner_fields_response_model.dart';

class OwnerRepository {
  final ApiClient api;

  OwnerRepository(this.api);

  String _extractErrorMessage(dynamic raw) {
    const fallback = 'Failed to load data';

    if (raw is Map) {
      final error = raw['error'];

      if (error is Map) {
        final details = error['details'];

        if (details is List && details.isNotEmpty) {
          final firstDetail = details.first;

          if (firstDetail is Map) {
            final detailMessage = firstDetail['message'];

            if (detailMessage is Map) {
              final ar = detailMessage['ar']?.toString().trim();
              final en = detailMessage['en']?.toString().trim();

              if (ar != null && ar.isNotEmpty) return ar;
              if (en != null && en.isNotEmpty) return en;
            }

            final plainMessage = firstDetail['message']?.toString().trim();
            if (plainMessage != null && plainMessage.isNotEmpty) {
              return plainMessage;
            }
          }
        }

        final msg = error['message'];

        if (msg is Map) {
          final ar = msg['ar']?.toString().trim();
          final en = msg['en']?.toString().trim();

          if (ar != null && ar.isNotEmpty) return ar;
          if (en != null && en.isNotEmpty) return en;
        }

        final code = error['code']?.toString().trim();
        if (code != null && code.isNotEmpty) return code;
      }

      final message = raw['message'];

      if (message is Map) {
        final ar = message['ar']?.toString().trim();
        final en = message['en']?.toString().trim();

        if (ar != null && ar.isNotEmpty) return ar;
        if (en != null && en.isNotEmpty) return en;
      }

      final text = raw['message']?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }

    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }

    return fallback;
  }

  String _extractLocalizedMessage(dynamic raw) {
    if (raw is Map) {
      final ar = raw['ar']?.toString().trim();
      final en = raw['en']?.toString().trim();

      if (ar != null && ar.isNotEmpty) return ar;
      if (en != null && en.isNotEmpty) return en;
    }

    final text = raw?.toString().trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }

    return '';
  }

  String _isoDate(DateTime d) {
    final x = d.toLocal();
    final mm = x.month.toString().padLeft(2, '0');
    final dd = x.day.toString().padLeft(2, '0');
    return '${x.year}-$mm-$dd';
  }

  Future<CreateFieldResponseModel> createField(
    CreateFieldRequest request,
  ) async {
    if (kDebugMode) {
      debugPrint('[CREATE_FIELD] POST /fields');
      debugPrint('[CREATE_FIELD] body=${request.toJson()}');
    }

    try {
      final res = await api.post(
        'fields',
        data: request.toJson(),
      );

      final root = Map<String, dynamic>.from(res.data as Map);

      if (kDebugMode) {
        debugPrint('[CREATE_FIELD] status=${res.statusCode}');
        debugPrint('[CREATE_FIELD] response=$root');
      }

      return CreateFieldResponseModel.fromJson(root);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[CREATE_FIELD] DioException status=$status');
        debugPrint('[CREATE_FIELD] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CREATE_FIELD] unexpected error=$e');
      }
      throw Exception('Failed to create field');
    }
  }

  Future<void> uploadFieldImage({
    required String fieldId,
    required File imageFile,
  }) async {
    final resolvedFieldId = fieldId.trim();
    if (resolvedFieldId.isEmpty) {
      throw Exception('Invalid field id');
    }

    if (kDebugMode) {
      debugPrint('[UPLOAD_FIELD_IMAGE] POST /fields/$resolvedFieldId/images');
      debugPrint('[UPLOAD_FIELD_IMAGE] file=${imageFile.path}');
    }

    try {
      final fileName = imageFile.path.split(Platform.pathSeparator).last;

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final res = await api.post(
        'fields/$resolvedFieldId/images',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (kDebugMode) {
        debugPrint('[UPLOAD_FIELD_IMAGE] status=${res.statusCode}');
        debugPrint('[UPLOAD_FIELD_IMAGE] response=${res.data}');
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[UPLOAD_FIELD_IMAGE] DioException status=$status');
        debugPrint('[UPLOAD_FIELD_IMAGE] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UPLOAD_FIELD_IMAGE] unexpected error=$e');
      }
      throw Exception('Failed to upload image');
    }
  }

  Future<void> updateField({
    required String fieldId,
    String? name,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    double? basePrice,
    double? commissionRate,
  }) async {
    final id = fieldId.trim();

    final payload = <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (basePrice != null) 'basePrice': basePrice,
      if (commissionRate != null) 'commissionRate': commissionRate,
    };

    if (kDebugMode) {
      debugPrint('[UPDATE_FIELD] PATCH /fields/$id');
      debugPrint('[UPDATE_FIELD] body=$payload');
    }

    try {
      await api.patch(
        'fields/$id',
        data: payload,
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e.response?.data));
    } catch (e) {
      throw Exception('Failed to update field');
    }
  }

  Future<void> deleteField(String fieldId) async {
    final id = fieldId.trim();

    if (kDebugMode) {
      debugPrint('[DELETE_FIELD] DELETE /fields/$id');
    }

    try {
      await api.delete(
        'fields/$id',
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e.response?.data));
    } catch (e) {
      throw Exception('Failed to delete field');
    }
  }

  Future<void> deleteFieldImage({
    required String fieldId,
    required String imageId,
  }) async {
    final fid = fieldId.trim();
    final iid = imageId.trim();

    if (kDebugMode) {
      debugPrint('[DELETE_FIELD_IMAGE] DELETE /fields/$fid/images/$iid');
    }

    try {
      await api.delete(
        'fields/$fid/images/$iid',
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e.response?.data));
    } catch (e) {
      throw Exception('Failed to delete image');
    }
  }

  Future<OwnerFieldsResponseModel> getMyFields({
    int page = 1,
    int limit = 10,
  }) async {
    final query = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
      'myFields': 'true',
    };

    if (kDebugMode) {
      debugPrint('[OWNER_FIELDS] GET /fields');
      debugPrint('[OWNER_FIELDS] query=$query');
    }

    try {
      final res = await api.get(
        'fields',
        queryParameters: query,
      );

      final root = Map<String, dynamic>.from(res.data as Map);

      if (kDebugMode) {
        debugPrint('[OWNER_FIELDS] status=${res.statusCode}');
        debugPrint('[OWNER_FIELDS] response=$root');
      }

      return OwnerFieldsResponseModel.fromJson(root);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[OWNER_FIELDS] DioException status=$status');
        debugPrint('[OWNER_FIELDS] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OWNER_FIELDS] unexpected error=$e');
      }
      throw Exception('Failed to load fields');
    }
  }

  Future<List<TimeSlotModel>> getFieldTimeSlots({
    required String fieldId,
    required DateTime startDate,
    required DateTime endDate,
    int page = 1,
    int limit = 100,
  }) async {
    final resolvedFieldId = fieldId.trim();
    if (resolvedFieldId.isEmpty) {
      throw Exception('Invalid field id');
    }

    final query = <String, dynamic>{
      'fieldId': resolvedFieldId,
      'startDate': _isoDate(startDate),
      'endDate': _isoDate(endDate),
      'page': page,
      'limit': limit,
    };

    if (kDebugMode) {
      debugPrint('[OWNER_TIME_SLOTS] GET /time-slots');
      debugPrint('[OWNER_TIME_SLOTS] query=$query');
    }

    try {
      final res = await api.get(
        'time-slots',
        queryParameters: query,
      );

      final root = Map<String, dynamic>.from(res.data as Map);
      final data = root['data'];
      final list = data is List ? data : const [];

      if (kDebugMode) {
        debugPrint('[OWNER_TIME_SLOTS] status=${res.statusCode}');
        debugPrint('[OWNER_TIME_SLOTS] response=$root');
      }

      return list
          .whereType<Map>()
          .map((e) => TimeSlotModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[OWNER_TIME_SLOTS] DioException status=$status');
        debugPrint('[OWNER_TIME_SLOTS] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OWNER_TIME_SLOTS] unexpected error=$e');
      }
      throw Exception('Failed to load time slots');
    }
  }

  Future<TimeSlotModel> createTimeSlot({
    required String fieldId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required double price,
  }) async {
    final payload = {
      'fieldId': fieldId.trim(),
      'date': _isoDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'price': price,
    };

    if (kDebugMode) {
      debugPrint('[CREATE_TIME_SLOT] POST /time-slots');
      debugPrint('[CREATE_TIME_SLOT] body=$payload');
    }

    try {
      final res = await api.post(
        'time-slots',
        data: payload,
      );

      final root = Map<String, dynamic>.from(res.data as Map);
      final data = Map<String, dynamic>.from(root['data'] as Map);

      if (kDebugMode) {
        debugPrint('[CREATE_TIME_SLOT] status=${res.statusCode}');
        debugPrint('[CREATE_TIME_SLOT] response=$root');
      }

      return TimeSlotModel.fromJson(data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[CREATE_TIME_SLOT] DioException status=$status');
        debugPrint('[CREATE_TIME_SLOT] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CREATE_TIME_SLOT] unexpected error=$e');
      }
      throw Exception('Failed to create time slot');
    }
  }

  Future<BulkCreateTimeSlotsResult> bulkCreateTimeSlots({
    required String fieldId,
    required DateTime startDate,
    required DateTime endDate,
    required List<int> daysOfWeek,
    required List<BulkTimeRangeItem> timeRanges,
  }) async {
    final resolvedFieldId = fieldId.trim();
    if (resolvedFieldId.isEmpty) {
      throw Exception('Invalid field id');
    }

    if (daysOfWeek.isEmpty) {
      throw Exception('At least one day is required');
    }

    if (timeRanges.isEmpty) {
      throw Exception('At least one time range is required');
    }

    final payload = {
      'fieldId': resolvedFieldId,
      'startDate': _isoDate(startDate),
      'endDate': _isoDate(endDate),
      'daysOfWeek': daysOfWeek,
      'timeRanges': timeRanges.map((e) => e.toJson()).toList(),
    };

    if (kDebugMode) {
      debugPrint('[BULK_CREATE_TIME_SLOTS] POST /time-slots/bulk');
      debugPrint('[BULK_CREATE_TIME_SLOTS] body=$payload');
    }

    try {
      final res = await api.post(
        'time-slots/bulk',
        data: payload,
      );

      final root = Map<String, dynamic>.from(res.data as Map);

      if (kDebugMode) {
        debugPrint('[BULK_CREATE_TIME_SLOTS] status=${res.statusCode}');
        debugPrint('[BULK_CREATE_TIME_SLOTS] response=$root');
      }

      return BulkCreateTimeSlotsResult.fromJson(root);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[BULK_CREATE_TIME_SLOTS] DioException status=$status');
        debugPrint('[BULK_CREATE_TIME_SLOTS] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BULK_CREATE_TIME_SLOTS] unexpected error=$e');
      }
      throw Exception('Failed to create bulk time slots');
    }
  }

  Future<TimeSlotModel> updateTimeSlot({
    required String slotId,
    DateTime? date,
    String? startTime,
    String? endTime,
    double? price,
  }) async {
    final payload = <String, dynamic>{
      if (date != null) 'date': _isoDate(date),
      if (startTime != null && startTime.trim().isNotEmpty)
        'startTime': startTime.trim(),
      if (endTime != null && endTime.trim().isNotEmpty)
        'endTime': endTime.trim(),
      if (price != null) 'price': price,
    };

    if (kDebugMode) {
      debugPrint('[UPDATE_TIME_SLOT] PATCH /time-slots/$slotId');
      debugPrint('[UPDATE_TIME_SLOT] body=$payload');
    }

    try {
      final res = await api.patch(
        'time-slots/${slotId.trim()}',
        data: payload,
      );

      final root = Map<String, dynamic>.from(res.data as Map);
      final data = Map<String, dynamic>.from(root['data'] as Map);

      if (kDebugMode) {
        debugPrint('[UPDATE_TIME_SLOT] status=${res.statusCode}');
        debugPrint('[UPDATE_TIME_SLOT] response=$root');
      }

      return TimeSlotModel.fromJson(data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[UPDATE_TIME_SLOT] DioException status=$status');
        debugPrint('[UPDATE_TIME_SLOT] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UPDATE_TIME_SLOT] unexpected error=$e');
      }
      throw Exception('Failed to update time slot');
    }
  }

  Future<void> deleteTimeSlot(String slotId) async {
    final resolvedSlotId = slotId.trim();
    if (resolvedSlotId.isEmpty) {
      throw Exception('Invalid slot id');
    }

    if (kDebugMode) {
      debugPrint('[DELETE_TIME_SLOT] DELETE /time-slots/$resolvedSlotId');
    }

    try {
      final res = await api.delete(
        'time-slots/$resolvedSlotId',
      );

      if (kDebugMode) {
        debugPrint('[DELETE_TIME_SLOT] status=${res.statusCode}');
        debugPrint('[DELETE_TIME_SLOT] response=${res.data}');
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[DELETE_TIME_SLOT] DioException status=$status');
        debugPrint('[DELETE_TIME_SLOT] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DELETE_TIME_SLOT] unexpected error=$e');
      }
      throw Exception('Failed to delete time slot');
    }
  }

  Future<OwnerBookingsPageResult> getOwnerBookings({
    String? fieldId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 10,
  }) async {
    final query = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (fieldId != null && fieldId.trim().isNotEmpty) {
      query['fieldId'] = fieldId.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    if (startDate != null) {
      query['startDate'] = startDate.toUtc().toIso8601String();
    }
    if (endDate != null) {
      query['endDate'] = endDate.toUtc().toIso8601String();
    }

    if (kDebugMode) {
      debugPrint('[OWNER_BOOKINGS] GET /bookings/owner');
      debugPrint('[OWNER_BOOKINGS] query=$query');
    }

    try {
      final res = await api.get(
        'bookings/owner',
        queryParameters: query,
      );

      final root = Map<String, dynamic>.from(res.data as Map);

      if (kDebugMode) {
        debugPrint('[OWNER_BOOKINGS] status=${res.statusCode}');
        debugPrint('[OWNER_BOOKINGS] response=$root');
      }

      final data = root['data'] is Map
          ? Map<String, dynamic>.from(root['data'] as Map)
          : <String, dynamic>{};

      final bookingsRaw = data['bookings'];
      final paginationRaw = data['pagination'];

      final bookings = bookingsRaw is List
          ? bookingsRaw
              .map(
                (e) => BookingModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : <BookingModel>[];

      final pagination = paginationRaw is Map
          ? OwnerBookingsPagination.fromJson(
              Map<String, dynamic>.from(paginationRaw),
            )
          : const OwnerBookingsPagination(
              total: 0,
              page: 1,
              limit: 10,
              totalPages: 1,
            );

      final resolvedMessage = _extractLocalizedMessage(root['message']);

      return OwnerBookingsPageResult(
        success: root['success'] == true,
        message: resolvedMessage.isEmpty ? null : resolvedMessage,
        bookings: bookings,
        pagination: pagination,
        timestamp: DateTime.tryParse(root['timestamp']?.toString() ?? ''),
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[OWNER_BOOKINGS] DioException status=$statusCode');
        debugPrint('[OWNER_BOOKINGS] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OWNER_BOOKINGS] unexpected error=$e');
      }
      throw Exception('Failed to load bookings');
    }
  }

  Future<BookingModel> getBookingDetails({
    required String bookingId,
  }) async {
    final id = bookingId.trim();
    if (id.isEmpty) {
      throw Exception('Booking ID is required');
    }

    if (kDebugMode) {
      debugPrint('[OWNER_BOOKING_DETAILS] GET /bookings/$id');
    }

    try {
      final res = await api.get('bookings/$id');

      final root = Map<String, dynamic>.from(res.data as Map);
      final data = root['data'];

      if (kDebugMode) {
        debugPrint('[OWNER_BOOKING_DETAILS] status=${res.statusCode}');
        debugPrint('[OWNER_BOOKING_DETAILS] response=$root');
      }

      if (data is Map<String, dynamic>) {
        return BookingModel.fromJson(data);
      }
      if (data is Map) {
        return BookingModel.fromJson(Map<String, dynamic>.from(data));
      }

      throw Exception('Invalid booking details response');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[OWNER_BOOKING_DETAILS] DioException status=$status');
        debugPrint('[OWNER_BOOKING_DETAILS] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OWNER_BOOKING_DETAILS] unexpected error=$e');
      }
      throw Exception('Failed to load booking details');
    }
  }

  Future<OwnerCheckInResult> validateQrToken({
    required String qrToken,
    String? fieldId,
  }) async {
    final token = qrToken.trim();
    final resolvedFieldId = fieldId?.trim();

    if (token.isEmpty) {
      throw Exception('QR token is required');
    }

    final payload = <String, dynamic>{
      'qrToken': token,
      if (resolvedFieldId != null && resolvedFieldId.isNotEmpty)
        'fieldId': resolvedFieldId,
    };

    if (kDebugMode) {
      debugPrint('[OWNER_QR_VALIDATE] POST /qr/validate');
      debugPrint('[OWNER_QR_VALIDATE] body=$payload');
    }

    try {
      final res = await api.post(
        'qr/validate',
        data: payload,
      );

      final root = Map<String, dynamic>.from(res.data as Map);

      if (kDebugMode) {
        debugPrint('[OWNER_QR_VALIDATE] status=${res.statusCode}');
        debugPrint('[OWNER_QR_VALIDATE] response=$root');
      }

      return OwnerCheckInResult.fromJson(root);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[OWNER_QR_VALIDATE] DioException status=$status');
        debugPrint('[OWNER_QR_VALIDATE] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OWNER_QR_VALIDATE] unexpected error=$e');
      }
      throw Exception('Failed to validate QR');
    }
  }

  Future<OwnerCheckInResult> verifyBookingId({
    required String bookingId,
    String? fieldId,
  }) async {
    final id = bookingId.trim();
    final resolvedFieldId = fieldId?.trim();

    if (id.isEmpty) {
      throw Exception('Booking ID is required');
    }

    final payload = <String, dynamic>{
      'bookingId': id,
      if (resolvedFieldId != null && resolvedFieldId.isNotEmpty)
        'fieldId': resolvedFieldId,
    };

    if (kDebugMode) {
      debugPrint('[OWNER_BOOKING_VERIFY] POST /qr/verify-booking-id');
      debugPrint('[OWNER_BOOKING_VERIFY] body=$payload');
    }

    try {
      final res = await api.post(
        'qr/verify-booking-id',
        data: payload,
      );

      final root = Map<String, dynamic>.from(res.data as Map);

      if (kDebugMode) {
        debugPrint('[OWNER_BOOKING_VERIFY] status=${res.statusCode}');
        debugPrint('[OWNER_BOOKING_VERIFY] response=$root');
      }

      return OwnerCheckInResult.fromJson(root);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[OWNER_BOOKING_VERIFY] DioException status=$status');
        debugPrint('[OWNER_BOOKING_VERIFY] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OWNER_BOOKING_VERIFY] unexpected error=$e');
      }
      throw Exception('Failed to verify booking');
    }
  }

  Future<OwnerCancelBookingResult> cancelBooking({
    required String bookingId,
    String? reason,
  }) async {
    final id = bookingId.trim();
    if (id.isEmpty) {
      throw Exception('Booking ID is required');
    }

    final payload = <String, dynamic>{
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };

    if (kDebugMode) {
      debugPrint('[OWNER_CANCEL_BOOKING] PATCH /bookings/$id/cancel');
      debugPrint('[OWNER_CANCEL_BOOKING] body=$payload');
    }

    try {
      final res = await api.patch(
        'bookings/$id/cancel',
        data: payload,
      );

      final root = Map<String, dynamic>.from(res.data as Map);

      if (kDebugMode) {
        debugPrint('[OWNER_CANCEL_BOOKING] status=${res.statusCode}');
        debugPrint('[OWNER_CANCEL_BOOKING] response=$root');
      }

      return OwnerCancelBookingResult.fromJson(root);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[OWNER_CANCEL_BOOKING] DioException status=$status');
        debugPrint('[OWNER_CANCEL_BOOKING] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OWNER_CANCEL_BOOKING] unexpected error=$e');
      }
      throw Exception('Failed to cancel booking');
    }
  }

  Future<OwnerNoShowResult> markBookingNoShow({
    required String bookingId,
  }) async {
    final id = bookingId.trim();
    if (id.isEmpty) {
      throw Exception('Booking ID is required');
    }

    if (kDebugMode) {
      debugPrint('[OWNER_NO_SHOW] PATCH /bookings/$id/no-show');
    }

    try {
      final res = await api.patch(
        'bookings/$id/no-show',
      );

      final root = Map<String, dynamic>.from(res.data as Map);

      if (kDebugMode) {
        debugPrint('[OWNER_NO_SHOW] status=${res.statusCode}');
        debugPrint('[OWNER_NO_SHOW] response=$root');
      }

      return OwnerNoShowResult.fromJson(root);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[OWNER_NO_SHOW] DioException status=$status');
        debugPrint('[OWNER_NO_SHOW] DioException data=$data');
      }

      throw Exception(_extractErrorMessage(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OWNER_NO_SHOW] unexpected error=$e');
      }
      throw Exception('Failed to mark booking as no-show');
    }
  }
}

class OwnerBookingsPageResult {
  final bool success;
  final String? message;
  final List<BookingModel> bookings;
  final OwnerBookingsPagination pagination;
  final DateTime? timestamp;

  const OwnerBookingsPageResult({
    required this.success,
    required this.message,
    required this.bookings,
    required this.pagination,
    required this.timestamp,
  });
}

class OwnerBookingsPagination {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const OwnerBookingsPagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  factory OwnerBookingsPagination.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, int fallback) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return OwnerBookingsPagination(
      total: asInt(json['total'], 0),
      page: asInt(json['page'], 1),
      limit: asInt(json['limit'], 10),
      totalPages: asInt(json['totalPages'], 1),
    );
  }
}

class OwnerCheckInResult {
  final bool success;
  final String message;
  final OwnerCheckInData data;

  const OwnerCheckInResult({
    required this.success,
    required this.message,
    required this.data,
  });

  factory OwnerCheckInResult.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final rawMessage = json['message'];

    String resolvedMessage = '';
    if (rawMessage is Map) {
      final ar = rawMessage['ar']?.toString().trim();
      final en = rawMessage['en']?.toString().trim();

      if (ar != null && ar.isNotEmpty) {
        resolvedMessage = ar;
      } else if (en != null && en.isNotEmpty) {
        resolvedMessage = en;
      }
    } else {
      final text = rawMessage?.toString().trim();
      if (text != null && text.isNotEmpty) {
        resolvedMessage = text;
      }
    }

    return OwnerCheckInResult(
      success: json['success'] == true,
      message: resolvedMessage,
      data: rawData is Map<String, dynamic>
          ? OwnerCheckInData.fromJson(rawData)
          : (rawData is Map
              ? OwnerCheckInData.fromJson(
                  Map<String, dynamic>.from(rawData),
                )
              : const OwnerCheckInData()),
    );
  }
}

class OwnerCheckInData {
  final String bookingId;
  final String status;
  final String playerName;
  final String fieldName;
  final DateTime? scheduledStartTime;
  final DateTime? scheduledEndTime;

  const OwnerCheckInData({
    this.bookingId = '',
    this.status = '',
    this.playerName = '',
    this.fieldName = '',
    this.scheduledStartTime,
    this.scheduledEndTime,
  });

  factory OwnerCheckInData.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text)?.toLocal();
    }

    return OwnerCheckInData(
      bookingId: (json['bookingId'] ?? '').toString(),
      status: (json['status'] ?? '').toString().trim().toUpperCase(),
      playerName: (json['playerName'] ?? '').toString(),
      fieldName: (json['fieldName'] ?? '').toString(),
      scheduledStartTime: parseDt(json['scheduledStartTime']),
      scheduledEndTime: parseDt(json['scheduledEndTime']),
    );
  }
}

class OwnerCancelBookingResult {
  final bool success;
  final String message;
  final OwnerCancelledBookingData data;

  const OwnerCancelBookingResult({
    required this.success,
    required this.message,
    required this.data,
  });

  factory OwnerCancelBookingResult.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];

    String resolvedMessage = '';
    final rawMessage = json['message'];
    if (rawMessage is Map) {
      final ar = rawMessage['ar']?.toString().trim();
      final en = rawMessage['en']?.toString().trim();

      if (ar != null && ar.isNotEmpty) {
        resolvedMessage = ar;
      } else if (en != null && en.isNotEmpty) {
        resolvedMessage = en;
      }
    } else {
      final text = rawMessage?.toString().trim();
      if (text != null && text.isNotEmpty) {
        resolvedMessage = text;
      }
    }

    return OwnerCancelBookingResult(
      success: json['success'] == true,
      message: resolvedMessage,
      data: rawData is Map<String, dynamic>
          ? OwnerCancelledBookingData.fromJson(rawData)
          : (rawData is Map
              ? OwnerCancelledBookingData.fromJson(
                  Map<String, dynamic>.from(rawData),
                )
              : const OwnerCancelledBookingData()),
    );
  }
}

class OwnerCancelledBookingData {
  final OwnerCancelledBookingInfo booking;
  final OwnerBookingRefundInfo refund;

  const OwnerCancelledBookingData({
    this.booking = const OwnerCancelledBookingInfo(),
    this.refund = const OwnerBookingRefundInfo(),
  });

  factory OwnerCancelledBookingData.fromJson(Map<String, dynamic> json) {
    final bookingRaw = json['booking'];
    final refundRaw = json['refund'];

    return OwnerCancelledBookingData(
      booking: bookingRaw is Map<String, dynamic>
          ? OwnerCancelledBookingInfo.fromJson(bookingRaw)
          : (bookingRaw is Map
              ? OwnerCancelledBookingInfo.fromJson(
                  Map<String, dynamic>.from(bookingRaw),
                )
              : const OwnerCancelledBookingInfo()),
      refund: refundRaw is Map<String, dynamic>
          ? OwnerBookingRefundInfo.fromJson(refundRaw)
          : (refundRaw is Map
              ? OwnerBookingRefundInfo.fromJson(
                  Map<String, dynamic>.from(refundRaw),
                )
              : const OwnerBookingRefundInfo()),
    );
  }
}

class OwnerCancelledBookingInfo {
  final String id;
  final String status;

  const OwnerCancelledBookingInfo({
    this.id = '',
    this.status = '',
  });

  factory OwnerCancelledBookingInfo.fromJson(Map<String, dynamic> json) {
    return OwnerCancelledBookingInfo(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class OwnerBookingRefundInfo {
  final double amount;
  final int percentage;

  const OwnerBookingRefundInfo({
    this.amount = 0,
    this.percentage = 0,
  });

  factory OwnerBookingRefundInfo.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return OwnerBookingRefundInfo(
      amount: asDouble(json['amount']),
      percentage: asInt(json['percentage']),
    );
  }
}

class OwnerNoShowResult {
  final bool success;
  final String message;
  final OwnerNoShowData data;

  const OwnerNoShowResult({
    required this.success,
    required this.message,
    required this.data,
  });

  factory OwnerNoShowResult.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];

    String resolvedMessage = '';
    final rawMessage = json['message'];
    if (rawMessage is Map) {
      final ar = rawMessage['ar']?.toString().trim();
      final en = rawMessage['en']?.toString().trim();

      if (ar != null && ar.isNotEmpty) {
        resolvedMessage = ar;
      } else if (en != null && en.isNotEmpty) {
        resolvedMessage = en;
      }
    } else {
      final text = rawMessage?.toString().trim();
      if (text != null && text.isNotEmpty) {
        resolvedMessage = text;
      }
    }

    return OwnerNoShowResult(
      success: json['success'] == true,
      message: resolvedMessage,
      data: rawData is Map<String, dynamic>
          ? OwnerNoShowData.fromJson(rawData)
          : (rawData is Map
              ? OwnerNoShowData.fromJson(
                  Map<String, dynamic>.from(rawData),
                )
              : const OwnerNoShowData()),
    );
  }
}

class OwnerNoShowData {
  final OwnerNoShowBookingInfo booking;
  final OwnerNoShowPlayerInfo player;

  const OwnerNoShowData({
    this.booking = const OwnerNoShowBookingInfo(),
    this.player = const OwnerNoShowPlayerInfo(),
  });

  factory OwnerNoShowData.fromJson(Map<String, dynamic> json) {
    final bookingRaw = json['booking'];
    final playerRaw = json['player'];

    return OwnerNoShowData(
      booking: bookingRaw is Map<String, dynamic>
          ? OwnerNoShowBookingInfo.fromJson(bookingRaw)
          : (bookingRaw is Map
              ? OwnerNoShowBookingInfo.fromJson(
                  Map<String, dynamic>.from(bookingRaw),
                )
              : const OwnerNoShowBookingInfo()),
      player: playerRaw is Map<String, dynamic>
          ? OwnerNoShowPlayerInfo.fromJson(playerRaw)
          : (playerRaw is Map
              ? OwnerNoShowPlayerInfo.fromJson(
                  Map<String, dynamic>.from(playerRaw),
                )
              : const OwnerNoShowPlayerInfo()),
    );
  }
}

class OwnerNoShowBookingInfo {
  final String id;
  final String status;

  const OwnerNoShowBookingInfo({
    this.id = '',
    this.status = '',
  });

  factory OwnerNoShowBookingInfo.fromJson(Map<String, dynamic> json) {
    return OwnerNoShowBookingInfo(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class OwnerNoShowPlayerInfo {
  final int noShowCount;
  final bool isSuspended;
  final DateTime? suspendedUntil;

  const OwnerNoShowPlayerInfo({
    this.noShowCount = 0,
    this.isSuspended = false,
    this.suspendedUntil,
  });

  factory OwnerNoShowPlayerInfo.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    bool asBool(dynamic value) {
      if (value is bool) return value;
      final text = value?.toString().toLowerCase().trim();
      return text == 'true' || text == '1';
    }

    DateTime? parseDt(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text)?.toLocal();
    }

    return OwnerNoShowPlayerInfo(
      noShowCount: asInt(json['noShowCount']),
      isSuspended: asBool(json['isSuspended']),
      suspendedUntil: parseDt(json['suspendedUntil']),
    );
  }
}