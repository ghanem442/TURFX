import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

typedef ReadToken = String? Function();
typedef ReadRefreshToken = String? Function();
typedef SaveTokens = Future<void> Function({
  required String accessToken,
  String? refreshToken,
});
typedef Logout = Future<void> Function();
typedef OnSessionExpired = void Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required this.readAccessToken,
    required this.readRefreshToken,
    required this.saveTokens,
    required this.logout,
    this.onSessionExpired,
  }) : _dio = dio;

  final Dio _dio;
  final ReadToken readAccessToken;
  final ReadRefreshToken readRefreshToken;
  final SaveTokens saveTokens;
  final Logout logout;
  final OnSessionExpired? onSessionExpired;

  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  bool _isAuthRefreshRequest(RequestOptions options) {
    final path = options.path.toLowerCase();
    return path.contains('auth/refresh');
  }

  bool _shouldSkipAuthHeader(RequestOptions options) {
    final path = options.path.toLowerCase();

    return path.contains('auth/login') ||
        path.contains('auth/register') ||
        path.contains('auth/refresh') ||
        path.contains('auth/forgot-password') ||
        path.contains('auth/reset-password');
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_shouldSkipAuthHeader(options)) {
      handler.next(options);
      return;
    }

    final token = readAccessToken();
    if (token != null && token.trim().isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final status = response.statusCode;
    final request = response.requestOptions;

    // Reject 401 response to trigger onError if it is not already a retry or a refresh request
    final alreadyRetried = request.extra['__retried__'] == true;
    if (status == 401 && !alreadyRetried && !_isAuthRefreshRequest(request)) {
      _log('401 detected in response -> turning into DioException to trigger token refresh');
      handler.reject(
        DioException(
          requestOptions: request,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Unauthorized (401)',
        ),
      );
      return;
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final request = err.requestOptions;

    final alreadyRetried = request.extra['__retried__'] == true;

    if (status != 401 || alreadyRetried || _isAuthRefreshRequest(request)) {
      handler.next(err);
      return;
    }

    final refreshToken = readRefreshToken();
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      await logout();
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      _log('401 detected -> refresh in progress, queuing request');
      _pendingRequests.add(_PendingRequest(err: err, handler: handler));
      return;
    }

    _isRefreshing = true;

    try {
      _log('401 detected -> attempting token refresh');

      final res = await _dio.post(
        'auth/refresh',
        data: {'refreshToken': refreshToken.trim()},
        options: Options(
          headers: {'Authorization': null},
          extra: {'skipAuthRefresh': true},
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final raw = res.data;
      final statusCode = res.statusCode;

      if (statusCode == null || statusCode >= 400 || raw is! Map) {
        await _clearPendingAndLogout();
        handler.next(err);
        return;
      }

      final body = raw.cast<String, dynamic>();

      String newAccess = '';
      String? newRefresh;

      final dynamic bodyData = body['data'];

      if (bodyData is Map) {
        final mapData = bodyData.cast<String, dynamic>();
        final tokens = mapData['tokens'];

        final source = tokens is Map
            ? tokens.cast<String, dynamic>()
            : mapData;

        newAccess =
            (source['accessToken'] ?? source['access_token'] ?? '')
                .toString()
                .trim();

        final rt = source['refreshToken'] ?? source['refresh_token'];
        newRefresh = rt?.toString().trim();
      } else {
        newAccess =
            (body['accessToken'] ?? body['access_token'] ?? '')
                .toString()
                .trim();

        final rt = body['refreshToken'] ?? body['refresh_token'];
        newRefresh = rt?.toString().trim();
      }

      if (newAccess.isEmpty) {
        _log('Refresh failed: missing access token');
        await _clearPendingAndLogout();
        handler.next(err);
        return;
      }

      await saveTokens(accessToken: newAccess, refreshToken: newRefresh);

      await _retryRequest(request, newAccess, handler);
      await _retryPendingRequests(newAccess);
    } catch (e) {
      _log('Refresh exception -> $e');
      await _clearPendingAndLogout();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _retryRequest(
    RequestOptions request,
    String newAccess,
    ErrorInterceptorHandler handler,
  ) async {
    final retryOptions = Options(
      method: request.method,
      headers: Map<String, dynamic>.from(request.headers)
        ..['Authorization'] = 'Bearer $newAccess',
      responseType: request.responseType,
      contentType: request.contentType,
      extra: Map<String, dynamic>.from(request.extra)..['__retried__'] = true,
      followRedirects: request.followRedirects,
      receiveDataWhenStatusError: request.receiveDataWhenStatusError,
      sendTimeout: request.sendTimeout,
      receiveTimeout: request.receiveTimeout,
      validateStatus: request.validateStatus,
    );

    _log('Retrying original request after refresh -> ${request.method} ${request.path}');

    final retryResponse = await _dio.request(
      request.path,
      data: request.data,
      queryParameters: request.queryParameters,
      cancelToken: request.cancelToken,
      options: retryOptions,
      onReceiveProgress: request.onReceiveProgress,
      onSendProgress: request.onSendProgress,
    );

    handler.resolve(retryResponse);
  }

  Future<void> _retryPendingRequests(String newAccess) async {
    final pending = List<_PendingRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    for (final pendingRequest in pending) {
      try {
        await _retryRequest(
          pendingRequest.err.requestOptions,
          newAccess,
          pendingRequest.handler,
        );
      } catch (e) {
        pendingRequest.handler.next(pendingRequest.err);
      }
    }
  }

  Future<void> _clearPendingAndLogout() async {
    final pending = List<_PendingRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    await logout();

    onSessionExpired?.call();

    for (final pendingRequest in pending) {
      pendingRequest.handler.next(pendingRequest.err);
    }
  }
}

class _PendingRequest {
  final DioException err;
  final ErrorInterceptorHandler handler;

  _PendingRequest({required this.err, required this.handler});
}