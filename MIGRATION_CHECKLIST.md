# UI/UX Migration Checklist

Use this checklist to track your progress implementing the new UI/UX components.

## ✅ Setup (Completed)

- [x] Install dependencies (`flutter pub get`)
- [x] Update color system in `app_theme.dart`
- [x] Update typography to Rajdhani
- [x] Update page transitions
- [x] Create new component files
- [x] Create assets/animations folder

---

## 🏠 Home Page (`lib/features/home/presentation/pages/home_page.dart`)

- [ ] Import `HeroBanner` widget
- [ ] Add `HeroBanner` at the top of the page
- [ ] Import `FieldCardSkeleton` from shimmer_loading
- [ ] Replace `CircularProgressIndicator` with `FieldCardSkeleton` list
- [ ] Import `animate_do` package
- [ ] Wrap field cards with `FadeInUp` animation
- [ ] Add staggered delay (100ms * index)
- [ ] Test loading state
- [ ] Test field list animation

**Estimated Time**: 30 minutes

---

## ⏰ Choose Time Page (`lib/features/bookings/presentation/pages/choose_time_page.dart`)

- [ ] Import `HapticUtils`
- [ ] Import `animate_do`
- [ ] Import `AnimatedAppButton`
- [ ] Wrap day selector with `AnimatedContainer`
- [ ] Add scale transform on selection
- [ ] Add haptic feedback to day selection
- [ ] Wrap time slots with `FadeInUp`
- [ ] Add staggered delay (60ms * index)
- [ ] Add haptic feedback to slot selection
- [ ] Replace continue button with `AnimatedAppButton`
- [ ] Wrap button with `AnimatedSlide`
- [ ] Test day selection animation
- [ ] Test time slot animations
- [ ] Test button slide-in

**Estimated Time**: 45 minutes

---

## ✅ Booking Confirmation Page (`lib/features/bookings/presentation/pages/booking_confirmation_page.dart`)

- [ ] Import `lottie` package
- [ ] Import `dart:io`
- [ ] Create `_buildSuccessAnimation()` method
- [ ] Add Lottie animation with fallback
- [ ] Wrap status badge with `AnimatedContainer`
- [ ] Add color animation based on status
- [ ] Create `_CountdownPill` stateful widget
- [ ] Add pulse animation controller
- [ ] Implement pulse when < 5 minutes
- [ ] Wrap payment gateways with `AnimatedOpacity`
- [ ] Add haptic feedback on payment selection
- [ ] Test success animation
- [ ] Test status badge animation
- [ ] Test countdown pulse

**Estimated Time**: 60 minutes

---

## 📋 My Bookings Page (`lib/features/bookings/presentation/pages/my_bookings_page.dart`)

- [ ] Import `flutter_slidable`
- [ ] Import `lottie` and `dart:io`
- [ ] Wrap page with `DefaultTabController`
- [ ] Add `TabBar` with 3 tabs (Upcoming, Past, Cancelled)
- [ ] Add `TabBarView` with 3 views
- [ ] Wrap booking cards with `Slidable`
- [ ] Add cancel action to `endActionPane`
- [ ] Add haptic feedback to swipe actions
- [ ] Create `_buildEmptyState()` method
- [ ] Add Lottie animation or icon for empty state
- [ ] Test tab switching
- [ ] Test swipe-to-cancel
- [ ] Test empty state

**Estimated Time**: 45 minutes

---

## 🔄 Global Replacements

### Replace Loading Indicators

**Files to check**:
- [ ] `lib/features/home/presentation/pages/home_page.dart`
- [ ] `lib/features/fields/presentation/pages/field_details_page.dart`
- [ ] `lib/features/bookings/presentation/pages/choose_time_page.dart`
- [ ] `lib/features/bookings/presentation/pages/my_bookings_page.dart`
- [ ] `lib/features/owner/presentation/pages/owner_fields_page.dart`
- [ ] `lib/features/owner/presentation/pages/owner_bookings_page.dart`
- [ ] `lib/features/wallet/presentation/pages/wallet_page.dart`
- [ ] `lib/features/profile/presentation/pages/profile_page.dart`

**Search for**: `CircularProgressIndicator()`  
**Replace with**: `SportyLoadingIndicator()` or appropriate skeleton

**Estimated Time**: 30 minutes

---

### Replace SnackBars

**Files to check**:
- [ ] `lib/features/auth/presentation/pages/login_page.dart`
- [ ] `lib/features/auth/presentation/pages/register_page.dart`
- [ ] `lib/features/bookings/presentation/pages/choose_time_page.dart`
- [ ] `lib/features/bookings/presentation/pages/booking_confirmation_page.dart`
- [ ] `lib/features/owner/presentation/pages/add_field_page.dart`
- [ ] `lib/features/owner/presentation/pages/owner_time_slots_page.dart`
- [ ] `lib/features/wallet/presentation/pages/wallet_page.dart`
- [ ] Any other files with `ScaffoldMessenger`

**Search for**: `ScaffoldMessenger.of(context).showSnackBar`  
**Replace with**: `showSportySnackBar(context, message: '...', type: SnackBarType.success)`

**Estimated Time**: 45 minutes

---

### Replace Buttons

**Files to check**:
- [ ] `lib/features/home/presentation/pages/home_page.dart`
- [ ] `lib/features/fields/presentation/pages/field_details_page.dart`
- [ ] `lib/features/bookings/presentation/pages/choose_time_page.dart`
- [ ] `lib/features/bookings/presentation/pages/booking_confirmation_page.dart`
- [ ] `lib/features/auth/presentation/pages/login_page.dart`
- [ ] `lib/features/auth/presentation/pages/register_page.dart`

**Search for**: `ElevatedButton(` or custom button widgets  
**Replace with**: `AnimatedAppButton(`

**Note**: Only replace primary action buttons. Keep small icon buttons as-is.

**Estimated Time**: 60 minutes

---

## 📳 Add Haptic Feedback

### Button Presses
- [ ] All `AnimatedAppButton` (automatic)
- [ ] Icon buttons (add `HapticUtils.light()`)
- [ ] Floating action buttons (add `HapticUtils.medium()`)

### Selections
- [ ] Time slot selection (add `HapticUtils.light()`)
- [ ] Day selection (add `HapticUtils.light()`)
- [ ] Field selection (add `HapticUtils.light()`)
- [ ] Tab selection (add `HapticUtils.selection()`)

### Confirmations
- [ ] Booking confirmation (add `HapticUtils.heavy()`)
- [ ] Payment confirmation (add `HapticUtils.heavy()`)
- [ ] Cancellation (add `HapticUtils.medium()`)

### Errors
- [ ] Error dialogs (add `HapticUtils.error()`)
- [ ] Validation errors (add `HapticUtils.error()`)

**Estimated Time**: 30 minutes

---

## 🎬 Optional Enhancements

### Lottie Animations
- [ ] Download `success_checkmark.json` from LottieFiles
- [ ] Download `empty_bookings.json` from LottieFiles
- [ ] Download `loading_football.json` from LottieFiles
- [ ] Save to `assets/animations/`
- [ ] Test animations load correctly

**Estimated Time**: 15 minutes

### Additional Animations
- [ ] Add `FadeIn` to dialogs
- [ ] Add `SlideInRight` to side panels
- [ ] Add `ZoomIn` to modals
- [ ] Add pulse to notification badges

**Estimated Time**: 30 minutes

---

## 🧪 Testing

### Visual Testing
- [ ] Dark theme colors look correct
- [ ] Typography is bold and sporty
- [ ] Buttons have scale animation
- [ ] Page transitions slide from right
- [ ] Loading skeletons match content layout
- [ ] SnackBars are styled correctly
- [ ] Hero banner displays properly
- [ ] Animations are smooth (60fps)

### Functional Testing
- [ ] All buttons still work
- [ ] Navigation still works
- [ ] Loading states display correctly
- [ ] Error states display correctly
- [ ] Empty states display correctly
- [ ] Swipe actions work
- [ ] Tab switching works

### Device Testing
- [ ] Test on Android device
- [ ] Test on iOS device (if available)
- [ ] Haptic feedback works on device
- [ ] Animations are smooth on device
- [ ] No performance issues

**Estimated Time**: 45 minutes

---

## 📊 Progress Tracking

### Overall Progress
- Setup: ✅ 100% (6/6)
- Home Page: ⬜ 0% (0/9)
- Choose Time Page: ⬜ 0% (0/14)
- Booking Confirmation: ⬜ 0% (0/14)
- My Bookings Page: ⬜ 0% (0/13)
- Global Replacements: ⬜ 0% (0/3 sections)
- Haptic Feedback: ⬜ 0% (0/4 sections)
- Optional: ⬜ 0% (0/2 sections)
- Testing: ⬜ 0% (0/3 sections)

### Total Estimated Time
- **Core Features**: ~4 hours
- **Optional Features**: ~45 minutes
- **Testing**: ~45 minutes
- **Total**: ~5.5 hours

---

## 💡 Tips

1. **Work in order** - Complete setup before moving to pages
2. **Test frequently** - Run the app after each major change
3. **Use hot reload** - Flutter's hot reload speeds up development
4. **Check examples** - Refer to QUICK_REFERENCE.md for code snippets
5. **One page at a time** - Don't try to do everything at once
6. **Commit often** - Git commit after each completed section
7. **Test on device** - Haptic feedback only works on physical devices
8. **Ask for help** - Check documentation if stuck

---

## 🎯 Recommended Order

1. ✅ Setup (already done)
2. 🏠 Home Page (most visible)
3. 🔄 Replace Loading Indicators (quick wins)
4. 🔄 Replace SnackBars (quick wins)
5. ⏰ Choose Time Page (critical user flow)
6. ✅ Booking Confirmation (critical user flow)
7. 🔄 Replace Buttons (visual consistency)
8. 📳 Add Haptic Feedback (polish)
9. 📋 My Bookings Page (nice to have)
10. 🎬 Optional Enhancements (if time permits)
11. 🧪 Testing (always last)

---

## 📝 Notes

- Mark items as complete by changing `[ ]` to `[x]`
- Add your own notes or issues below each section
- Update progress percentages as you go
- Celebrate small wins! 🎉

---

**Started**: ___________  
**Completed**: ___________  
**Total Time**: ___________

---

Good luck! 🚀
