import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/routing/app_navigation.dart';
import 'package:football/core/utils/error_utils.dart';
import 'package:football/core/widgets/app_button.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/booking_model.dart';
import '../providers/booking_providers.dart';
import '../providers/payment_local_store_provider.dart';
import 'booking_confirmation_page.dart';

class MyBookingsPage extends ConsumerStatefulWidget {
  const MyBookingsPage({super.key});

  @override
  ConsumerState<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends ConsumerState<MyBookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const int _limit = 20;

  static const List<String> _categories = [
    'upcoming',
    'cancelled',
    'played',
    'expired',
  ];

  static const List<String> _labels = [
    'Upcoming',
    'Cancelled',
    'Played',
    'Expired',
  ];

  String? _cancellingBookingId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  MyBookingsQuery _currentQuery() {
    final category = _categories[_tabController.index];

    return MyBookingsQuery(
      category: category,
      status: _mapCategoryToStatus(category),
      page: 1,
      limit: _limit,
    );
  }

  String? _mapCategoryToStatus(String category) {
    switch (category) {
      case 'upcoming':
        return 'CONFIRMED,PENDING_PAYMENT,CHECKED_IN';
      case 'cancelled':
        return 'CANCELLED,CANCELLED_REFUNDED,CANCELLED_NO_REFUND';
      case 'played':
        return 'PLAYED,COMPLETED';
      case 'expired':
        return 'EXPIRED_NO_SHOW,NO_SHOW,PAYMENT_FAILED';
      default:
        return null;
    }
  }

  Future<void> _refresh() async {
    final query = _currentQuery();
    ref.invalidate(myBookingsProvider(query));
    await ref.read(myBookingsProvider(query).future);
  }

  void _invalidateAllBookingTabs() {
    for (final category in _categories) {
      ref.invalidate(
        myBookingsProvider(
          MyBookingsQuery(
            category: category,
            status: _mapCategoryToStatus(category),
            page: 1,
            limit: _limit,
          ),
        ),
      );
    }
  }

  Future<void> _cancelBooking(BookingModel booking) async {
    if (!booking.canCancel || _cancellingBookingId != null) return;

    final result =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Booking?'),
            content: Text(
              booking.willGetRefund
                  ? 'Are you sure you want to cancel ${booking.bookingNumberDisplay}?\n\nA refund will be returned to your wallet.'
                  : 'Are you sure you want to cancel ${booking.bookingNumberDisplay}?\n\nThis booking is no longer eligible for refund.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
        ) ??
        false;

    if (!result || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _cancellingBookingId = booking.id;
    });

    try {
      final cancelResult = await ref.read(
        cancelBookingProvider.notifier,
      ).cancel(
        CancelBookingParams(
          bookingId: booking.id,
          reason: 'Cancelled by player',
        ),
      );

      await ref.read(paymentLocalStoreProvider).clearPaymentId(
            bookingId: booking.id,
          );

      _invalidateAllBookingTabs();
      ref.invalidate(bookingByIdProvider(booking.id));
      ref.invalidate(bookingQrProvider(booking.id));

      if (!mounted) return;

      final refund = cancelResult.refund;
      final message = (cancelResult.messageAr?.trim().isNotEmpty == true)
          ? cancelResult.messageAr!.trim()
          : (cancelResult.messageEn?.trim().isNotEmpty == true)
              ? cancelResult.messageEn!.trim()
              : 'Booking cancelled successfully';

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            refund.amount > 0
                ? '$message • Refund ${_refundPercentage(refund.percentage)}% (${_formatMoney(refund.amount)} EGP)'
                : message,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_extractErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancellingBookingId = null;
        });
      }
    }
  }

  String _extractErrorMessage(Object e) {
    return friendlyErrorMessage(
      e,
      fallback: 'تعذر إلغاء الحجز',
    );
  }

  String _refundPercentage(num value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  bool _shouldShowQr(BookingModel booking) {
    return ref.read(bookingQrEligibilityProvider(booking)).canShowQr;
  }

  bool _shouldShowContinuePayment(BookingModel booking) {
    return booking.statusUpper == 'PENDING_PAYMENT';
  }

  bool _shouldShowPaymentFailedInfo(BookingModel booking) {
    return booking.statusUpper == 'PAYMENT_FAILED';
  }

  String _paymentSummary(BookingModel booking, {required bool hasSavedPayment}) {
    final gateway = (booking.paymentGateway ?? '').trim();
    final paymentStatus = (booking.paymentStatus ?? '').trim();
    final statusUpper = booking.statusUpper;

    if (statusUpper == 'PENDING_PAYMENT') {
      if (hasSavedPayment) {
        if (gateway.isNotEmpty) {
          return paymentStatus.isNotEmpty
              ? 'Payment in progress via $gateway • $paymentStatus'
              : 'Payment in progress via $gateway • waiting for screenshot/review';
        }
        return 'Payment started and saved locally • continue to finish';
      }

      if (gateway.isNotEmpty) {
        return paymentStatus.isNotEmpty
            ? 'Manual payment via $gateway • $paymentStatus'
            : 'Manual payment via $gateway • waiting for screenshot/review';
      }

      return 'Waiting for manual payment submission';
    }

    if (statusUpper == 'PAYMENT_FAILED') {
      return 'Payment failed or was rejected';
    }

    if (statusUpper == 'CONFIRMED') {
      if (gateway.isNotEmpty && paymentStatus.isNotEmpty) {
        return 'Payment confirmed via $gateway • $paymentStatus';
      }
      if (gateway.isNotEmpty) {
        return 'Payment confirmed via $gateway';
      }
      return 'Booking confirmed';
    }

    if (statusUpper == 'CHECKED_IN') {
      if (gateway.isNotEmpty && paymentStatus.isNotEmpty) {
        return 'Checked in • $gateway • $paymentStatus';
      }
      return 'Checked in successfully';
    }

    if (gateway.isNotEmpty) {
      return paymentStatus.isNotEmpty
          ? 'Payment: $gateway • $paymentStatus'
          : 'Payment: $gateway';
    }

    if (paymentStatus.isNotEmpty) {
      return 'Payment status: $paymentStatus';
    }

    return 'Payment status unavailable';
  }

  @override
  Widget build(BuildContext context) {
    final query = _currentQuery();
    final bookingsAsync = ref.watch(myBookingsProvider(query));

    final switchKey = ValueKey(
      'tab_${_tabController.index}_${query.category ?? "unknown"}',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Home',
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Cancelled'),
            Tab(text: 'Played'),
            Tab(text: 'Expired'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: bookingsAsync.when(
            loading: () => _LoadingSkeleton(key: switchKey),
            error: (e, _) => _ErrorState(
              key: switchKey,
              onRetry: _refresh,
              message: _extractErrorMessage(e),
            ),
            data: (result) {
              final bookings = result.bookings;

              if (bookings.isEmpty) {
                return _EmptyState(
                  key: ValueKey('empty_${query.category}'),
                  title: _labels[_tabController.index],
                );
              }

              return ListView.builder(
                key: switchKey,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  final booking = bookings[index];
                  final isCancelling = _cancellingBookingId == booking.id;

                  return FutureBuilder<String?>(
                    future: ref.read(paymentLocalStoreProvider).getPaymentId(
                          bookingId: booking.id,
                        ),
                    builder: (context, snapshot) {
                      final hasSavedPayment =
                          (snapshot.data?.trim().isNotEmpty ?? false);

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 220 + (index * 35)),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) {
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, (1 - t) * 10),
                              child: child,
                            ),
                          );
                        },
                        child: _BookingCard(
                          booking: booking,
                          isCancelling: isCancelling,
                          canShowQr: _shouldShowQr(booking),
                          showContinuePayment:
                              _shouldShowContinuePayment(booking),
                          showPaymentFailedInfo:
                              _shouldShowPaymentFailedInfo(booking),
                          hasSavedPayment: hasSavedPayment,
                          paymentSummary: _paymentSummary(
                            booking,
                            hasSavedPayment: hasSavedPayment,
                          ),
                          onCancel: booking.canCancel && !isCancelling
                              ? () => _cancelBooking(booking)
                              : null,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;
  final bool canShowQr;
  final bool isCancelling;
  final bool showContinuePayment;
  final bool showPaymentFailedInfo;
  final bool hasSavedPayment;
  final String paymentSummary;

  const _BookingCard({
    required this.booking,
    required this.onCancel,
    required this.canShowQr,
    required this.isCancelling,
    required this.showContinuePayment,
    required this.showPaymentFailedInfo,
    required this.hasSavedPayment,
    required this.paymentSummary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fieldName = booking.fieldDisplayName;
    final status = booking.statusUpper;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          context.openBookingConfirmation({
            'bookingId': booking.id,
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      booking.bookingNumberDisplay,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: _StatusBadge(status: status),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                fieldName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if ((booking.fieldAddress ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  booking.fieldAddress!.trim(),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_formatDate(booking.scheduledDate))),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_formatTime(booking.scheduledStart)} - ${_formatTime(booking.scheduledEnd)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_formatMoney(booking.depositAsDouble)} EGP deposit',
                    ),
                  ),
                ],
              ),
              if (booking.remainingAsDouble > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_formatMoney(booking.remainingAsDouble)} EGP remaining at field',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.credit_card, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(paymentSummary),
                  ),
                ],
              ),
              if (status == 'PENDING_PAYMENT') ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(24),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withAlpha(60),
                    ),
                  ),
                  child: Text(
                    hasSavedPayment
                        ? 'فيه عملية دفع محفوظة بالفعل لهذا الحجز. افتح التفاصيل لاستكمال الرفع أو متابعة المراجعة.'
                        : 'هذا الحجز غير مؤكد بعد. افتح التفاصيل لاستكمال الدفع اليدوي ورفع إثبات التحويل.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
              if (showPaymentFailedInfo) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withAlpha(50),
                    ),
                  ),
                  child: const Text(
                    'فشل الدفع أو تم رفضه أو انتهت صلاحيته. ستحتاج إلى إنشاء حجز جديد إذا أردت المحاولة مرة أخرى.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
              if (status == 'CHECKED_IN') ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withAlpha(18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blueGrey.withAlpha(50),
                    ),
                  ),
                  child: const Text(
                    'تم تسجيل الدخول لهذا الحجز بالفعل.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      context.openBookingConfirmation({
                        'bookingId': booking.id,
                      });
                    },
                    icon: Icon(
                      showContinuePayment
                          ? Icons.payments_outlined
                          : Icons.receipt_long,
                      size: 18,
                    ),
                    label: Text(
                      showContinuePayment ? 'Continue Payment' : 'Details',
                    ),
                  ),
                  if (booking.canCancel)
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: isCancelling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel_outlined, size: 18),
                      label: Text(
                        isCancelling
                            ? 'Cancelling...'
                            : booking.willGetRefund
                                ? 'Cancel + Refund'
                                : 'Cancel',
                      ),
                    ),
                  if (canShowQr)
                    FilledButton.tonalIcon(
                      onPressed: () {
                        context.push('/booking/${booking.id}/qr');
                      },
                      icon: const Icon(Icons.qr_code_2, size: 18),
                      label: Text(booking.qrIsUsed ? 'QR Used' : 'Show QR'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'CONFIRMED':
        bg = Colors.green.withAlpha(30);
        fg = Colors.green;
        label = 'Confirmed';
        break;
      case 'PENDING_PAYMENT':
        bg = Colors.orange.withAlpha(38);
        fg = Colors.orange;
        label = 'Pending Payment';
        break;
      case 'CHECKED_IN':
        bg = Colors.blueGrey.withAlpha(38);
        fg = Colors.blueGrey.shade900;
        label = 'Checked In';
        break;
      case 'COMPLETED':
        bg = Colors.blue.withAlpha(30);
        fg = Colors.blue;
        label = 'Completed';
        break;
      case 'PLAYED':
        bg = Colors.blue.withAlpha(30);
        fg = Colors.blue;
        label = 'Played';
        break;
      case 'CANCELLED_REFUNDED':
        bg = Colors.red.withAlpha(30);
        fg = Colors.red;
        label = 'Cancelled + Refunded';
        break;
      case 'CANCELLED_NO_REFUND':
        bg = Colors.red.withAlpha(30);
        fg = Colors.red;
        label = 'Cancelled';
        break;
      case 'CANCELLED':
        bg = Colors.red.withAlpha(30);
        fg = Colors.red;
        label = 'Cancelled';
        break;
      case 'EXPIRED_NO_SHOW':
        bg = Colors.grey.withAlpha(38);
        fg = Colors.grey.shade800;
        label = 'Expired';
        break;
      case 'NO_SHOW':
        bg = Colors.grey.withAlpha(38);
        fg = Colors.grey.shade800;
        label = 'No Show';
        break;
      case 'PAYMENT_FAILED':
        bg = Colors.deepOrange.withAlpha(35);
        fg = Colors.deepOrange;
        label = 'Payment Failed';
        break;
      default:
        bg = Colors.grey.withAlpha(38);
        fg = Colors.grey.shade800;
        label = status.replaceAll('_', ' ');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;

  const _EmptyState({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey('empty_state_$title'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 140),
        const Icon(Icons.event_busy, size: 60, color: Colors.grey),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'No $title bookings found',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;
  final String message;

  const _ErrorState({
    super.key,
    required this.onRetry,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('error_state'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 110),
        const Icon(Icons.error_outline, size: 60, color: Colors.red),
        const SizedBox(height: 12),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: AppButton(
            text: 'Retry',
            width: 140,
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget box({double h = 14, double w = double.infinity, double r = 10}) {
      return Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: theme.dividerColor.withAlpha(40),
          borderRadius: BorderRadius.circular(r),
        ),
      );
    }

    Widget card() {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: box(h: 16, w: 160)),
                const SizedBox(width: 10),
                box(h: 24, w: 110, r: 999),
              ],
            ),
            const SizedBox(height: 14),
            box(h: 14, w: 220),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: box(h: 14, w: 140))]),
            const SizedBox(height: 8),
            Row(children: [Expanded(child: box(h: 14, w: 180))]),
            const SizedBox(height: 8),
            Row(children: [Expanded(child: box(h: 14, w: 130))]),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                box(h: 36, w: 100, r: 999),
                box(h: 36, w: 120, r: 999),
                box(h: 36, w: 110, r: 999),
              ],
            ),
          ],
        ),
      );
    }

    return ListView(
      key: const ValueKey('loading_state'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [card(), card(), card()],
    );
  }
}

String _formatDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year.toString();
  return '$dd/$mm/$yyyy';
}

String _formatTime(DateTime d) {
  int h = d.hour;
  final m = d.minute.toString().padLeft(2, '0');
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