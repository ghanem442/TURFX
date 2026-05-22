# Quick Reference - UI/UX Components

## 🎨 Colors

```dart
import 'package:football/core/theme/app_theme.dart';

// Primary
AppColors.green        // #00C853 - Main brand color
AppColors.darkGreen    // #007C30 - Gradient accent
AppColors.orange       // #FF6D00 - CTA buttons

// Dark Theme
AppColors.darkBg       // #0D0D0D - Background
AppColors.darkCard     // #1A1A1A - Cards
AppColors.darkSurface  // #242424 - Surface elements
AppColors.darkText     // #FFFFFF - Text
AppColors.darkSubText  // #9E9E9E - Secondary text
```

---

## 🔘 Buttons

```dart
import 'package:football/core/widgets/animated_app_button.dart';

// Primary button
AnimatedAppButton(
  text: 'Book Now',
  onPressed: () { },
)

// With icon
AnimatedAppButton(
  text: 'Continue',
  icon: Icons.arrow_forward,
  onPressed: () { },
)

// Outlined
AnimatedAppButton(
  text: 'Cancel',
  isOutlined: true,
  onPressed: () { },
)

// Loading state
AnimatedAppButton(
  text: 'Processing...',
  isLoading: true,
  onPressed: null,
)

// Custom colors
AnimatedAppButton(
  text: 'Delete',
  backgroundColor: Colors.red,
  onPressed: () { },
)
```

---

## ⏳ Loading States

```dart
import 'package:football/core/widgets/shimmer_loading.dart';

// Field card skeleton
const FieldCardSkeleton()

// Time slot skeleton
const TimeSlotSkeleton()

// Booking card skeleton
const BookingCardSkeleton()

// Circular loader
const SportyLoadingIndicator()

// Custom size
SportyLoadingIndicator(
  size: 60,
  color: AppColors.orange,
)
```

---

## 🎭 Animations

```dart
import 'package:animate_do/animate_do.dart';

// Fade in from bottom
FadeInUp(
  duration: const Duration(milliseconds: 400),
  child: YourWidget(),
)

// With delay (for lists)
FadeInUp(
  delay: Duration(milliseconds: 100 * index),
  child: YourWidget(),
)

// Fade in
FadeIn(
  duration: const Duration(milliseconds: 300),
  child: YourWidget(),
)

// Slide in from right
SlideInRight(
  duration: const Duration(milliseconds: 400),
  child: YourWidget(),
)

// Zoom in
ZoomIn(
  duration: const Duration(milliseconds: 300),
  child: YourWidget(),
)
```

---

## 📢 Notifications

```dart
import 'package:football/core/widgets/sporty_snackbar.dart';

// Success
showSportySnackBar(
  context,
  message: 'Booking confirmed!',
  type: SnackBarType.success,
)

// Error
showSportySnackBar(
  context,
  message: 'Something went wrong',
  type: SnackBarType.error,
)

// Info
showSportySnackBar(
  context,
  message: 'Please select a time slot',
  type: SnackBarType.info,
)

// Warning
showSportySnackBar(
  context,
  message: 'Only 5 minutes remaining',
  type: SnackBarType.warning,
)

// Custom duration
showSportySnackBar(
  context,
  message: 'Quick message',
  type: SnackBarType.info,
  duration: const Duration(seconds: 2),
)
```

---

## 📳 Haptic Feedback

```dart
import 'package:football/core/utils/haptic_utils.dart';

// Light tap (selections)
HapticUtils.light();

// Medium tap (buttons)
HapticUtils.medium();

// Heavy tap (confirmations)
HapticUtils.heavy();

// Selection (pickers)
HapticUtils.selection();

// Error/warning
HapticUtils.error();
```

---

## 🎪 Hero Banner

```dart
import 'package:football/core/widgets/hero_banner.dart';

HeroBanner(
  title: 'Book Your Field',
  subtitle: 'Find the perfect spot to play',
)

// Custom height
HeroBanner(
  title: 'Welcome Back!',
  subtitle: 'Ready to play?',
  height: 180,
)
```

---

## 🎬 Lottie Animations

```dart
import 'package:lottie/lottie.dart';
import 'dart:io';

// With fallback
Widget buildSuccessAnimation() {
  final file = File('assets/animations/success_checkmark.json');
  
  if (file.existsSync()) {
    return Lottie.asset(
      'assets/animations/success_checkmark.json',
      width: 120,
      height: 120,
      repeat: false,
    );
  }
  
  // Fallback icon
  return const Icon(
    Icons.check_circle,
    color: AppColors.green,
    size: 80,
  );
}
```

---

## 🔄 Animated Containers

```dart
// Animated selection
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  curve: Curves.easeOutCubic,
  decoration: BoxDecoration(
    color: isSelected ? AppColors.green : AppColors.darkCard,
    borderRadius: BorderRadius.circular(12),
  ),
  transform: isSelected 
    ? Matrix4.identity().scaled(1.05) 
    : Matrix4.identity(),
  child: YourWidget(),
)

// Animated slide
AnimatedSlide(
  offset: isVisible ? Offset.zero : const Offset(0, 1),
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOutCubic,
  child: YourWidget(),
)

// Animated opacity
AnimatedOpacity(
  opacity: isVisible ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 300),
  child: YourWidget(),
)
```

---

## 📱 Swipe Actions

```dart
import 'package:flutter_slidable/flutter_slidable.dart';

Slidable(
  key: ValueKey(item.id),
  endActionPane: ActionPane(
    motion: const ScrollMotion(),
    children: [
      SlidableAction(
        onPressed: (context) {
          HapticUtils.medium();
          // Handle action
        },
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        icon: Icons.delete,
        label: 'Delete',
      ),
      SlidableAction(
        onPressed: (context) {
          // Handle action
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: Icons.edit,
        label: 'Edit',
      ),
    ],
  ),
  child: YourWidget(),
)
```

---

## 📊 Tab Bar

```dart
DefaultTabController(
  length: 3,
  child: Column(
    children: [
      const TabBar(
        tabs: [
          Tab(text: 'Upcoming'),
          Tab(text: 'Past'),
          Tab(text: 'Cancelled'),
        ],
      ),
      Expanded(
        child: TabBarView(
          children: [
            UpcomingTab(),
            PastTab(),
            CancelledTab(),
          ],
        ),
      ),
    ],
  ),
)
```

---

## 💡 Common Patterns

### Loading List with Shimmer
```dart
if (isLoading) {
  return ListView.builder(
    itemCount: 3,
    itemBuilder: (context, index) => const FieldCardSkeleton(),
  );
}

return ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return FadeInUp(
      delay: Duration(milliseconds: 100 * index),
      child: ItemCard(item: items[index]),
    );
  },
);
```

### Empty State
```dart
Widget buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.event_busy,
          size: 80,
          color: AppColors.darkSubText,
        ),
        const SizedBox(height: 16),
        Text(
          'No Items Found',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Try adjusting your filters',
          style: TextStyle(color: AppColors.darkSubText),
        ),
      ],
    ),
  );
}
```

### Pulse Animation
```dart
class PulsingWidget extends StatefulWidget {
  final Widget child;
  
  const PulsingWidget({super.key, required this.child});
  
  @override
  State<PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<PulsingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.03).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOut,
        ),
      ),
      child: widget.child,
    );
  }
}
```

---

## 🎯 Best Practices

1. **Always add haptic feedback** to interactive elements
2. **Use shimmer skeletons** instead of spinners for lists
3. **Animate list items** with staggered delays (100ms * index)
4. **Add scale animation** to buttons (use AnimatedAppButton)
5. **Use SportySnackBar** for all notifications
6. **Provide fallbacks** for Lottie animations
7. **Test on physical device** for haptic feedback
8. **Keep animations under 400ms** for snappy feel
9. **Use easeOutCubic** curve for most animations
10. **Add loading states** to all async operations

---

## 📚 Import Cheat Sheet

```dart
// Theme & Colors
import 'package:football/core/theme/app_theme.dart';

// Widgets
import 'package:football/core/widgets/animated_app_button.dart';
import 'package:football/core/widgets/shimmer_loading.dart';
import 'package:football/core/widgets/sporty_snackbar.dart';
import 'package:football/core/widgets/hero_banner.dart';

// Utils
import 'package:football/core/utils/haptic_utils.dart';

// External packages
import 'package:animate_do/animate_do.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shimmer/shimmer.dart';
```

---

**Need more examples?** Check the implementation guide: `UI_UX_IMPLEMENTATION_GUIDE.md`
