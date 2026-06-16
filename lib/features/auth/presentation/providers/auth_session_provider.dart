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
  static const _bootTimeout = Duration(seconds: 10);

  @override
  AuthStatus build() => AuthStatus.unknown;

  Future<void> boot() async {
    final storage = ref.read(secureStorageProvider);

    try {
      // Read tokens from secure storage with generous timeout
      final access = await storage.getAccessToken().timeout(
        _bootTimeout,
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('Auth boot: getAccessToken timed out');
          }
          return null;
        },
      );
      
      final refresh = await storage.getRefreshToken().timeout(
        _bootTimeout,
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('Auth boot: getRefreshToken timed out');
          }
          return null;
        },
      );
      
      final userDataRaw = await storage.getUserData().timeout(
        _bootTimeout,
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('Auth boot: getUserData timed out');
          }
          return null;
        },
      );

      final accessOk = access != null && access.trim().isNotEmpty;
      final refreshOk = refresh != null && refresh.trim().isNotEmpty;

      // Update in-memory token providers
      ref.read(accessTokenProvider.notifier).state = accessOk ? access : null;
      ref.read(refreshTokenProvider.notifier).state = refreshOk ? refresh : null;

      // If we have at least an access token, consider user authenticated
      if (accessOk) {
        state = AuthStatus.authenticated;
        _restoreUser(userDataRaw);
        
        if (kDebugMode) {
          debugPrint(
            'Auth boot SUCCESS: Tokens restored from storage. '
            'access=${access?.substring(0, 20)}... refresh=${refreshOk ? "YES" : "NO"}',
          );
        }
      } else {
        // No valid tokens found - user needs to log in
        state = AuthStatus.unauthenticated;
        ref.read(authUserProvider.notifier).state = null;
        
        if (kDebugMode) {
          debugPrint('Auth boot: No valid tokens found -> unauthenticated');
        }
      }
    } catch (e, stackTrace) {
      // Storage read failed - treat as unauthenticated but don't clear storage
      // (in case it's a temporary issue)
      ref.read(accessTokenProvider.notifier).state = null;
      ref.read(refreshTokenProvider.notifier).state = null;
      ref.read(authUserProvider.notifier).state = null;

      state = AuthStatus.unauthenticated;

      if (kDebugMode) {
        debugPrint('Auth boot FAILED -> unauthenticated. Error: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final storage = ref.read(secureStorageProvider);

    // Save to secure storage first
    await storage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    // Then update in-memory state
    ref.read(accessTokenProvider.notifier).state = accessToken;
    ref.read(refreshTokenProvider.notifier).state = refreshToken;
    
    if (kDebugMode) {
      debugPrint('Tokens saved to secure storage. Access token: ${accessToken.substring(0, 20)}...');
    }
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
    if (kDebugMode) {
      debugPrint('Logout initiated - clearing all auth data');
    }
    
    final storage = ref.read(secureStorageProvider);

    // Clear secure storage
    await storage.clearAll();

    // Clear in-memory state
    ref.read(accessTokenProvider.notifier).state = null;
    ref.read(refreshTokenProvider.notifier).state = null;
    ref.read(authUserProvider.notifier).state = null;

    // Mark as unauthenticated
    state = AuthStatus.unauthenticated;
    
    // Trigger router refresh to redirect to login
    ref.read(routerRefreshProvider).refresh();
    
    if (kDebugMode) {
      debugPrint('Logout complete - redirecting to login');
    }
  }

  void markAuthenticated() {
    if (kDebugMode) {
      debugPrint('Marking user as authenticated');
    }
    
    state = AuthStatus.authenticated;
    ref.read(routerRefreshProvider).refresh();
  }
}

final authSessionProvider =
    NotifierProvider<AuthSession, AuthStatus>(AuthSession.new);