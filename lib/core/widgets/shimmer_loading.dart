import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Shimmer loading skeleton for field cards
class FieldCardSkeleton extends StatelessWidget {
  const FieldCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            _ShimmerBox(
              width: double.infinity,
              height: 160,
              borderRadius: 12,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            // Title
            _ShimmerBox(
              width: 200,
              height: 20,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            // Subtitle
            _ShimmerBox(
              width: 150,
              height: 16,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            // Price and button row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ShimmerBox(
                  width: 80,
                  height: 24,
                  isDark: isDark,
                ),
                _ShimmerBox(
                  width: 100,
                  height: 36,
                  borderRadius: 8,
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading skeleton for time slots
class TimeSlotSkeleton extends StatelessWidget {
  const TimeSlotSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return _ShimmerBox(
      width: double.infinity,
      height: 60,
      borderRadius: 12,
      isDark: isDark,
    );
  }
}

/// Shimmer loading skeleton for booking cards
class BookingCardSkeleton extends StatelessWidget {
  const BookingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ShimmerBox(width: 150, height: 20, isDark: isDark),
                _ShimmerBox(width: 80, height: 24, borderRadius: 12, isDark: isDark),
              ],
            ),
            const SizedBox(height: 12),
            _ShimmerBox(width: 200, height: 16, isDark: isDark),
            const SizedBox(height: 8),
            _ShimmerBox(width: 120, height: 16, isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isDark;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkCard : const Color(0xFFE0E0E0),
      highlightColor: isDark ? AppColors.darkSurface : const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Sporty loading indicator
class SportyLoadingIndicator extends StatelessWidget {
  final Color? color;
  final double size;

  const SportyLoadingIndicator({
    super.key,
    this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          color: color ?? AppColors.green,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}
