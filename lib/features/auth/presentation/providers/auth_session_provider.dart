import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/storage/providers.dart';
import 'package:football/core/routing/router_refresh.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

final accessTokenProvider = StateProvider<String?>((ref) => null);
final refreshTokenProvider = StateProvider<String?>((ref) => null);

@immutable
class AuthUser {
  const AuthUser({
    required this.email,
    required this.isVerified,
    this.name,
    this.role,
    this.id,
  });

  final String email;
  final bool isVerified;
  final String? name;
  final String? role;
  final String? id;

  AuthUser copyWith({
    String? email,
    bool? isVerified,
    String? name,
    String? role,
    String? id,
  }) {
    return AuthUser(
      email: email ?? this.email,
      isVerified: isVerified ?? this.isVerified,
      name: name ?? this.name,
      role: role ?? this.role,
      id: id ?? this.id,
    );
  }
}

final authUserProvider = StateProvider<AuthUser?>((ref) => null);

final authIsVerifiedProvider = Provider<bool>((ref) {
  return ref.watch(authUserProvider.select((u) => u?.isVerified ?? true));
});

final authEmailProvider = Provider<String?>((ref) {
  return ref.watch(authUserProvider.select((u) => u?.email));
});

final authUserNameProvider = Provider<String?>((ref) {
  return ref.watch(authUserProvider.select((u) => u?.name));
});

final authUserRoleProvider = Provider<String?>((ref) {
  return ref.watch(authUserProvider.select((u) => u?.role));
});

class AuthSession extends Notifier<AuthStatus> {
  static const _bootTimeout = Duration(seconds: 2);

  @override
  AuthStatus build() => AuthStatus.unknown;

  Future<void> boot() async {
    final storage = ref.read(secureStorageProvider);

    try {
      final accessFuture = storage.getAccessToken();
      final refreshFuture = storage.getRefreshToken();
      final userDataFuture = storage.getUserData();

      final access = await accessFuture.timeout(_bootTimeout);
      final refresh = await refreshFuture.timeout(_bootTimeout);
      final userDataRaw = await userDataFuture.timeout(_bootTimeout);

      final accessOk = access != null && access.trim().isNotEmpty;
      final refreshOk = refresh != null && refresh.trim().isNotEmpty;

      ref.read(accessTokenProvider.notifier).state = accessOk ? access : null;
      ref.read(refreshTokenProvider.notifier).state = refreshOk ? refresh : null;

      if (accessOk) {
        state = AuthStatus.authenticated;
        _restoreUser(userDataRaw);
      } else {
        state = AuthStatus.unauthenticated;
        ref.read(authUserProvider.notifier).state = null;
      }

      if (kDebugMode) {
        debugPrint(
          'Auth boot done. access=${accessOk ? "YES" : "NO"} refresh=${refreshOk ? "YES" : "NO"} status=$state',
        );
      }
    } catch (e) {
      ref.read(accessTokenProvider.notifier).state = null;
      ref.read(refreshTokenProvider.notifier).state = null;
      ref.read(authUserProvider.notifier).state = null;

      state = AuthStatus.unauthenticated;

      if (kDebugMode) {
        debugPrint('Auth boot failed -> unauthenticated. Error: $e');
      }
      ref.read(routerRefreshProvider).refresh();
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final storage = ref.read(secureStorageProvider);

    await storage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    ref.read(accessTokenProvider.notifier).state = accessToken;
    ref.read(refreshTokenProvider.notifier).state = refreshToken;
  }

  void saveUser({
    required String email,
    required bool isVerified,
    String? name,
    String? role,
    String? id,
  }) {
    final user = AuthUser(
      email: email.trim(),
      isVerified: isVerified,
      name: name?.trim(),
      role: role,
      id: id,
    );
    ref.read(authUserProvider.notifier).state = user;

    final storage = ref.read(secureStorageProvider);
    final payload = jsonEncode({
      'email': user.email,
      'isVerified': user.isVerified,
      if (user.name != null) 'name': user.name,
      if (user.role != null) 'role': user.role,
      if (user.id != null) 'id': user.id,
    });
    storage.saveUserData(payload);
  }

  void _restoreUser(String? raw) {
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      ref.read(authUserProvider.notifier).state = AuthUser(
        email: (map['email'] ?? '').toString(),
        isVerified: map['isVerified'] == true,
        name: map['name']?.toString(),
        role: map['role']?.toString(),
        id: map['id']?.toString(),
      );
    } catch (_) {
      // ignore corrupt persisted user data
    }
  }

  void setUserFromAuthResponse(Map<String, dynamic> data) {
    final userMap = (data['user'] is Map) ? (data['user'] as Map) : null;
    if (userMap == null) return;

    final email = (userMap['email'] ?? '').toString().trim();
    if (email.isEmpty) return;

    final name = userMap['name']?.toString().trim();
    final isVerified = userMap['isVerified'] == true;
    final role = userMap['role']?.toString();
    final id = userMap['id']?.toString();

    saveUser(
      email: email,
      isVerified: isVerified,
      name: (name != null && name.isNotEmpty) ? name : null,
      role: role,
      id: id,
    );
  }

  void markVerified() {
    final current = ref.read(authUserProvider);
    if (current == null) return;

    ref.read(authUserProvider.notifier).state =
        current.copyWith(isVerified: true);
    ref.read(routerRefreshProvider).refresh();
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);

    await storage.clearAll();

    ref.read(accessTokenProvider.notifier).state = null;
    ref.read(refreshTokenProvider.notifier).state = null;
    ref.read(authUserProvider.notifier).state = null;

    state = AuthStatus.unauthenticated;
    ref.read(routerRefreshProvider).refresh();
  }

  void markAuthenticated() {
    state = AuthStatus.authenticated;
    ref.read(routerRefreshProvider).refresh();
  }
}

final authSessionProvider =
    NotifierProvider<AuthSession, AuthStatus>(AuthSession.new);