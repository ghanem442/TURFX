# Football Booking App — UI/UX Implementation Guide

## ✅ Completed (P0 & P1)

### 1. Design System ✅
- **Colors**: Updated to bold & sporty Nike/ESPN style
  - Primary green: `#00C853` (brighter, more energetic)
  - Dark green: `#007C30` (for gradients)
  - Accent orange: `#FF6D00` (stronger CTA)
  - Dark theme: Near-black (`#0D0D0D`, `#1A1A1A`, `#242424`)
  
- **Typography**: Changed to Rajdhani (bold sporty font with Arabic support)
  - Increased letter spacing for sporty feel
  - Bold weights throughout (w600-w800)

### 2. Dependencies Added ✅
```yaml
shimmer: ^3.0.0          # Loading skeletons
animate_do: ^3.3.4       # Fade/slide animations
lottie: ^3.1.2           # Success animations
flutter_slidable: ^3.1.1 # Swipe actions
```

### 3. New Components Created ✅

#### `AnimatedAppButton` 
- Scale animation on press (1.0 → 0.95 → 1.0)
- Haptic feedback integration
- Loading state support
- Icon support
- Outlined variant

#### `ShimmerLoading`
- `FieldCardSkeleton` - for field lists
- `TimeSlotSkeleton` - for time slot grids
- `BookingCardSkeleton` - for booking lists
- `SportyLoadingIndicator` - circular progress with brand colors

#### `SportySnackBar`
- Styled with dark background
- Icon + message layout
- Types: success, error, info, warning
- Bold typography

#### `HeroBanner`
- Gradient background (dark green → bright green)
- Football field pattern overlay
- Bold headline + subtitle
- Shadow effect

### 4. Page Transitions ✅
- Changed from subtle fade to **bold slide-in from right**
- Duration: 280ms with easeOutCubic curve
- Nike/ESPN style navigation feel

---

## 🔨 Next Steps (P2 & P3)

### Home Page Updates

**File**: `lib/features/home/presentation/pages/home_page.dart`

```dart
import 'package:animate_do/animate_do.dart';
import '../../../../core/widgets/hero_banner.dart';
import '../../../../core/widgets/shimmer_loading.dart';

// Add hero banner at top:
HeroBanner(
  title: 'Book Your Field',
  subtitle: 'Find and reserve the perfect football field',
),

// Replace CircularProgressIndicator with:
ListView.builder(
  itemBuilder: (context, index) {
    return const FieldCardSkeleton();
  },
)

// Wrap field cards with animation:
FadeInUp(
  duration: const Duration(milliseconds: 400),
  delay: Duration(milliseconds: 100 * index),
  child: FieldCard(...),
)
```

---

### Choose Time Page Updates

**File**: `lib/features/bookings/presentation/pages/choose_time_page.dart`

```dart
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';

// Day selector - animate selection:
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
  // ... rest of day card
)

// Time slot grid - animate on load:
FadeInUp(
  delay: Duration(milliseconds: 60 * index),
  child: TimeSlotCard(...),
)

// On slot selection - add haptic:
onTap: () {
  HapticFeedback.lightImpact();
  // ... selection logic
}

// Continue button - sticky with slide animation:
AnimatedSlide(
  offset: selectedTimeSlotId != null 
    ? Offset.zero 
    : const Offset(0, 1),
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOutCubic,
  child: AnimatedAppButton(
    text: 'Continue',
    onPressed: () { ... },
  ),
)
```

---

### Booking Confirmation Page Updates

**File**: `lib/features/bookings/presentation/pages/booking_confirmation_page.dart`

```dart
import 'package:lottie/lottie.dart';
import 'dart:io';

// Success animation (when status == CONFIRMED):
Widget _buildSuccessAnimation() {
  final animationFile = File('assets/animations/success_checkmark.json');
  
  if (animationFile.existsSync()) {
    return Lottie.asset(
      'assets/animations/success_checkmark.json',
      width: 120,
      height: 120,
      repeat: false,
    );
  }
  
  // Fallback
  return const Icon(
    Icons.check_circle,
    color: AppColors.green,
    size: 80,
  );
}

// Status badge - animate color:
AnimatedContainer(
  duration: const Duration(milliseconds: 500),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  decoration: BoxDecoration(
    color: _getStatusColor(status),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(status),
)

// Countdown timer - pulse when < 5 minutes:
class _CountdownPill extends StatefulWidget {
  final Duration remaining;
  // ...
}

class _CountdownPillState extends State<_CountdownPill> 
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    
    if (widget.remaining.inMinutes < 5) {
      _pulseController.repeat(reverse: true);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.03).animate(
        CurvedAnimation(
          parent: _pulseController,
          curve: Curves.easeInOut,
        ),
      ),
      child: Container(
        // ... countdown UI with red color if < 5 min
      ),
    );
  }
}

// Payment gateway cards - slide in:
AnimatedOpacity(
  opacity: canPay ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 300),
  child: Column(
    children: paymentGateways.map((gateway) => ...).toList(),
  ),
)
```

---

### My Bookings Page Updates

**File**: `lib/features/bookings/presentation/pages/my_bookings_page.dart`

```dart
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lottie/lottie.dart';
import 'dart:io';

// Add tab bar:
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
            _buildUpcomingBookings(),
            _buildPastBookings(),
            _buildCancelledBookings(),
          ],
        ),
      ),
    ],
  ),
)

// Booking card with swipe-to-cancel:
Slidable(
  key: ValueKey(booking.id),
  endActionPane: ActionPane(
    motion: const ScrollMotion(),
    children: [
      SlidableAction(
        onPressed: (context) {
          HapticFeedback.mediumImpact();
          _cancelBooking(booking.id);
        },
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        icon: Icons.cancel,
        label: 'Cancel',
      ),
    ],
  ),
  child: BookingCard(booking: booking),
)

// Empty state:
Widget _buildEmptyState() {
  final animationFile = File('assets/animations/empty_bookings.json');
  
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (animationFile.existsSync())
          Lottie.asset(
            'assets/animations/empty_bookings.json',
            width: 200,
            height: 200,
          )
        else
          const Icon(
            Icons.event_busy,
            size: 80,
            color: AppColors.darkSubText,
          ),
        const SizedBox(height: 16),
        const Text(
          'No Bookings Yet',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Book your first field to get started',
          style: TextStyle(color: AppColors.darkSubText),
        ),
      ],
    ),
  );
}
```

---

### Global Haptic Feedback

Add to all important interactions:

```dart
import 'package:flutter/services.dart';

// Light tap (selections, toggles):
HapticFeedback.lightImpact();

// Medium tap (button presses):
HapticFeedback.mediumImpact();

// Heavy tap (confirmations):
HapticFeedback.heavyImpact();

// Error/warning:
HapticFeedback.vibrate();
```

---

### Replace All Loading Indicators

Find and replace all instances of:

```dart
// OLD:
CircularProgressIndicator()

// NEW:
SportyLoadingIndicator()

// OR for inline loading:
const CircularProgressIndicator(
  color: AppColors.green,
  strokeWidth: 2.5,
)
```

---

### Update All SnackBars

Find and replace:

```dart
// OLD:
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Message')),
)

// NEW:
showSportySnackBar(
  context,
  message: 'Message',
  type: SnackBarType.success, // or error, info, warning
)
```

---

## 📦 Installation Steps

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Download Lottie animations** (optional):
   - Visit https://lottiefiles.com
   - Download `success_checkmark.json` and save to `assets/animations/`
   - See `assets/animations/README.md` for details

3. **Run the app**:
   ```bash
   flutter run
   ```

---

## 🎨 Usage Examples

### Using AnimatedAppButton

```dart
import 'package:football/core/widgets/animated_app_button.dart';

AnimatedAppButton(
  text: 'Book Now',
  icon: Icons.calendar_today,
  onPressed: () {
    // Handle press
  },
  isLoading: isProcessing,
  backgroundColor: AppColors.green,
)

// Outlined variant:
AnimatedAppButton(
  text: 'Cancel',
  isOutlined: true,
  onPressed: () { ... },
)
```

### Using Shimmer Loading

```dart
import 'package:football/core/widgets/shimmer_loading.dart';

// In loading state:
if (isLoading) {
  return ListView.builder(
    itemCount: 3,
    itemBuilder: (context, index) => const FieldCardSkeleton(),
  );
}
```

### Using Hero Banner

```dart
import 'package:football/core/widgets/hero_banner.dart';

HeroBanner(
  title: 'Welcome Back!',
  subtitle: 'Ready to play?',
  height: 180,
)
```

---

## 🎯 Priority Checklist

- [x] P0: Dark theme + color system
- [x] P0: Typography upgrade (Rajdhani)
- [x] P1: Page transition animation
- [x] P1: Shimmer loading states
- [x] P1: Haptic feedback utilities
- [ ] P2: Home page hero banner integration
- [ ] P2: Field cards animation (FadeInUp)
- [ ] P2: Time slot selection animations
- [ ] P2: Lottie success animation
- [ ] P2: Styled SnackBars replacement
- [ ] P3: My Bookings tab bar
- [ ] P3: Swipe-to-cancel in bookings
- [ ] P3: Countdown pulse effect
- [ ] P3: Empty state animations

---

## 📝 Notes

- All new components are in `lib/core/widgets/`
- Theme updates are in `lib/core/theme/app_theme.dart`
- Page transitions are in `lib/core/routing/page_transitions.dart`
- Lottie animations are optional - app uses fallback UI if not present
- Haptic feedback requires physical device (won't work in simulator)

---

## 🚀 Next Actions

1. Integrate `HeroBanner` into home page
2. Replace loading indicators with shimmer skeletons
3. Add `FadeInUp` animations to list items
4. Implement tab bar in My Bookings
5. Add swipe-to-cancel functionality
6. Download and integrate Lottie animations
7. Test on physical device for haptic feedback

---

**Questions or issues?** Check the component files for inline documentation and examples.
