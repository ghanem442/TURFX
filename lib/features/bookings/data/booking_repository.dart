import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/cloudinary_upload_service.dart';
import 'package:football/core/utils/error_utils.dart';
import 'package:football/core/errors/api_exception.dart';

import 'models/booking_model.dart';
import 'models/bookings_list_result_model.dart';
import 'models/cancel_booking_result_model.dart';
import 'models/manual_payment_info_model.dart';
import 'models/payment_result_model.dart';
import 'models/payment_upload_result_model.dart';
import 'models/payment_verification_status_model.dart';
import 'models/time_slot_model.dart';

class BookingsRepository {
  final ApiClient api;

  BookingsRepository(this.api);

  Future<List<TimeSlotModel>> getTimeSlots({
    required String fieldId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final resolvedFieldId = fieldId.trim();

    final queryParams = <String, dynamic>{
      'fieldId': resolvedFieldId,
      'startDate': _isoDate(startDate),
      'endDate': _isoDate(endDate),
      'page': 1,
      'limit': 100,
    };

    if (kDebugMode) {
      debugPrint('================ TIME SLOTS REQUEST ================');
      debugPrint('[TIME_SLOTS] GET /time-slots');
      debugPrint('[TIME_SLOTS] query=$queryParams');
      debugPrint('[TIME_SLOTS] fieldId=$resolvedFieldId');
      debugPrint('[TIME_SLOTS] startDate=${_isoDate(startDate)}');
      debugPrint('[TIME_SLOTS] endDate=${_isoDate(endDate)}');
    }

    try {
      final res = await api.dio.get(
        'time-slots',
        queryParameters: queryParams,
      );

      final root = Map<String, dynamic>.from(res.data as Map);
      final data = root['data'];
      final list = (data is List) ? data : const [];

      if (kDebugMode) {
        debugPrint('[TIME_SLOTS] status=${res.statusCode}');
        debugPrint('[TIME_SLOTS] full response=$root');
        debugPrint('[TIME_SLOTS] data count=${list.length}');
        if (list.isEmpty) {
          debugPrint('[TIME_SLOTS] WARNING: backend returned empty slots list');
        }
        debugPrint('===================================================');
      }

      return list
          .whereType<Map>()
          .map((e) => TimeSlotModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      final message = _extractDioMessage(
        e,
        fallback: 'Failed to load time slots',
      );

      if (kDebugMode) {
        debugPrint('[TIME_SLOTS] DioException status=${e.response?.statusCode}');
        debugPrint('[TIME_SLOTS] DioException data=${e.response?.data}');
        debugPrint('[TIME_SLOTS] DioException message=$message');
      }

      throw Exception(message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TIME_SLOTS] unexpected error=$e');
      }
      throw Exception('Failed to load time slots');
    }
  }

  Future<BookingModel> createBooking({
    required String timeSlotId,
  }) async {
    final resolvedTimeSlotId = timeSlotId.trim();

    try {
      final res = await api.dio.post(
        'bookings',
        data: {'timeSlotId': resolvedTimeSlotId},
      );

      if (kDebugMode) {
        debugPrint('[CREATE_BOOKING] status=${res.statusCode}');
        debugPrint('[CREATE_BOOKING] raw response=${res.data}');
      }

      final root = _asMap(res.data);
      if (root == null) {
        throw Exception('Invalid booking response');
      }

      if (root['success'] == false) {
        final msg = extractErrorMessage(root);

        if (kDebugMode) {
          debugPrint('[CREATE_BOOKING] backend rejected request');
          debugPrint('[CREATE_BOOKING] parsed error=$msg');
          debugPrint('[CREATE_BOOKING] full root=$root');
        }

        throw Exception(msg);
      }

      final rawData = root['data'];
      if (rawData is! Map) {
        if (kDebugMode) {
          debugPrint('[CREATE_BOOKING] invalid data payload: $rawData');
        }
        throw Exception('Invalid booking response');
      }

      final data = Map<String, dynamic>.from(rawData);
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[CREATE_BOOKING] DioException status=$statusCode');
        debugPrint('[CREATE_BOOKING] DioException data=$data');
        debugPrint('[CREATE_BOOKING] DioException message=${e.message}');
      }

      throw Exception(
        _extractDioMessage(
          e,
          fallback: 'Failed to create booking',
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CREATE_BOOKING] unexpected error=$e');
      }
      rethrow;
    }
  }

  Future<BookingModel> getBookingById({
    required String bookingId,
  }) async {
    final resolvedBookingId = bookingId.trim();

    if (kDebugMode) {
      debugPrint('[BOOKING_BY_ID] GET /bookings/$resolvedBookingId');
    }

    try {
      final res = await api.dio.get('bookings/$resolvedBookingId');

      if (kDebugMode) {
        debugPrint('[BOOKING_BY_ID] status=${res.statusCode}');
        debugPrint('[BOOKING_BY_ID] response=${res.data}');
      }

      final root = _asMap(res.data);
      if (root == null) {
        throw Exception('Invalid booking response');
      }

      if (root['success'] == false) {
        throw Exception(extractErrorMessage(root));
      }

      final rawData = root['data'];
      if (rawData is! Map) {
        throw Exception('Invalid booking response');
      }

      final data = Map<String, dynamic>.from(rawData);
      return BookingModel.fromJson(data);
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[BOOKING_BY_ID] DioException status=${e.response?.statusCode}',
        );
        debugPrint('[BOOKING_BY_ID] DioException data=${e.response?.data}');
      }

      throw Exception(
        _extractDioMessage(
          e,
          fallback: 'Failed to load booking',
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BOOKING_BY_ID] unexpected error=$e');
      }
      rethrow;
    }
  }

  Future<QrCodeModel> getQrCode({
    required String bookingId,
  }) async {
    final resolvedBookingId = bookingId.trim();

    if (kDebugMode) {
      debugPrint('[BOOKING_QR] GET /bookings/$resolvedBookingId/qr');
    }

    try {
      final res = await api.dio.get('bookings/$resolvedBookingId/qr');

      if (kDebugMode) {
        debugPrint('[BOOKING_QR] status=${res.statusCode}');
        debugPrint('[BOOKING_QR] response=${res.data}');
      }

      final root = _asMap(res.data);
      if (root == null) {
        throw Exception('Invalid QR response');
      }

      if (root['success'] == false) {
        throw Exception(extractErrorMessage(root));
      }

      final rawData = root['data'];
      if (rawData is! Map) {
        throw Exception('Invalid QR response');
      }

      final data = Map<String, dynamic>.from(rawData);
      return QrCodeModel.fromJson(data);
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[BOOKING_QR] DioException status=${e.response?.statusCode}');
        debugPrint('[BOOKING_QR] DioException data=${e.response?.data}');
      }

      throw Exception(
        _extractDioMessage(
          e,
          fallback: 'Failed to load QR code',
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BOOKING_QR] unexpected error=$e');
      }
      rethrow;
    }
  }

  Future<ManualPaymentInfoModel> getManualPaymentInfo({
    required String gateway,
  }) async {
    final resolvedGateway = gateway.trim();
    final gatewayKey = resolvedGateway.toUpperCase();

    if (kDebugMode) {
      debugPrint('[MANUAL_PAYMENT_INFO] ========== START ==========');
      debugPrint('[MANUAL_PAYMENT_INFO] Gateway: $resolvedGateway');
      debugPrint('[MANUAL_PAYMENT_INFO] Gateway Key: $gatewayKey');
    }

    // Firebase removed - using API only
    if (kDebugMode) {
      debugPrint('[MANUAL_PAYMENT_INFO] Using API (Firebase removed)');
    }

    if (kDebugMode) {
      debugPrint(
        '[MANUAL_PAYMENT_INFO] GET /payments/manual-payment-info/$resolvedGateway',
      );
    }

    try {
      final res = await api.dio.get(
        'payments/manual-payment-info/$resolvedGateway',
      );

      if (kDebugMode) {
        debugPrint('[MANUAL_PAYMENT_INFO] status=${res.statusCode}');
        debugPrint('[MANUAL_PAYMENT_INFO] response=${res.data}');
      }

      final root = _asMap(res.data);
      if (root == null) {
        throw Exception('Invalid manual payment info response');
      }

      if (root['success'] == false) {
        throw Exception(extractErrorMessage(root));
      }

      final rawData = root['data'];
      if (rawData is! Map) {
        throw Exception('Invalid manual payment info response');
      }

      return ManualPaymentInfoModel.fromJson(
        Map<String, dynamic>.from(rawData),
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[MANUAL_PAYMENT_INFO] DioException status=${e.response?.statusCode}',
        );
        debugPrint('[MANUAL_PAYMENT_INFO] DioException data=${e.response?.data}');
      }

      throw Exception(
        _extractDioMessage(
          e,
          fallback: 'Failed to load payment account details',
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MANUAL_PAYMENT_INFO] unexpected error=$e');
      }
      rethrow;
    }
  }

  Future<PaymentResultModel> initiateDepositPayment({
    required String bookingId,
    required String gateway,
  }) async {
    final resolvedBookingId = bookingId.trim();
    final resolvedGateway = gateway.trim();

    final payload = <String, dynamic>{
      'bookingId': resolvedBookingId,
      'gateway': resolvedGateway,
    };

    if (kDebugMode) {
      debugPrint('[PAYMENT_INITIATE] POST /payments/initiate');
      debugPrint('[PAYMENT_INITIATE] request payload=$payload');
    }

    try {
      final res = await api.dio.post(
        'payments/initiate',
        data: payload,
      );

      if (kDebugMode) {
        debugPrint('[PAYMENT_INITIATE] status=${res.statusCode}');
        debugPrint('[PAYMENT_INITIATE] response=${res.data}');
      }

      return PaymentResultModel.fromAny(res.data);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[PAYMENT_INITIATE] DioException status=$statusCode');
        debugPrint('[PAYMENT_INITIATE] DioException data=$data');
        debugPrint('[PAYMENT_INITIATE] DioException message=${e.message}');
      }

      if (data is Map) {
        return PaymentResultModel.fromAny(data);
      }

      if (data is String && data.trim().isNotEmpty) {
        return PaymentResultModel(
          success: false,
          data: null,
          error: PaymentErrorModel(
            code: statusCode?.toString() ?? 'PAYMENT_FAILED',
            message: const {},
            plainMessage: data.trim(),
          ),
          message: data.trim(),
          status: statusCode?.toString(),
          raw: {
            'statusCode': statusCode,
            'data': data,
          },
        );
      }

      return PaymentResultModel(
        success: false,
        data: null,
        error: PaymentErrorModel(
          code: statusCode?.toString() ?? 'PAYMENT_FAILED',
          message: const {},
          plainMessage: e.message,
        ),
        message: e.message,
        status: statusCode?.toString(),
        raw: {
          'statusCode': statusCode,
          'data': data,
          'dioMessage': e.message,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PAYMENT_INITIATE] unexpected error=$e');
      }

      return PaymentResultModel(
        success: false,
        data: null,
        error: PaymentErrorModel(
          code: 'PAYMENT_PARSE_ERROR',
          message: const {},
          plainMessage: e.toString(),
        ),
        message: e.toString(),
        status: 'PAYMENT_PARSE_ERROR',
        raw: {
          'error': e.toString(),
        },
      );
    }
  }

  Future<PaymentResultModel> initiateWalletPayment({
    required String bookingId,
    required String gateway,
  }) {
    return initiateDepositPayment(
      bookingId: bookingId.trim(),
      gateway: gateway.trim(),
    );
  }

  Future<PaymentUploadResultModel> uploadPaymentScreenshot({
    required String paymentId,
    required File screenshotFile,
    String? notes,
    String? transactionId,
    String? senderNumber,
    void Function(int sent, int total)? onProgress,
  }) async {
    final resolvedPaymentId = paymentId.trim();

    if (kDebugMode) {
      debugPrint(
        '[UPLOAD_SCREENSHOT] POST /payments/$resolvedPaymentId/upload-screenshot (JSON screenshotUrl)',
      );
      debugPrint('[UPLOAD_SCREENSHOT] file=${screenshotFile.path}');
      debugPrint('[UPLOAD_SCREENSHOT] notes=$notes');
      debugPrint('[UPLOAD_SCREENSHOT] transactionId=$transactionId');
      debugPrint('[UPLOAD_SCREENSHOT] senderNumber=$senderNumber');
    }

    try {
      final cloudinary = CloudinaryUploadService(api);
      final screenshotUrl = await cloudinary.uploadImage(
        imageFile: screenshotFile,
        onProgress: onProgress,
      );

      final body = <String, dynamic>{
        'screenshotUrl': screenshotUrl,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (transactionId != null && transactionId.trim().isNotEmpty)
          'transactionId': transactionId.trim(),
        if (senderNumber != null && senderNumber.trim().isNotEmpty)
          'senderNumber': senderNumber.trim(),
      };

      final res = await api.post(
        'payments/$resolvedPaymentId/upload-screenshot',
        data: body,
      );

      if (kDebugMode) {
        debugPrint('[UPLOAD_SCREENSHOT] status=${res.statusCode}');
        debugPrint('[UPLOAD_SCREENSHOT] response=${res.data}');
      }

      final root = _asMap(res.data);
      if (root == null) {
        throw Exception('Invalid screenshot upload response');
      }

      if (root['success'] == false) {
        throw Exception(extractErrorMessage(root));
      }

      final rawData = root['data'];
      if (rawData is! Map) {
        throw Exception('Invalid screenshot upload response');
      }

      return PaymentUploadResultModel.fromJson(
        Map<String, dynamic>.from(rawData),
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[UPLOAD_SCREENSHOT] DioException status=${e.response?.statusCode}',
        );
        debugPrint('[UPLOAD_SCREENSHOT] DioException data=${e.response?.data}');
      }

      throw Exception(
        _extractDioMessage(
          e,
          fallback: 'Failed to upload payment screenshot',
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UPLOAD_SCREENSHOT] unexpected error=$e');
      }
      rethrow;
    }
  }

  Future<PaymentVerificationStatusModel> getVerificationStatus({
    required String paymentId,
  }) async {
    final resolvedPaymentId = paymentId.trim();

    if (kDebugMode) {
      debugPrint(
        '[PAYMENT_STATUS] GET /payments/$resolvedPaymentId/verification-status',
      );
    }

    try {
      final res = await api.dio.get(
        'payments/$resolvedPaymentId/verification-status',
      );

      if (kDebugMode) {
        debugPrint('[PAYMENT_STATUS] status=${res.statusCode}');
        debugPrint('[PAYMENT_STATUS] response=${res.data}');
      }

      final root = _asMap(res.data);
      if (root == null) {
        throw Exception('Invalid payment status response');
      }

      if (root['success'] == false) {
        throw Exception(extractErrorMessage(root));
      }

      final rawData = root['data'];
      if (rawData is! Map) {
        throw Exception('Invalid payment status response');
      }

      return PaymentVerificationStatusModel.fromJson(
        Map<String, dynamic>.from(rawData),
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[PAYMENT_STATUS] DioException status=${e.response?.statusCode}');
        debugPrint('[PAYMENT_STATUS] DioException data=${e.response?.data}');
      }

      // Handle 429 Too Many Requests with retryAfter
      if (e.response?.statusCode == 429) {
        int retryAfter = 10; // Default to 10 seconds
        
        try {
          final responseData = e.response?.data;
          if (responseData is Map) {
            retryAfter = (responseData['retryAfter'] as num?)?.toInt() ?? 10;
          }
        } catch (_) {
          // If parsing fails, use default
        }
        
        throw TooManyRequestsException(
          retryAfter: retryAfter,
          message: 'Too many requests. Please wait $retryAfter seconds before retrying.',
        );
      }

      throw Exception(
        _extractDioMessage(
          e,
          fallback: 'Failed to load payment verification status',
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PAYMENT_STATUS] unexpected error=$e');
      }
      rethrow;
    }
  }

  Future<CancelBookingResultModel> cancelBooking({
    required String bookingId,
    String? reason,
  }) async {
    final resolvedBookingId = bookingId.trim();

    try {
      final res = await api.dio.patch(
        'bookings/$resolvedBookingId/cancel',
        data: {
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
      );

      if (kDebugMode) {
        debugPrint('[CANCEL] status=${res.statusCode}');
        debugPrint('[CANCEL] response=${res.data}');
      }

      final root = Map<String, dynamic>.from(res.data as Map);
      return CancelBookingResultModel.fromJson(root);
    } on DioException catch (e) {
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[CANCEL] DioException status=${e.response?.statusCode}');
        debugPrint('[CANCEL] DioException data=$data');
      }

      if (data is Map) {
        final parsed = CancelBookingResultModel.fromJson(
          Map<String, dynamic>.from(data),
        );

        final message =
            parsed.messageAr ??
            parsed.messageEn ??
            extractErrorMessage(Map<String, dynamic>.from(data));

        throw Exception(message);
      }

      if (data is String && data.trim().isNotEmpty) {
        throw Exception(data.trim());
      }

      if (e.message != null && e.message!.trim().isNotEmpty) {
        throw Exception(e.message!.trim());
      }

      throw Exception('Failed to cancel booking');
    }
  }

  Future<BookingsListResult> getMyBookings({
    String? status,
    String? category,
    String? fieldId,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 10,
  }) async {
    final resolvedStatus = status?.trim();
    final resolvedCategory = category?.trim();
    final resolvedFieldId = fieldId?.trim();

    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (resolvedStatus != null && resolvedStatus.isNotEmpty)
        'status': resolvedStatus,
      if (resolvedCategory != null && resolvedCategory.isNotEmpty)
        'category': resolvedCategory,
      if (resolvedFieldId != null && resolvedFieldId.isNotEmpty)
        'fieldId': resolvedFieldId,
      if (startDate != null) 'startDate': _isoDate(startDate),
      if (endDate != null) 'endDate': _isoDate(endDate),
    };

    if (kDebugMode) {
      debugPrint('[MY_BOOKINGS] GET /bookings/my');
      debugPrint('[MY_BOOKINGS] query=$queryParameters');
    }

    try {
      final res = await api.dio.get(
        'bookings/my',
        queryParameters: queryParameters,
      );

      if (kDebugMode) {
        debugPrint('[MY_BOOKINGS] status=${res.statusCode}');
        debugPrint('[MY_BOOKINGS] response=${res.data}');
      }

      final root = Map<String, dynamic>.from(res.data as Map);
      return BookingsListResult.fromJson(root);
    } on DioException catch (e) {
      final data = e.response?.data;

      if (kDebugMode) {
        debugPrint('[MY_BOOKINGS] DioException status=${e.response?.statusCode}');
        debugPrint('[MY_BOOKINGS] DioException data=$data');
      }

      throw Exception(
        _extractDioMessage(
          e,
          fallback: 'Failed to load bookings',
        ),
      );
    }
  }

  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String _extractDioMessage(
    DioException e, {
    required String fallback,
  }) {
    final data = e.response?.data;

    if (data is Map) {
      return extractErrorMessage(Map<String, dynamic>.from(data));
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    if (e.message != null && e.message!.trim().isNotEmpty) {
      return e.message!.trim();
    }

    return fallback;
  }

  String _isoDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}