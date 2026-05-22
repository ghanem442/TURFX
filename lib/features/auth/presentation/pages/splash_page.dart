import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_button.dart';
import '../../data/auth_repository_provider.dart';
import '../providers/auth_session_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _started = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startBoot();
    });
  }

  String _homeRouteForRole(String? role) {
    final normalized = (role ?? '').trim().toUpperCase();

    if (normalized == 'ADMIN') return '/admin/dashboard';
    if (normalized == 'FIELD_OWNER') return '/owner';

    return '/home';
  }

  Future<void> _startBoot() async {
    if (_started) return;
    _started = true;

    try {
      final session = ref.read(authSessionProvider.notifier);
      final repo = ref.read(authRepositoryProvider);

      await session.boot();

      if (!mounted) return;

      final auth = ref.read(authSessionProvider);

      if (auth != AuthStatus.authenticated) {
        context.go('/login');
        return;
      }

      final me = await repo.getCurrentUser();

      if (!mounted) return;

      if (me.success != true) {
        await session.logout();
        if (!mounted) return;
        context.go('/login');
        return;
      }

      final data = me.data;
      final userMap = (data['user'] is Map)
          ? (data['user'] as Map).cast<String, dynamic>()
          : (data['data'] is Map)
              ? (data['data'] as Map).cast<String, dynamic>()
              : data;

      final email = (userMap['email'] ?? '').toString().trim();
      final isVerified = userMap['isVerified'] == true;
      final name = userMap['name']?.toString().trim();
      final role = userMap['role']?.toString();
      final id = userMap['id']?.toString();

      if (email.isEmpty) {
        await session.logout();
        if (!mounted) return;
        context.go('/login');
        return;
      }

      session.saveUser(
        email: email,
        isVerified: isVerified,
        name: (name != null && name.isNotEmpty) ? name : null,
        role: role,
        id: id,
      );

      if (!mounted) return;

      if (!isVerified) {
        context.go('/verify-email', extra: email);
        return;
      }

      context.go(_homeRouteForRole(role));
    } catch (e) {
      final session = ref.read(authSessionProvider.notifier);
      await session.logout();

      if (!mounted) return;
      context.go('/login');
    } finally {
      _started = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_soccer, size: 64),
              const SizedBox(height: 14),
              const Text(
                'Football Booking',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
              ),
              const SizedBox(height: 8),
              const Text('جاري التحضير...'),
              const SizedBox(height: 16),
              const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 18),
              AppButton(
                text: 'إعادة المحاولة',
                width: 200,
                onPressed: _startBoot,
              ),
            ],
          ),
        ),
      ),
    );
  }
}