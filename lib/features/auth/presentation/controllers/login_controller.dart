import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import 'package:football/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:football/core/notifications/push_token_sync_service.dart';

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

      final res = await repo.login(email: email, password: password);

      final dynamic rawData = res.data;
      if (rawData is! Map<String, dynamic>) {
        throw Exception("Invalid login response: data is not a map");
      }

      final tokensNode = rawData["tokens"];
      if (tokensNode is! Map) {
        throw Exception("Invalid login response: tokens missing");
      }

      final tokens = tokensNode.cast<String, dynamic>();

      final accessToken = (tokens["accessToken"] ?? "").toString();
      final refreshToken = (tokens["refreshToken"] ?? "").toString();

      if (accessToken.isEmpty) {
        throw Exception("Login failed: accessToken missing");
      }
      if (refreshToken.isEmpty) {
        throw Exception("Login failed: refreshToken missing");
      }

      await ref.read(authSessionProvider.notifier).saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );

      ref.read(authSessionProvider.notifier).setUserFromAuthResponse(rawData);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await ref.read(pushTokenSyncServiceProvider).syncNow();
    });
  }
}