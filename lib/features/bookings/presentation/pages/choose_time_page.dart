import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/theme/app_theme.dart';
import 'package:football/core/utils/error_utils.dart';
import 'package:football/core/widgets/app_button.dart';
import 'package:football/features/fields/data/models/field_model.dart';
import 'package:football/core/routing/app_navigation.dart';
import 'package:go_router/go_router.dart';

import '../providers/booking_providers.dart';
import '../../data/models/time_slot_model.dart';
import '../../../fields/presentation/providers/fields_providers.dart';

class ChooseTimePage extends ConsumerStatefulWidget {
  final String fieldId;
  final FieldModel? field;

  const ChooseTimePage({super.key, required this.fieldId, this.field});

  @override
  ConsumerState<ChooseTimePage> createState() => _ChooseTimePageState();
}

class _ChooseTimePageState extends ConsumerState<ChooseTimePage> {
  late final List<DateTime> _days = List.generate(7, (i) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: i));
  });

  int _selectedDayIndex = 0;
  String? _selectedTimeSlotId;
  bool _creating = false;

  Future<void> _refresh(TimeSlotsQuery query) async {
    setState(() {
      _selectedTimeSlotId = null;
    });
    ref.invalidate(timeSlotsProvider(query));
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fieldAsync = ref.watch(fieldByIdProvider(widget.fieldId));
    final field = widget.field ?? fieldAsync.value;

    if (field == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose Time')),
        body: fieldAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const Center(child: Text('Failed to load field')),
      );
    }

    final title = (field.nameAr?.trim().isNotEmpty == true)
        ? field.nameAr!.trim()
        : field.name;

    final selectedDay = _days[_selectedDayIndex];

    final startOfDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      0,
      0,
      0,
    );

    final endOfDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
      23,
      59,
      59,
    );

    final query = TimeSlotsQuery(
      fieldId: field.id,
      startDate: startOfDay,
      endDate: endOfDay,
    );

    final slotsAsync = ref.watch(timeSlotsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Time'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.safePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/home'),
          ),
          IconButton(
            tooltip: 'My Bookings',
            icon: const Icon(Icons.list_alt),
            onPressed: () => context.go('/my-bookings'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _creating ? null : () => _refresh(query),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: theme.dividerColor.withAlpha(160)),
            ),
          ),
          child: AppButton(
            text: 'Continue',
            color: _selectedTimeSlotId != null ? AppColors.green : Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 14),
            onPressed: _selectedTimeSlotId != null
                ? _handleContinuePressed
                : null,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(query),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: AppColors.green.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.sports_soccer,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Select day',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final d = _days[i];
                  final selected = i == _selectedDayIndex;

                  return InkWell(
                    onTap: () {
                      if (_creating) return;
                      setState(() {
                        _selectedDayIndex = i;
                        _selectedTimeSlotId = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.green : theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.green
                              : theme.dividerColor.withAlpha(160),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${_weekdayShort(d.weekday)} ${d.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: selected
                                ? Colors.white
                                : (theme.textTheme.bodyMedium?.color ??
                                    Colors.black),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select time slot',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'بعد اختيار المعاد هيتم إنشاء الحجز، وبعدها هتختار وسيلة الدفع اليدوي وترفع إثبات التحويل.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            slotsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        _friendlyError(e),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        text: 'Retry',
                        width: 120,
                        onPressed: () async => _refresh(query),
                      ),
                    ],
                  ),
                ),
              ),
              data: (slots) {
                final sorted = [...slots]
                  ..sort((a, b) => a.start.compareTo(b.start));

                if (_selectedTimeSlotId != null &&
                    !sorted.any(
                      (s) => s.id == _selectedTimeSlotId && s.isAvailable,
                    )) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _selectedTimeSlotId = null);
                    }
                  });
                }

                if (sorted.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No available time slots')),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sorted.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.65,
                  ),
                  itemBuilder: (context, i) {
                    final TimeSlotModel s = sorted[i];
                    final selected = s.id == _selectedTimeSlotId;

                    final bg = !s.isAvailable
                        ? Colors.grey.withAlpha(60)
                        : selected
                            ? AppColors.green
                            : theme.cardColor;

                    final fg = !s.isAvailable
                        ? Colors.black38
                        : selected
                            ? Colors.white
                            : (theme.textTheme.bodyMedium?.color ??
                                Colors.black);

                    return InkWell(
                      onTap: (!s.isAvailable || _creating)
                          ? null
                          : () => setState(() => _selectedTimeSlotId = s.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.green
                                : theme.dividerColor.withAlpha(160),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_formatTime(s.start)} - ${_formatTime(s.end)}',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: fg,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_formatMoney(s.priceAsDouble)} EGP',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: fg,
                              ),
                            ),
                            if (selected && s.isAvailable) ...[
                              const SizedBox(height: 8),
                              const Icon(
                                Icons.check_circle,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                            if (!s.isAvailable) ...[
                              const SizedBox(height: 8),
                              const Icon(
                                Icons.lock,
                                size: 16,
                                color: Colors.black38,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleContinuePressed() async {
    final slotId = _selectedTimeSlotId;
    if (slotId == null || _creating) return;

    setState(() => _creating = true);

    try {
      final booking = await ref.read(createBookingProvider.notifier).create(slotId);

      if (!mounted) return;

      context.push(
        '/booking-confirmation',
        extra: {
          'bookingId': booking.id,
          'fieldId': widget.fieldId,
        },
      );
    } catch (e, st) {
      debugPrint('================ BOOKING ERROR ================');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $st');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyBookingError(e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  String _weekdayShort(int wd) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(wd - 1).clamp(0, 6)];
  }

  String _formatTime(DateTime d) {
    final x = d.toLocal();
    int h = x.hour;
    final m = x.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$m $ampm';
  }

  String _formatMoney(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _friendlyError(Object e) {
    return friendlyErrorMessage(
      e,
      fallback: 'تعذر تحميل المواعيد المتاحة',
    );
  }

  String _friendlyBookingError(Object e) {
    final text = e.toString().replaceFirst('Exception: ', '').trim();

    if (text.isEmpty) {
      return 'Failed to create booking. Please try again.';
    }

    if (text.toLowerCase().contains('invalid booking response')) {
      return 'تعذر إنشاء الحجز بسبب مشكلة في بيانات الحجز.';
    }

    if (text.toLowerCase().contains('not available')) {
      return 'هذا الموعد غير متاح الآن.';
    }

    return text;
  }
}