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

class _SplashPageState extends ConsumerState<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoRotation;
  late Animation<double> _glowScale;
  late Animation<Offset> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _loadingOpacity;

  bool _started = false;
  bool _showRetryButton = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _logoRotation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _glowScale = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.9, curve: Curves.easeInOutBack),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    _loadingOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startBoot();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

    final stopwatch = Stopwatch()..start();

    try {
      final session = ref.read(authSessionProvider.notifier);
      final repo = ref.read(authRepositoryProvider);

      await session.boot();

      if (!mounted) return;

      final auth = ref.read(authSessionProvider);

      if (auth != AuthStatus.authenticated) {
        await _delayTransition(stopwatch);
        if (!mounted) return;
        context.go('/login');
        return;
      }

      final me = await repo.getCurrentUser();

      if (!mounted) return;

      if (me.success != true) {
        await session.logout();
        await _delayTransition(stopwatch);
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
        await _delayTransition(stopwatch);
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
        await _delayTransition(stopwatch);
        if (!mounted) return;
        context.go('/verify-email', extra: email);
        return;
      }

      await _delayTransition(stopwatch);
      if (!mounted) return;
      context.go(_homeRouteForRole(role));
    } catch (e) {
      if (mounted) {
        setState(() {
          _showRetryButton = true;
        });
      }
      final session = ref.read(authSessionProvider.notifier);
      await session.logout();

      // Wait for delay to let the user see what's happening or try to retry
      await _delayTransition(stopwatch);
      if (!mounted) return;
      if (!_showRetryButton) {
        context.go('/login');
      }
    } finally {
      _started = false;
    }
  }

  Future<void> _delayTransition(Stopwatch stopwatch) async {
    const minDuration = Duration(seconds: 3);
    final elapsed = stopwatch.elapsed;
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0F1D), // Near Black
              Color(0xFF071911), // Subtle Forest Green Dark Glow
              Color(0xFF020408), // Pitch Black
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Stadium light radial glow effect
            Center(
              child: AnimatedBuilder(
                animation: _glowScale,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _glowScale.value,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF10B981).withAlpha(38), // Emerald glow (0.15 opacity)
                            const Color(0xFF10B981).withAlpha(10), // (0.04 opacity)
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Logo
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Transform.rotate(
                              angle: _logoRotation.value * 3.14159,
                              child: Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF0F172A),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withAlpha(64), // (0.25 opacity)
                                      blurRadius: 30,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withAlpha(89), // (0.35 opacity)
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.sports_soccer,
                                  size: 68,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 36),
                    
                    // Animated App Name and Arabic subtitle
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _textOpacity.value,
                          child: FractionalTranslation(
                            translation: _textSlide.value,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Football Booking',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 26,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'TURFX',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 48),
                    
                    // Animated Loader and Retry Option
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _loadingOpacity.value,
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 140,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: const LinearProgressIndicator(
                                minHeight: 3,
                                backgroundColor: Color(0xFF1E293B),
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                          if (_showRetryButton) ...[
                            const SizedBox(height: 28),
                            AppButton(
                              text: 'إعادة المحاولة',
                              width: 200,
                              onPressed: () async {
                                setState(() {
                                  _showRetryButton = false;
                                });
                                _controller.reset();
                                _controller.forward();
                                await _startBoot();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}