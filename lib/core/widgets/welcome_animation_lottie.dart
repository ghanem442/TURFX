import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:io';
import '../theme/app_theme.dart';

/// Professional animated welcome screen with Lottie animations
class WelcomeAnimationLottie extends StatefulWidget {
  final String userName;
  final String userRole; // 'PLAYER', 'FIELD_OWNER', 'ADMIN'
  final VoidCallback onComplete;

  const WelcomeAnimationLottie({
    super.key,
    required this.userName,
    required this.userRole,
    required this.onComplete,
  });

  @override
  State<WelcomeAnimationLottie> createState() => _WelcomeAnimationLottieState();
}

class _WelcomeAnimationLottieState extends State<WelcomeAnimationLottie>
    with TickerProviderStateMixin {
  late AnimationController _textController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeIn,
      ),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 2500));
    HapticFeedback.lightImpact();
    widget.onComplete();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _getWelcomeMessage() {
    final role = widget.userRole.trim().toUpperCase();
    switch (role) {
      case 'PLAYER':
        return 'Welcome, great player!';
      case 'FIELD_OWNER':
        return 'Your stadium is top-tier!';
      case 'ADMIN':
        return 'CEO of the ultimate pitch booking app!';
      default:
        return 'Welcome back!';
    }
  }

  String _getLottieAsset() {
    final role = widget.userRole.trim().toUpperCase();
    switch (role) {
      case 'PLAYER':
        return 'assets/animations/welcome_player.json';
      case 'FIELD_OWNER':
        return 'assets/animations/welcome_owner.json';
      case 'ADMIN':
        return 'assets/animations/welcome_admin.json';
      default:
        return 'assets/animations/welcome_player.json';
    }
  }

  IconData _getRoleIcon() {
    final role = widget.userRole.trim().toUpperCase();
    switch (role) {
      case 'PLAYER':
        return Icons.sports_soccer;
      case 'FIELD_OWNER':
        return Icons.stadium;
      case 'ADMIN':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor() {
    final role = widget.userRole.trim().toUpperCase();
    switch (role) {
      case 'PLAYER':
        return AppColors.green;
      case 'FIELD_OWNER':
        return AppColors.orange;
      case 'ADMIN':
        return Colors.purple;
      default:
        return AppColors.green;
    }
  }

  Widget _buildAnimation() {
    final lottieFile = File(_getLottieAsset());

    if (lottieFile.existsSync()) {
      return Lottie.asset(
        _getLottieAsset(),
        width: 200,
        height: 200,
        fit: BoxFit.contain,
      );
    }

    // Fallback to icon with animation
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _getRoleColor().withAlpha(76), // ~0.3
                  _getRoleColor().withAlpha(25), // ~0.1
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getRoleColor().withAlpha(51), // ~0.2
                ),
                child: Icon(
                  _getRoleIcon(),
                  size: 50,
                  color: _getRoleColor(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              _getRoleColor().withAlpha(25), // ~0.1
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie animation or fallback icon
              _buildAnimation(),

              const SizedBox(height: 40),

              // Animated text
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Column(
                        children: [
                          // User name with gradient
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                _getRoleColor(),
                                _getRoleColor().withAlpha(178), // ~0.7
                              ],
                            ).createShader(bounds),
                            child: Text(
                              widget.userName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 36,
                                    letterSpacing: 1.0,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Welcome message
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _getWelcomeMessage(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 20,
                                    letterSpacing: 0.5,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 60),

              // Animated dots loading indicator
              _AnimatedDots(color: _getRoleColor()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated dots loading indicator
class _AnimatedDots extends StatefulWidget {
  final Color color;

  const _AnimatedDots({required this.color});

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value - delay).clamp(0.0, 1.0);
            final scale = (value < 0.5)
                ? 1.0 + (value * 2) * 0.5
                : 1.5 - ((value - 0.5) * 2) * 0.5;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
