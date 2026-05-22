import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'base_url.dart';

class ApiClient {
  ApiClient({
    String? baseUrl,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: _normalizeBaseUrl(baseUrl ?? resolveApiBaseUrl()),
            responseType: ResponseType.json,
            validateStatus: _validateStatus,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            sendTimeout: kIsWeb ? null : const Duration(seconds: 120),
            connectTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 120),
          ),
        ) {
    _log('API BASE URL -> ${dio.options.baseUrl}');

    // Retry on 429 (Too Many Requests) with exponential backoff
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException err, ErrorInterceptorHandler handler) async {
          final statusCode = err.response?.statusCode;
          final extra = err.requestOptions.extra;
          final retryCount = (extra['__retryCount'] as int?) ?? 0;

          if (statusCode == 429 && retryCount < 3) {
            final delay = Duration(seconds: 1 << retryCount);
            _log(
              '429 detected -> waiting ${delay.inSeconds}s '
              'before retry #${retryCount + 1}',
            );
            await Future.delayed(delay);

            try {
              final response = await dio.request(
                err.requestOptions.path,
                data: err.requestOptions.data,
                queryParameters: err.requestOptions.queryParameters,
                options: Options(
                  method: err.requestOptions.method,
                  headers: err.requestOptions.headers,
                  extra: {
                    ...err.requestOptions.extra,
                    '__retryCount': retryCount + 1,
                  },
                  responseType: err.requestOptions.responseType,
                  contentType: err.requestOptions.contentType,
                ),
              );
              handler.resolve(response);
              return;
            } catch (_) {
              handler.next(err);
              return;
            }
          }

          handler.next(err);
        },
      ),
    );

    // Logging
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }

          _log('REQUEST -> ${options.method} ${options.uri}');
          _log('HEADERS -> ${_redactHeaders(options.headers)}');
          _log('DATA -> ${_redactData(options.data)}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          _log('RESPONSE -> ${response.statusCode}');
          _log('DATA -> ${response.data}');
          handler.next(response);
        },
        onError: (e, handler) {
          _log('ERROR -> ${e.message}');
          handler.next(e);
        },
      ),
    );
  }

  final Dio dio;

  // ✅ TOKEN
  static String? _token;

  static void setToken(String token) {
    _token = token;
  }

  static void clearToken() {
    _token = null;
  }

  static String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  static bool _validateStatus(int? status) {
    return status != null && status >= 200 && status < 300;
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static String _redactHeaders(Map<String, dynamic>? headers) {
    if (headers == null || headers.isEmpty) return '{}';
    final copy = Map<String, dynamic>.from(headers);
    final auth = copy['Authorization'];
    if (auth is String && auth.trim().isNotEmpty) {
      copy['Authorization'] = 'Bearer ***';
    }
    return copy.toString();
  }

  static String _redactData(dynamic data) {
    if (data == null) return 'null';
    if (data is! Map<String, dynamic>) return data.toString();
    final copy = Map<String, dynamic>.from(data);
    const sensitive = {
      'password',
      'cardNumber',
      'cvv',
      'cardCvv',
      'pin',
      'secret',
      'token',
    };
    for (final key in copy.keys) {
      final lower = key.toLowerCase();
      if (sensitive.any((s) => lower.contains(s))) {
        copy[key] = '***';
      }
    }
    return copy.toString();
  }

  String _fixPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Request path cannot be empty');
    }
    return trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  }

  // ========================
  // ✅ FULL METHODS (FIX)
  // ========================

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.get(
      _fixPath(path),
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.post(
      _fixPath(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.patch(
      _fixPath(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.put(
      _fixPath(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return dio.delete(
      _fixPath(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}