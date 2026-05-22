import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import 'package:football/features/auth/presentation/providers/auth_session_provider.dart';

class LoginController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);

      // Single login attempt - no retry logic
      final res = await repo.login(email: email, password: password);

      // Check if response is successful
      if (res.success != true) {
        throw Exception(res.message ?? 'Login failed');
      }

      final dynamic rawData = res.data;
      
      if (kDebugMode) {
        debugPrint('Login response received: ${rawData.runtimeType}');
      }

      if (rawData is! Map<String, dynamic>) {
        throw Exception("Invalid login response: data is not a map");
      }

      // Extract tokens with better error handling
      final tokensNode = rawData["tokens"];
      
      if (kDebugMode) {
        debugPrint('Tokens node: $tokensNode (${tokensNode.runtimeType})');
      }

      if (tokensNode == null) {
        throw Exception("Invalid login response: tokens field is null");
      }

      if (tokensNode is! Map) {
        throw Exception("Invalid login response: tokens is not a map (got ${tokensNode.runtimeType})");
      }

      final tokens = tokensNode.cast<String, dynamic>();

      final accessToken = (tokens["accessToken"] ?? "").toString().trim();
      final refreshToken = (tokens["refreshToken"] ?? "").toString().trim();

      if (kDebugMode) {
        debugPrint('Access token length: ${accessToken.length}');
        debugPrint('Refresh token length: ${refreshToken.length}');
      }

      if (accessToken.isEmpty) {
        throw Exception("Login failed: accessToken is empty");
      }
      if (refreshToken.isEmpty) {
        throw Exception("Login failed: refreshToken is empty");
      }

      // Save tokens BEFORE setting user data or marking authenticated
      await ref.read(authSessionProvider.notifier).saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );

      if (kDebugMode) {
        debugPrint('Tokens saved successfully');
      }

      // Set user data from response
      ref.read(authSessionProvider.notifier).setUserFromAuthResponse(rawData);

      if (kDebugMode) {
        debugPrint('User data set from response');
      }

      // Mark as authenticated (this triggers navigation)
      ref.read(authSessionProvider.notifier).markAuthenticated();

      if (kDebugMode) {
        debugPrint('Login completed successfully');
      }
    });
  }
}