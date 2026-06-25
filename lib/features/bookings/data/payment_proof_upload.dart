import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/base_url.dart';
import 'package:football/core/network/media_url.dart';

/// Uploads payment proof to your **Railway/backend** (multipart), then the app
/// sends the returned URL as `screenshotUrl` to `POST .../upload-screenshot`.
///
/// Configure the upload route (relative to `/api/v1/`) if your Nest path differs:
/// `--dart-define=PAYMENT_PROOF_UPLOAD_PATH=uploads/payment-proof`
///
/// Form fields sent: **[PAYMENT_PROOF_FILE_FIELD]** (default `file`) + `paymentId`.
/// Backend must return JSON containing one of: `data.url`, `url`, `fileUrl`,
/// `screenshotUrl`, `publicUrl`, `path` (same shapes as typical Nest `success` wrappers).
class PaymentProofUpload {
  PaymentProofUpload._();

  static const String uploadPath = String.fromEnvironment(
    'PAYMENT_PROOF_UPLOAD_PATH',
    defaultValue: 'uploads/payment-proof',
  );

  static const String fileFieldName = String.fromEnvironment(
    'PAYMENT_PROOF_FILE_FIELD',
    defaultValue: 'file',
  );

  /// Resolves the full upload URI from base URL and configured path
  static Uri uploadUri() {
    final base = resolveApiBaseUrl().trim();
    final path = uploadPath.trim().startsWith('/')
        ? uploadPath.trim().substring(1)
        : uploadPath.trim();
    final joined = base.endsWith('/') ? '$base$path' : '$base/$path';
    return Uri.parse(joined);
  }

  static String parseUploadResponseUrl(dynamic raw) {
    if (raw == null) {
      throw Exception('رد فارغ من سيرفر رفع الملف');
    }
    if (raw is! Map) {
      throw Exception('رد غير صالح من سيرفر رفع الملف');
    }
    final root = Map<String, dynamic>.from(raw);

    if (kDebugMode) {
      debugPrint('[PAYMENT_PROOF_UPLOAD] raw response -> $root');
    }

    String? pick(Map<String, dynamic> m) {
      for (final key in [
        'screenshotUrl',
        'url',
        'fileUrl',
        'publicUrl',
        'path',
        'filePath',
      ]) {
        final v = m[key]?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    if (root['data'] is Map) {
      final d = Map<String, dynamic>.from(root['data'] as Map);
      final hit = pick(d);
      if (hit != null) return resolvePublicMediaUrl(hit);
    }

    final top = pick(root);
    if (top != null) return resolvePublicMediaUrl(top);

    throw Exception(
      'سيرفر الرفع لم يرجع رابط الملف. تأكد من مسار $uploadPath وشكل الـ JSON '
      '(مثلاً success + data.url) أو عرّف PAYMENT_PROOF_UPLOAD_PATH.',
    );
  }

  static Future<String> uploadWithApiClient({
    required ApiClient api,
    required File file,
    required String paymentId,
  }) async {
    final resolvedPaymentId = paymentId.trim();
    if (resolvedPaymentId.isEmpty) {
      throw Exception('معرّف الدفع غير صالح');
    }

    final rawName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'proof.jpg';
    final safeName = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final formData = FormData.fromMap({
      fileFieldName: await MultipartFile.fromFile(
        file.path,
        filename: safeName,
      ),
      'paymentId': resolvedPaymentId,
    });

    if (kDebugMode) {
      debugPrint(
        '[PAYMENT_PROOF_UPLOAD] POST $uploadPath field=$fileFieldName paymentId=$resolvedPaymentId',
      );
    }

    final res = await api.post(
      uploadPath,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    return parseUploadResponseUrl(res.data);
  }

}
