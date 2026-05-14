import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models/booking_model.dart';
import 'models/bookings_list_result_model.dart';
import 'models/cancel_booking_result_model.dart';
import 'models/payment_result_model.dart';
import 'models/time_slot_model.dart';

class BookingsApi {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  final http.Client _client;
  final String? token;

  BookingsApi({
    http.Client? client,
    this.token,
  }) : _client = client ?? http.Client();

  Future<List<TimeSlotModel>> getTimeSlots({
    required String fieldId,
    required DateTime startDate,
    required DateTime endDate,
    int page = 1,
    int limit = 100,
  }) async {
    final uri = Uri.parse('$baseUrl/time-slots').replace(
      queryParameters: {
        'fieldId': fieldId,
        'startDate': _isoDate(startDate),
        'endDate': _isoDate(endDate),
        'limit': limit.toString(),
        'page': page.toString(),
      },
    );

    final res = await _client.get(uri, headers: _headers());
    final decoded = _decodeBody(res, method: 'GET', uri: uri);

    final data = decoded['data'];
    if (data is! List) return const <TimeSlotModel>[];

    return data
        .whereType<Map>()
        .map((e) => TimeSlotModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<BookingModel> createBooking({
    required String timeSlotId,
  }) async {
    final uri = Uri.parse('$baseUrl/bookings');

    final res = await _client.post(
      uri,
      headers: _headers(json: true),
      body: jsonEncode({'timeSlotId': timeSlotId}),
    );

    final decoded = _decodeBody(res, method: 'POST', uri: uri);
    final data = _extractDataMap(decoded, method: 'POST', uri: uri);

    return BookingModel.fromJson(data);
  }

  Future<BookingModel> getBookingById({
    required String bookingId,
  }) async {
    final uri = Uri.parse('$baseUrl/bookings/$bookingId');

    final res = await _client.get(uri, headers: _headers());
    final decoded = _decodeBody(res, method: 'GET', uri: uri);
    final data = _extractDataMap(decoded, method: 'GET', uri: uri);

    return BookingModel.fromJson(data);
  }

  Future<ManualPaymentInfoModel> getManualPaymentInfo({
    required String gateway,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/payments/manual-payment-info/${gateway.trim()}',
    );

    final res = await _client.get(uri, headers: _headers());
    final decoded = _decodeBody(res, method: 'GET', uri: uri);
    final data = _extractDataMap(decoded, method: 'GET', uri: uri);

    return ManualPaymentInfoModel.fromJson(data);
  }

  Future<PaymentResultModel> initiateDepositPayment({
    required String bookingId,
    required String gateway,
  }) async {
    final uri = Uri.parse('$baseUrl/payments/initiate');

    final res = await _client.post(
      uri,
      headers: _headers(json: true),
      body: jsonEncode({
        'bookingId': bookingId.trim(),
        'gateway': gateway.trim(),
      }),
    );

    final decoded = _decodeBody(res, method: 'POST', uri: uri);
    final payload = _extractPayload(decoded);

    return PaymentResultModel.fromJson(payload);
  }

  Future<PaymentResultModel> initiateWalletPayment({
    required String bookingId,
    required String gateway,
  }) {
    return initiateDepositPayment(
      bookingId: bookingId,
      gateway: gateway,
    );
  }

  Future<PaymentUploadResultModel> uploadPaymentScreenshot({
    required String paymentId,
    required File screenshotFile,
    String? notes,
    String? transactionId,
    String? senderNumber,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/payments/${paymentId.trim()}/upload-screenshot',
    );

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers())
      ..files.add(
        await http.MultipartFile.fromPath(
          'screenshot',
          screenshotFile.path,
        ),
      );

    if (notes != null && notes.trim().isNotEmpty) {
      request.fields['notes'] = notes.trim();
    }

    if (transactionId != null && transactionId.trim().isNotEmpty) {
      request.fields['transactionId'] = transactionId.trim();
    }

    if (senderNumber != null && senderNumber.trim().isNotEmpty) {
      request.fields['senderNumber'] = senderNumber.trim();
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final decoded = _decodeBody(res, method: 'POST', uri: uri);
    final data = _extractDataMap(decoded, method: 'POST', uri: uri);

    return PaymentUploadResultModel.fromJson(data);
  }

  Future<PaymentVerificationStatusModel> getVerificationStatus({
    required String paymentId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/payments/${paymentId.trim()}/verification-status',
    );

    final res = await _client.get(uri, headers: _headers());
    final decoded = _decodeBody(res, method: 'GET', uri: uri);
    final data = _extractDataMap(decoded, method: 'GET', uri: uri);

    return PaymentVerificationStatusModel.fromJson(data);
  }

  Future<CancelBookingResultModel> cancelBooking({
    required String bookingId,
    String? reason,
  }) async {
    final uri = Uri.parse('$baseUrl/bookings/$bookingId/cancel');

    final body = <String, dynamic>{};
    if (reason != null && reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
    }

    final res = await _client.patch(
      uri,
      headers: _headers(json: true),
      body: jsonEncode(body),
    );

    final decoded = _decodeBody(res, method: 'PATCH', uri: uri);
    final payload = _extractPayload(decoded);

    return CancelBookingResultModel.fromJson(payload);
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
    final query = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (fieldId != null && fieldId.trim().isNotEmpty)
        'fieldId': fieldId.trim(),
      if (startDate != null) 'startDate': _isoDate(startDate),
      if (endDate != null) 'endDate': _isoDate(endDate),
    };

    final uri = Uri.parse('$baseUrl/bookings/my')
        .replace(queryParameters: query);

    final res = await _client.get(uri, headers: _headers());
    final decoded = _decodeBody(res, method: 'GET', uri: uri);
    final payload = _extractPayload(decoded);

    return BookingsListResult.fromJson(payload);
  }

  Future<QrCodeModel> getQrCode({
    required String bookingId,
  }) async {
    final uri = Uri.parse('$baseUrl/bookings/$bookingId/qr');

    final res = await _client.get(uri, headers: _headers());
    final decoded = _decodeBody(res, method: 'GET', uri: uri);
    final data = _extractDataMap(decoded, method: 'GET', uri: uri);

    return QrCodeModel.fromJson(data);
  }

  Map<String, dynamic> _decodeBody(
    http.Response res, {
    required String method,
    required Uri uri,
  }) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Request failed\n'
        '$method $uri\n'
        'Status: ${res.statusCode}\n'
        'Body: ${res.body}',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Invalid response format (expected JSON object)\n'
        '$method $uri\n'
        'Body: ${res.body}',
      );
    }

    return decoded;
  }

  Map<String, dynamic> _extractDataMap(
    Map<String, dynamic> decoded, {
    required String method,
    required Uri uri,
  }) {
    final data = decoded['data'];
    if (data is! Map) {
      throw Exception(
        'Invalid response format (expected data object)\n'
        '$method $uri\n'
        'Body: $decoded',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  Map<String, dynamic> _extractPayload(Map<String, dynamic> decoded) {
    final data = decoded['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return decoded;
  }

  Map<String, String> _headers({bool json = false}) {
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _isoDate(DateTime d) {
    final x = d.toLocal();
    final mm = x.month.toString().padLeft(2, '0');
    final dd = x.day.toString().padLeft(2, '0');
    return '${x.year}-$mm-$dd';
  }
}

class ManualPaymentInfoModel {
  final String gateway;
  final bool isAvailable;
  final Map<String, dynamic> instructions;
  final Map<String, dynamic> accountDetails;

  const ManualPaymentInfoModel({
    required this.gateway,
    required this.isAvailable,
    required this.instructions,
    required this.accountDetails,
  });

  String get instructionsAr => (instructions['ar'] ?? '').toString();
  String get instructionsEn => (instructions['en'] ?? '').toString();

  factory ManualPaymentInfoModel.fromJson(Map<String, dynamic> json) {
    return ManualPaymentInfoModel(
      gateway: (json['gateway'] ?? '').toString(),
      isAvailable: json['isAvailable'] == true,
      instructions: json['instructions'] is Map
          ? Map<String, dynamic>.from(json['instructions'] as Map)
          : const {},
      accountDetails: json['accountDetails'] is Map
          ? Map<String, dynamic>.from(json['accountDetails'] as Map)
          : const {},
    );
  }
}

class PaymentUploadResultModel {
  final String paymentId;
  final String screenshotUrl;
  final String verificationStatus;
  final int uploadAttempts;
  final int maxUploadAttempts;
  final Map<String, dynamic> message;

  const PaymentUploadResultModel({
    required this.paymentId,
    required this.screenshotUrl,
    required this.verificationStatus,
    required this.uploadAttempts,
    required this.maxUploadAttempts,
    required this.message,
  });

  String get messageAr => (message['ar'] ?? '').toString();
  String get messageEn => (message['en'] ?? '').toString();

  factory PaymentUploadResultModel.fromJson(Map<String, dynamic> json) {
    return PaymentUploadResultModel(
      paymentId: (json['paymentId'] ?? '').toString(),
      screenshotUrl: (json['screenshotUrl'] ?? '').toString(),
      verificationStatus: (json['verificationStatus'] ?? '').toString(),
      uploadAttempts: _toInt(json['uploadAttempts']),
      maxUploadAttempts: _toInt(json['maxUploadAttempts']),
      message: json['message'] is Map
          ? Map<String, dynamic>.from(json['message'] as Map)
          : const {},
    );
  }
}

class PaymentVerificationStatusModel {
  final String paymentId;
  final String referenceCode;
  final String verificationStatus;
  final String screenshotUrl;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final DateTime? paymentExpiresAt;
  final int uploadAttempts;
  final int maxUploadAttempts;
  final bool isFlagged;
  final String estimatedVerificationTime;

  const PaymentVerificationStatusModel({
    required this.paymentId,
    required this.referenceCode,
    required this.verificationStatus,
    required this.screenshotUrl,
    required this.submittedAt,
    required this.verifiedAt,
    required this.rejectionReason,
    required this.paymentExpiresAt,
    required this.uploadAttempts,
    required this.maxUploadAttempts,
    required this.isFlagged,
    required this.estimatedVerificationTime,
  });

  factory PaymentVerificationStatusModel.fromJson(Map<String, dynamic> json) {
    return PaymentVerificationStatusModel(
      paymentId: (json['paymentId'] ?? '').toString(),
      referenceCode: (json['referenceCode'] ?? '').toString(),
      verificationStatus: (json['verificationStatus'] ?? '').toString(),
      screenshotUrl: (json['screenshotUrl'] ?? '').toString(),
      submittedAt: _parseDateTime(json['submittedAt']),
      verifiedAt: _parseDateTime(json['verifiedAt']),
      rejectionReason: json['rejectionReason']?.toString(),
      paymentExpiresAt: _parseDateTime(json['paymentExpiresAt']),
      uploadAttempts: _toInt(json['uploadAttempts']),
      maxUploadAttempts: _toInt(json['maxUploadAttempts']),
      isFlagged: json['isFlagged'] == true,
      estimatedVerificationTime:
          (json['estimatedVerificationTime'] ?? '').toString(),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

int _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse('${value ?? ''}') ?? 0;
}