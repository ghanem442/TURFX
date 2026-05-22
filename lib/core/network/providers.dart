import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth_interceptor.dart';
import 'base_url.dart';
import 'package:football/core/routing/app_router.dart';
import 'package:football/features/auth/presentation/providers/auth_session_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final resolvedBaseUrl = resolveApiBaseUrl();
  final api = ApiClient(baseUrl: resolvedBaseUrl);

  if (kDebugMode) {
    debugPrint('API BaseUrl = $resolvedBaseUrl');
  }

  api.dio.interceptors.add(
    AuthInterceptor(
      dio: api.dio,
      readAccessToken: () {
        final token = ref.read(accessTokenProvider);
        if (kDebugMode) {
          debugPrint(
            'ACCESS TOKEN = ${token == null || token.isEmpty ? "EMPTY" : "EXISTS"}',
          );
        }
        return token;
      },
      readRefreshToken: () {
        final token = ref.read(refreshTokenProvider);
        if (kDebugMode) {
          debugPrint(
            'REFRESH TOKEN = ${token == null || token.isEmpty ? "EMPTY" : "EXISTS"}',
          );
        }
        return token;
      },
      saveTokens: ({required accessToken, String? refreshToken}) async {
        final oldRefresh = ref.read(refreshTokenProvider);

        final finalRefresh =
            (refreshToken != null && refreshToken.trim().isNotEmpty)
            ? refreshToken.trim()
            : (oldRefresh ?? '').trim();

        await ref.read(authSessionProvider.notifier).saveTokens(
          accessToken: accessToken.trim(),
          refreshToken: finalRefresh,
        );
      },
      logout: () async {
        await ref.read(authSessionProvider.notifier).logout();
      },
      onSessionExpired: () {
        final navigator = rootNavigatorKey.currentState;
        if (navigator != null) {
          navigator.pushNamedAndRemoveUntil('/login', (_) => false);
        }
      },
    ),
  );

  return api;
});