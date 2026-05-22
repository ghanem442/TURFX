import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

class CloudinaryUploadService {
  final ApiClient _api;

  CloudinaryUploadService(this._api);

  final Dio _cloudinaryDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 120),
    receiveTimeout: const Duration(seconds: 120),
  ));

  Future<Map<String, dynamic>> _getSignature() async {
    final response = await _api.dio.get('cloudinary/signature');

    if (kDebugMode) {
      debugPrint('[CLOUDINARY] signature response: ${response.data}');
    }

    final root = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : null;
    if (root == null) {
      throw Exception('Invalid signature response');
    }

    final data = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;
    return data;
  }

  Future<String> uploadImage({
    required File imageFile,
    void Function(int sent, int total)? onProgress,
  }) async {
    final sigData = await _getSignature();

    final cloudName = sigData['cloudName']?.toString();
    final apiKey = sigData['apiKey']?.toString();
    final signature = sigData['signature']?.toString();
    final timestamp = sigData['timestamp']?.toString();
    final folder = sigData['folder']?.toString();

    if (cloudName == null ||
        apiKey == null ||
        signature == null ||
        timestamp == null) {
      throw Exception('Missing Cloudinary signature parameters');
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename:
            'payment_proof_${timestamp}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
      'api_key': apiKey,
      'timestamp': timestamp,
      'signature': signature,
      if (folder != null && folder.isNotEmpty) 'folder': folder,
    });

    final response = await _cloudinaryDio.post(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      data: formData,
      onSendProgress: onProgress,
    );

    final url = response.data['secure_url']?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('Cloudinary did not return a secure_url');
    }
    return url;
  }
}
