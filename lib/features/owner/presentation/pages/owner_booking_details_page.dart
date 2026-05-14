import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/features/bookings/data/models/booking_model.dart';
import 'package:football/features/owner/data/owner_repository.dart';
import 'package:football/features/owner/presentation/providers/owner_providers.dart';
import 'package:go_router/go_router.dart';

class OwnerBookingDetailsPage extends ConsumerStatefulWidget {
  final String bookingId;
  final BookingModel? initialBooking;

  const OwnerBookingDetailsPage({
    super.key,
    required this.bookingId,
    this.initialBooking,
  });

  @override
  ConsumerState<OwnerBookingDetailsPage> createState() =>
      _OwnerBookingDetailsPageState();
}

class _OwnerBookingDetailsPageState
    extends ConsumerState<OwnerBookingDetailsPage> {
  late Future<BookingModel> _future;

  bool _cancelling = false;
  OwnerCancelBookingResult? _lastCancelResult;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<BookingModel> _load() {
    return ref
        .read(ownerRepositoryProvider)
        .getBookingDetails(bookingId: widget.bookingId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _refreshRelatedData() async {
    await ref.read(ownerBookingsProvider.notifier).forceRefresh();
  }

  bool _canCancelBooking(BookingModel booking) {
    final status = booking.status.trim().toUpperCase();

    if (booking.isCheckedIn) return false;

    const blockedStatuses = {
      'CANCELLED',
      'COMPLETED',
      'CHECKED_IN',
      'NO_SHOW',
      'EXPIRED',
    };

    return !blockedStatuses.contains(status);
  }

  Future<void> _cancelBooking(BookingModel booking) async {
    if (_cancelling) return;
    if (!_canCancelBooking(booking)) return;

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to cancel this booking?'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'Write a cancellation reason',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Booking'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel Booking'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    setState(() => _cancelling = true);

    try {
      final result = await ref.read(ownerRepositoryProvider).cancelBooking(
            bookingId: booking.id,
            reason: reasonController.text.trim().isEmpty
                ? null
                : reasonController.text.trim(),
          );

      _lastCancelResult = result;

      if (!mounted) return;

      await _refresh();
      await _refreshRelatedData();

      if (!mounted) return;

      final refund = result.data.refund;
      final refundText = refund.amount > 0
          ? 'Refund: ${_money(refund.amount)} (${refund.percentage}%)'
          : 'No refund applied';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              result.message.trim().isNotEmpty
                  ? '${result.message} • $refundText'
                  : 'Booking cancelled successfully • $refundText',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().replaceFirst('Exception: ', '').trim();

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(msg.isEmpty ? 'Failed to cancel booking' : msg),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      reasonController.dispose();
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<BookingModel>(
        future: _future,
        initialData: widget.initialBooking,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 52),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load booking details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final booking = snapshot.data!;
          final statusStyle = _statusStyle(context, booking.status);
          final paymentStyle = _paymentStyle(context, booking.paymentStatus);

          final canCancel = _canCancelBooking(booking);
          final cancelRefund = _lastCancelResult?.data.refund;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Badge(
                              label: _statusLabel(booking.status),
                              color: statusStyle.$1,
                              backgroundColor: statusStyle.$2,
                            ),
                            if ((booking.paymentStatus ?? '').trim().isNotEmpty)
                              _Badge(
                                label: _paymentStatusLabel(
                                  booking.paymentStatus!,
                                ),
                                color: paymentStyle.$1,
                                backgroundColor: paymentStyle.$2,
                              ),
                            if (booking.isCheckedIn)
                              _Badge(
                                label: 'Checked In',
                                color: Colors.green.shade800,
                                backgroundColor: Colors.green.shade100,
                              ),
                            if (booking.hasQr)
                              _Badge(
                                label: 'QR Ready',
                                color: Colors.indigo.shade800,
                                backgroundColor: Colors.indigo.shade100,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ((booking.fieldNameAr ?? '').trim().isNotEmpty
                              ? booking.fieldNameAr!.trim()
                              : ((booking.fieldName ?? '').trim().isNotEmpty
                                  ? booking.fieldName!.trim()
                                  : 'Unknown field')),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ((booking.playerName ?? '').trim().isNotEmpty
                              ? booking.playerName!.trim()
                              : ((booking.email ?? '').trim().isNotEmpty
                                  ? booking.email!.trim()
                                  : ((booking.phone ?? '').trim().isNotEmpty
                                      ? booking.phone!.trim()
                                      : 'Unknown player'))),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Booking Summary',
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.receipt_long_outlined,
                        title: 'Booking ID',
                        value: booking.id,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.sports_soccer_outlined,
                        title: 'Field ID',
                        value: booking.fieldId,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.person_outline,
                        title: 'Player ID',
                        value: booking.playerId,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.schedule_outlined,
                        title: 'Schedule',
                        value: _formatSchedule(
                          booking.scheduledDate,
                          booking.scheduledStart,
                          booking.scheduledEnd,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Financial Details',
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.payments_outlined,
                        title: 'Total Price',
                        value: _money(booking.totalAsDouble),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Deposit',
                        value: _money(booking.depositAsDouble),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.price_check_outlined,
                        title: 'Remaining',
                        value: _money(booking.remainingAsDouble),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.percent_outlined,
                        title: 'Commission Rate',
                        value: booking.commissionRate,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.request_quote_outlined,
                        title: 'Commission Amount',
                        value: booking.commissionAmount,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.savings_outlined,
                        title: 'Owner Revenue',
                        value: booking.ownerRevenue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Player & Payment',
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.email_outlined,
                        title: 'Email',
                        value: booking.email?.trim().isNotEmpty == true
                            ? booking.email!
                            : '—',
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        title: 'Phone',
                        value: booking.phone?.trim().isNotEmpty == true
                            ? booking.phone!
                            : '—',
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.credit_card_outlined,
                        title: 'Payment Status',
                        value:
                            booking.paymentStatus?.trim().isNotEmpty == true
                                ? _paymentStatusLabel(booking.paymentStatus!)
                                : '—',
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.qr_code_2_outlined,
                        title: 'QR Token',
                        value: booking.qrToken?.trim().isNotEmpty == true
                            ? booking.qrToken!
                            : '—',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Timeline',
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.access_time_outlined,
                        title: 'Created At',
                        value: _formatDateTime(booking.createdAt),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.update_outlined,
                        title: 'Updated At',
                        value: _formatDateTime(booking.updatedAt),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.timer_outlined,
                        title: 'Payment Deadline',
                        value: booking.paymentDeadline != null
                            ? _formatDateTime(booking.paymentDeadline!)
                            : '—',
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.event_busy_outlined,
                        title: 'Cancellation Deadline',
                        value: booking.cancellationDeadline != null
                            ? _formatDateTime(booking.cancellationDeadline!)
                            : '—',
                      ),
                      if (booking.checkedInAt != null) ...[
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.login_outlined,
                          title: 'Checked In At',
                          value: _formatDateTime(booking.checkedInAt!),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_lastCancelResult != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Latest Refund Result',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _InfoRow(
                            icon: Icons.cancel_outlined,
                            title: 'Booking Status',
                            value: _lastCancelResult!.data.booking.status
                                .trim()
                                .toUpperCase(),
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.currency_exchange_outlined,
                            title: 'Refund Amount',
                            value: _money(cancelRefund?.amount ?? 0),
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.percent_outlined,
                            title: 'Refund Percentage',
                            value: '${cancelRefund?.percentage ?? 0}%',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (booking.status.toUpperCase() == 'CONFIRMED')
                  FilledButton.icon(
                    onPressed: () => context.push(
                      '/owner/check-in',
                      extra: {
                        'fieldId': booking.fieldId,
                        'fieldName':
                            ((booking.fieldNameAr ?? '').trim().isNotEmpty
                                ? booking.fieldNameAr!.trim()
                                : ((booking.fieldName ?? '').trim().isNotEmpty
                                    ? booking.fieldName!.trim()
                                    : 'Unknown field')),
                        'bookingId': booking.id,
                        'qrToken': booking.qrToken,
                      },
                    ),
                    icon: const Icon(Icons.qr_code_scanner_outlined),
                    label: const Text('Open Check In'),
                  ),
                if (booking.status.toUpperCase() == 'CONFIRMED')
                  const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: canCancel && !_cancelling
                      ? () => _cancelBooking(booking)
                      : null,
                  icon: _cancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: Text(
                    _cancelling
                        ? 'Cancelling...'
                        : canCancel
                            ? 'Cancel Booking'
                            : 'Booking Cannot Be Cancelled',
                  ),
                ),
                if (_lastCancelResult != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Details'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

String _money(double value) {
  final whole = value.toStringAsFixed(
    value.truncateToDouble() == value ? 0 : 2,
  );
  return '$whole EGP';
}

String _statusLabel(String raw) {
  switch (raw) {
    case 'PENDING_PAYMENT':
      return 'Pending Payment';
    case 'CONFIRMED':
      return 'Confirmed';
    case 'CHECKED_IN':
      return 'Checked In';
    case 'COMPLETED':
      return 'Completed';
    case 'CANCELLED':
      return 'Cancelled';
    case 'NO_SHOW':
      return 'No Show';
    case 'EXPIRED':
      return 'Expired';
    case 'ALL':
      return 'All';
    default:
      return raw.replaceAll('_', ' ');
  }
}

String _paymentStatusLabel(String raw) {
  switch (raw) {
    case 'PENDING':
      return 'Payment Pending';
    case 'COMPLETED':
      return 'Payment Completed';
    case 'FAILED':
      return 'Payment Failed';
    case 'REFUNDED':
      return 'Refunded';
    default:
      return raw.replaceAll('_', ' ');
  }
}

(Color, Color) _statusStyle(BuildContext context, String status) {
  switch (status) {
    case 'PENDING_PAYMENT':
      return (Colors.orange.shade800, Colors.orange.shade100);
    case 'CONFIRMED':
      return (Colors.blue.shade800, Colors.blue.shade100);
    case 'CHECKED_IN':
      return (Colors.green.shade800, Colors.green.shade100);
    case 'COMPLETED':
      return (Colors.grey.shade800, Colors.grey.shade300);
    case 'CANCELLED':
      return (Colors.red.shade800, Colors.red.shade100);
    case 'NO_SHOW':
      return (Colors.deepOrange.shade800, Colors.deepOrange.shade100);
    case 'EXPIRED':
      return (Colors.grey.shade700, Colors.grey.shade200);
    default:
      return (
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.primaryContainer,
      );
  }
}

(Color, Color) _paymentStyle(BuildContext context, String? status) {
  switch (status) {
    case 'PENDING':
      return (Colors.orange.shade800, Colors.orange.shade100);
    case 'COMPLETED':
      return (Colors.green.shade800, Colors.green.shade100);
    case 'FAILED':
      return (Colors.red.shade800, Colors.red.shade100);
    case 'REFUNDED':
      return (Colors.blue.shade800, Colors.blue.shade100);
    default:
      return (
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.primaryContainer,
      );
  }
}

String _formatSchedule(DateTime date, DateTime start, DateTime end) {
  final localDate = date.toLocal();
  final localStart = start.toLocal();
  final localEnd = end.toLocal();

  final dd = localDate.day.toString().padLeft(2, '0');
  final mm = localDate.month.toString().padLeft(2, '0');
  final yyyy = localDate.year.toString();

  return '$dd/$mm/$yyyy • ${_formatTime(localStart)} - ${_formatTime(localEnd)}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yyyy = local.year.toString();
  return '$dd/$mm/$yyyy ${_formatTime(local)}';
}

String _formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}