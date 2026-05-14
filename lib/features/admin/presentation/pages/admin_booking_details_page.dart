import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/admin_booking_model.dart';

class AdminBookingDetailsPage extends StatelessWidget {
  final String bookingId;
  final AdminBookingModel? initialBooking;

  const AdminBookingDetailsPage({
    super.key,
    required this.bookingId,
    this.initialBooking,
  });

  @override
  Widget build(BuildContext context) {
    final booking = initialBooking;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        actions: [
          IconButton(
            tooltip: 'Pending Payments',
            onPressed: () => context.push('/admin/payments'),
            icon: const Icon(Icons.payments_outlined),
          ),
        ],
      ),
      body: booking == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'Booking details are not available yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Booking ID: $bookingId',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Direct loading by booking ID needs a dedicated backend endpoint. For now, open this page from Admin Bookings.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : _AdminBookingDetailsContent(booking: booking),
    );
  }
}

class _AdminBookingDetailsContent extends StatelessWidget {
  final AdminBookingModel booking;

  const _AdminBookingDetailsContent({
    required this.booking,
  });

  void _showScreenshotPreview(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                automaticallyImplyLeading: false,
                title: const Text('Screenshot Preview'),
                actions: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Could not load screenshot preview',
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(context, booking.status);
    final paymentStyle = _paymentStyle(context, booking.paymentStatus);
    final theme = Theme.of(context);

    final fieldName = (booking.fieldName?.trim().isNotEmpty ?? false)
        ? booking.fieldName!.trim()
        : 'Unknown field';

    final playerName = (booking.playerName?.trim().isNotEmpty ?? false)
        ? booking.playerName!.trim()
        : ((booking.playerEmail?.trim().isNotEmpty ?? false)
              ? booking.playerEmail!.trim()
              : ((booking.playerPhone?.trim().isNotEmpty ?? false)
                    ? booking.playerPhone!.trim()
                    : 'Unknown player'));

    final hasRefund = (booking.refundAmount ?? 0) > 0;
    final hasFinancialBreakdown =
        booking.totalPrice != null ||
        booking.depositAmount != null ||
        booking.remainingAmount != null ||
        booking.commissionAmount != null ||
        booking.ownerRevenue != null;

    final needsReview = booking.hasManualPaymentReview;
    final hasScreenshot = booking.screenshotUrl?.trim().isNotEmpty == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (needsReview) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.orange.withAlpha(55),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.pending_actions, color: Colors.orange),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'This booking appears to be part of the manual payment flow and may still require admin verification.',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.orange,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/admin/payments'),
                  child: const Text('Open Payments'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withAlpha(128),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fieldName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            playerName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Badge(
                          label: _statusLabel(booking.status),
                          color: statusStyle.$1,
                          backgroundColor: statusStyle.$2,
                        ),
                        if ((booking.paymentStatus ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _Badge(
                            label: _paymentStatusLabel(booking.paymentStatus!),
                            color: paymentStyle.$1,
                            backgroundColor: paymentStyle.$2,
                          ),
                        ],
                        if ((booking.verificationStatus ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _Badge(
                            label: _verificationStatusLabel(
                              booking.verificationStatus!,
                            ),
                            color: _verificationColor(
                              booking.verificationStatus!,
                            ),
                            backgroundColor: _verificationColor(
                              booking.verificationStatus!,
                            ).withAlpha(28),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Section(
                  title: 'Booking Info',
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.receipt_long_outlined,
                        title: 'Booking ID',
                        value: booking.bookingCode?.trim().isNotEmpty == true
                            ? booking.bookingCode!.trim()
                            : booking.id,
                      ),
                      if (booking.referenceCode?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.confirmation_number_outlined,
                          title: 'Reference Code',
                          value: booking.referenceCode!.trim(),
                        ),
                      ],
                      if (booking.paymentGateway?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.payments_outlined,
                          title: 'Gateway',
                          value: booking.paymentGateway!.trim(),
                        ),
                      ],
                      if (booking.ownerName?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.storefront_outlined,
                          title: 'Owner',
                          value: booking.ownerName!.trim(),
                        ),
                      ],
                      if (booking.ownerEmail?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.alternate_email_outlined,
                          title: 'Owner Email',
                          value: booking.ownerEmail!.trim(),
                        ),
                      ],
                      if (booking.playerEmail?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.email_outlined,
                          title: 'Player Email',
                          value: booking.playerEmail!.trim(),
                        ),
                      ],
                      if (booking.playerPhone?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          title: 'Player Phone',
                          value: booking.playerPhone!.trim(),
                        ),
                      ],
                      if (booking.fieldAddress?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          title: 'Field Address',
                          value: booking.fieldAddress!.trim(),
                        ),
                      ],
                      if (booking.scheduledDate != null ||
                          booking.scheduledStart != null ||
                          booking.scheduledEnd != null) ...[
                        const SizedBox(height: 10),
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
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Section(
                  title: 'Manual Payment Flow',
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.payments_outlined,
                        title: 'Flow Summary',
                        value: _manualPaymentSummary(booking),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.rule_outlined,
                        title: 'Expected Admin Action',
                        value: _expectedAdminAction(booking),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.info_outline,
                        title: 'Current Result',
                        value: _currentResultLabel(booking),
                      ),
                      if ((booking.rejectionReason ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.error_outline,
                          title: 'Rejection Reason',
                          value: booking.rejectionReason!.trim(),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasScreenshot) ...[
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Uploaded Screenshot',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            booking.screenshotUrl!.trim(),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                height: 120,
                                width: double.infinity,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withAlpha(18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Could not load screenshot preview',
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showScreenshotPreview(
                            context,
                            booking.screenshotUrl!.trim(),
                          ),
                          icon: const Icon(Icons.open_in_full),
                          label: const Text('Open Screenshot'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (hasFinancialBreakdown) ...[
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Financial Breakdown',
                    child: Column(
                      children: [
                        _FinanceGrid(
                          items: [
                            _FinanceItem(
                              label: 'Total Price',
                              value: _money(booking.totalPrice ?? 0),
                            ),
                            _FinanceItem(
                              label: 'Deposit Required',
                              value: _money(booking.depositAmount ?? 0),
                            ),
                            _FinanceItem(
                              label: 'Cash at Field',
                              value: _money(booking.remainingAmount ?? 0),
                              helper: 'Collected offline',
                            ),
                            _FinanceItem(
                              label: 'App Commission',
                              value: _money(booking.commissionAmount ?? 0),
                            ),
                            _FinanceItem(
                              label: 'Owner Online Share',
                              value: _money(booking.ownerRevenue ?? 0),
                              helper: 'From deposit only',
                            ),
                            _FinanceItem(
                              label: 'Refund Amount',
                              value: _money(booking.refundAmount ?? 0),
                              helper: hasRefund ? null : 'No refund',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _Section(
                  title: 'Status Details',
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.qr_code_2_outlined,
                        title: 'QR Status',
                        value: booking.hasQr
                            ? (booking.qrUsed ? 'Used' : 'Generated')
                            : 'Not available',
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.login_outlined,
                        title: 'Check-in',
                        value: booking.isCheckedIn
                            ? 'Checked in'
                            : 'Not checked in',
                      ),
                      if (booking.checkedInAt != null) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.access_time_outlined,
                          title: 'Checked In At',
                          value: _formatDateTime(booking.checkedInAt!),
                        ),
                      ],
                      if (booking.cancelledAt != null) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.cancel_outlined,
                          title: 'Cancelled At',
                          value: _formatDateTime(booking.cancelledAt!),
                        ),
                      ],
                      if (booking.qrUsedAt != null) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.verified_outlined,
                          title: 'QR Used At',
                          value: _formatDateTime(booking.qrUsedAt!),
                        ),
                      ],
                      if (booking.createdAt != null) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.event_available_outlined,
                          title: 'Created',
                          value: _formatDateTime(booking.createdAt!),
                        ),
                      ],
                      if (booking.updatedAt != null) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.update_outlined,
                          title: 'Updated',
                          value: _formatDateTime(booking.updatedAt!),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (needsReview)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withAlpha(90),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'لو محتاج تعمل approve أو reject، افتح صفحة Pending Payments.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => context.push('/admin/payments'),
                          child: const Text('Go'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(
              90,
            ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _FinanceGrid extends StatelessWidget {
  final List<_FinanceItem> items;

  const _FinanceGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => SizedBox(
              width: 155,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withAlpha(115),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      if (item.helper != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.helper!,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FinanceItem {
  final String label;
  final String value;
  final String? helper;

  const _FinanceItem({
    required this.label,
    required this.value,
    this.helper,
  });
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
    case 'PAYMENT_FAILED':
      return 'Payment Failed';
    default:
      return raw.replaceAll('_', ' ');
  }
}

String _paymentStatusLabel(String raw) {
  switch (raw.toUpperCase()) {
    case 'PENDING':
      return 'Pending Review';
    case 'PARTIAL':
      return 'Partial';
    case 'COMPLETED':
      return 'Completed';
    case 'FAILED':
      return 'Failed';
    case 'REFUNDED':
      return 'Refunded';
    case 'APPROVED':
      return 'Approved';
    case 'REJECTED':
      return 'Rejected';
    case 'EXPIRED':
      return 'Expired';
    case 'LOCKED':
      return 'Under Review';
    default:
      return raw.replaceAll('_', ' ');
  }
}

String _verificationStatusLabel(String raw) {
  switch (raw.toUpperCase()) {
    case 'PENDING':
      return 'Pending Review';
    case 'APPROVED':
      return 'Approved';
    case 'REJECTED':
      return 'Rejected';
    case 'EXPIRED':
      return 'Expired';
    case 'LOCKED':
      return 'Locked';
    default:
      return raw.replaceAll('_', ' ');
  }
}

Color _verificationColor(String raw) {
  switch (raw.toUpperCase()) {
    case 'PENDING':
    case 'LOCKED':
      return Colors.orange;
    case 'APPROVED':
      return Colors.green;
    case 'REJECTED':
    case 'EXPIRED':
      return Colors.red;
    default:
      return Colors.grey;
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
      return (Colors.teal.shade800, Colors.teal.shade100);
    case 'CANCELLED':
      return (Colors.red.shade800, Colors.red.shade100);
    case 'NO_SHOW':
      return (Colors.deepOrange.shade800, Colors.deepOrange.shade100);
    case 'EXPIRED':
      return (Colors.grey.shade700, Colors.grey.shade200);
    case 'PAYMENT_FAILED':
      return (Colors.red.shade900, Colors.red.shade200);
    default:
      return (
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.primaryContainer,
      );
  }
}

(Color, Color) _paymentStyle(BuildContext context, String? status) {
  switch ((status ?? '').toUpperCase()) {
    case 'PENDING':
    case 'LOCKED':
      return (Colors.orange.shade800, Colors.orange.shade100);
    case 'PARTIAL':
      return (Colors.blue.shade800, Colors.blue.shade100);
    case 'COMPLETED':
    case 'APPROVED':
      return (Colors.green.shade800, Colors.green.shade100);
    case 'FAILED':
    case 'REJECTED':
    case 'EXPIRED':
      return (Colors.red.shade800, Colors.red.shade100);
    case 'REFUNDED':
      return (Colors.purple.shade800, Colors.purple.shade100);
    default:
      return (
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.primaryContainer,
      );
  }
}

String _manualPaymentSummary(AdminBookingModel booking) {
  final bookingStatus = booking.status.toUpperCase();
  final paymentStatus = (booking.paymentStatus ?? '').trim().toUpperCase();
  final verificationStatus =
      (booking.verificationStatus ?? '').trim().toUpperCase();

  if (bookingStatus == 'PENDING_PAYMENT') {
    if (verificationStatus == 'LOCKED') {
      return 'Screenshot uploaded and currently under admin review';
    }
    if (verificationStatus == 'PENDING' || paymentStatus == 'PENDING') {
      return 'Manual payment submitted and waiting for admin verification';
    }
    if (verificationStatus.isNotEmpty) {
      return 'Verification status: $verificationStatus';
    }
    if (paymentStatus.isNotEmpty) {
      return 'Manual payment status: $paymentStatus';
    }
    return 'Booking still waiting for manual payment completion';
  }

  if (bookingStatus == 'PAYMENT_FAILED') {
    if (verificationStatus == 'REJECTED') {
      return 'Manual payment was rejected';
    }
    if (verificationStatus == 'EXPIRED') {
      return 'Manual payment expired before approval';
    }
    return 'Payment failed or booking is no longer payable';
  }

  if (bookingStatus == 'CONFIRMED') {
    if (verificationStatus == 'APPROVED' ||
        paymentStatus == 'APPROVED' ||
        paymentStatus == 'COMPLETED') {
      return 'Manual payment approved and booking confirmed';
    }
    return 'Booking confirmed';
  }

  if (verificationStatus.isNotEmpty) {
    return 'Verification status: $verificationStatus';
  }

  if (paymentStatus.isNotEmpty) {
    return 'Payment status: $paymentStatus';
  }

  return 'No manual payment details available';
}

String _expectedAdminAction(AdminBookingModel booking) {
  final bookingStatus = booking.status.toUpperCase();
  final paymentStatus = (booking.paymentStatus ?? '').trim().toUpperCase();
  final verificationStatus =
      (booking.verificationStatus ?? '').trim().toUpperCase();

  if (bookingStatus == 'PENDING_PAYMENT') {
    if (verificationStatus == 'PENDING' ||
        verificationStatus == 'LOCKED' ||
        paymentStatus == 'PENDING') {
      return 'Review the submitted manual payment and approve or reject it';
    }
    return 'Wait for player to complete manual payment submission';
  }

  if (bookingStatus == 'CONFIRMED') {
    return 'No payment action needed';
  }

  if (bookingStatus == 'PAYMENT_FAILED') {
    return 'No further payment action on this booking';
  }

  return 'Review booking according to current operational flow';
}

String _currentResultLabel(AdminBookingModel booking) {
  final bookingStatus = booking.status.toUpperCase();
  final paymentStatus = (booking.paymentStatus ?? '').trim().toUpperCase();
  final verificationStatus =
      (booking.verificationStatus ?? '').trim().toUpperCase();

  if (bookingStatus == 'CONFIRMED') {
    return 'Booking is already confirmed';
  }
  if (bookingStatus == 'PAYMENT_FAILED') {
    return 'Booking is no longer payable';
  }
  if (bookingStatus == 'PENDING_PAYMENT') {
    if (verificationStatus == 'PENDING' || paymentStatus == 'PENDING') {
      return 'Waiting for admin verification';
    }
    if (verificationStatus == 'LOCKED') return 'Currently being reviewed';
    return 'Still awaiting a valid completed payment';
  }
  return 'No final payment result yet';
}

String _money(double value) {
  final text = value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '$text EGP';
}

String _formatSchedule(DateTime? date, DateTime? start, DateTime? end) {
  if (date == null && start == null && end == null) return 'Unknown';

  final effectiveDate = date?.toLocal();
  final effectiveStart = start?.toLocal();
  final effectiveEnd = end?.toLocal();

  final dateText = effectiveDate == null
      ? '--/--/----'
      : _formatDate(effectiveDate);

  final startText =
      effectiveStart == null ? '--:--' : _formatTime(effectiveStart);
  final endText = effectiveEnd == null ? '--:--' : _formatTime(effectiveEnd);

  return '$dateText • $startText - $endText';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yyyy = local.year.toString();
  return '$dd/$mm/$yyyy';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${_formatDate(local)} ${_formatTime(local)}';
}

String _formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}