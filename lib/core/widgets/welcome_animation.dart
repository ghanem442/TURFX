import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// Professional animated welcome screen with role-specific messages
class WelcomeAnimation extends StatefulWidget {
  final String userName;
  final String userRole; // 'PLAYER', 'FIELD_OWNER', 'ADMIN'
  final VoidCallback onComplete;

  const WelcomeAnimation({
    super.key,
    required this.userName,
    required this.userRole,
    required this.onComplete,
  });

  @override
  State<WelcomeAnimation> createState() => _WelcomeAnimationState();
}

class _WelcomeAnimationState extends State<WelcomeAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late AnimationController _textController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    // Main animation controller
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Particle animation controller (continuous)
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Text animation controller
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Scale animation (zoom in effect)
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    // Fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeIn),
      ),
    );

    // Slide animation (from bottom)
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Rotate animation (subtle rotation)
    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _particleController,
        curve: Curves.linear,
      ),
    );

    // Start animations
    _startAnimations();
  }

  void _startAnimations() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Start main animation
    _mainController.forward();

    // Start text animation after a delay
    await Future.delayed(const Duration(milliseconds: 300));
    _textController.forward();

    // Complete after animation
    await Future.delayed(const Duration(milliseconds: 2500));
    HapticFeedback.lightImpact();
    widget.onComplete();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          // Animated particles background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ParticlesPainter(
                    animation: _particleController.value,
                    color: _getRoleColor(),
                  ),
                );
              },
            ),
          ),

          // Main content
          Center(
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Role icon with glow effect
                        Container(
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

                        const SizedBox(height: 40),

                        // Animated text
                        AnimatedBuilder(
                          animation: _textController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _slideAnimation.value),
                              child: Opacity(
                                opacity: _textController.value,
                                child: Column(
                                  children: [
                                    // User name
                                    Text(
                                      widget.userName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge
                                          ?.copyWith(
                                            color: _getRoleColor(),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 36,
                                            letterSpacing: 1.0,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),

                                    const SizedBox(height: 16),

                                    // Welcome message
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32),
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

                        // Animated loading indicator
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getRoleColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for animated particles background
class _ParticlesPainter extends CustomPainter {
  final double animation;
  final Color color;

  _ParticlesPainter({
    required this.animation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(25) // ~0.1
      ..style = PaintingStyle.fill;

    // Draw floating particles
    for (int i = 0; i < 20; i++) {
      final angle = (i * 18.0 + animation * 360) * math.pi / 180;
      final radius = 100.0 + (i * 20.0);
      final x = size.width / 2 + math.cos(angle) * radius;
      final y = size.height / 2 + math.sin(angle) * radius;
      final particleSize = 3.0 + (i % 3) * 2.0;

      canvas.drawCircle(
        Offset(x, y),
        particleSize,
        paint,
      );
    }

    // Draw orbiting circles
    for (int i = 0; i < 3; i++) {
      final angle = (animation * 360 + i * 120) * math.pi / 180;
      final radius = 150.0 + (i * 30.0);
      final x = size.width / 2 + math.cos(angle) * radius;
      final y = size.height / 2 + math.sin(angle) * radius;

      canvas.drawCircle(
        Offset(x, y),
        8.0,
        paint..color = color.withAlpha(38), // ~0.15
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
