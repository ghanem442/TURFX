import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/features/bookings/data/models/booking_model.dart';
import 'package:football/features/owner/presentation/providers/owner_providers.dart';
import 'package:go_router/go_router.dart';

class OwnerBookingsPage extends ConsumerStatefulWidget {
  final String? fieldId;
  final String? fieldName;

  const OwnerBookingsPage({
    super.key,
    this.fieldId,
    this.fieldName,
  });

  @override
  ConsumerState<OwnerBookingsPage> createState() => _OwnerBookingsPageState();
}

class _OwnerBookingsPageState extends ConsumerState<OwnerBookingsPage> {
  final ScrollController _scrollController = ScrollController();

  static const List<String> _statuses = [
    'ALL',
    'PENDING_PAYMENT',
    'CONFIRMED',
    'CHECKED_IN',
    'COMPLETED',
    'CANCELLED',
    'NO_SHOW',
    'EXPIRED',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ownerBookingsProvider.notifier).initialize(
            fieldId: widget.fieldId,
          );
    });
  }

  @override
  void didUpdateWidget(covariant OwnerBookingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.fieldId != widget.fieldId ||
        oldWidget.fieldName != widget.fieldName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(ownerBookingsProvider.notifier).initialize(
              fieldId: widget.fieldId,
            );
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      ref.read(ownerBookingsProvider.notifier).loadMore();
    }
  }

  Future<void> _cancelBooking(BookingModel booking) async {
    final repo = ref.read(ownerRepositoryProvider);
    final notifier = ref.read(ownerBookingsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final reasonController = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cancel Booking'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to cancel booking ${booking.id}?',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Optional reason',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Enter cancellation reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm Cancel'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed) return;

      final result = await repo.cancelBooking(
        bookingId: booking.id,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );

      if (!mounted) return;

      final refund = result.data.refund;
      final hasRefund = refund.amount > 0 || refund.percentage > 0;
      final refundAmountText = refund.amount.toStringAsFixed(
        refund.amount.truncateToDouble() == refund.amount ? 0 : 2,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            hasRefund
                ? '${result.message}\nRefund: $refundAmountText EGP (${refund.percentage}%)'
                : result.message,
          ),
        ),
      );

      await notifier.refresh();
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _markNoShow(BookingModel booking) async {
    final repo = ref.read(ownerRepositoryProvider);
    final notifier = ref.read(ownerBookingsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Mark as No-Show'),
            content: const Text(
              'Are you sure you want to mark this booking as no-show?\n\nThis means the player did not show up.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm No-Show'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final result = await repo.markBookingNoShow(
        bookingId: booking.id,
      );

      if (!mounted) return;

      final player = result.data.player;
      final suspendedText =
          player.isSuspended && player.suspendedUntil != null
              ? '\nPlayer suspended until ${_formatDateTime(player.suspendedUntil!)}'
              : '';

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${result.message}\nNo-show count: ${player.noShowCount}$suspendedText',
          ),
        ),
      );

      await notifier.refresh();
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ownerBookingsProvider);
    final notifier = ref.read(ownerBookingsProvider.notifier);

    final isFieldScope =
        widget.fieldId != null && widget.fieldId!.trim().isNotEmpty;

    final title = isFieldScope
        ? ((widget.fieldName?.trim().isNotEmpty ?? false)
            ? widget.fieldName!.trim()
            : 'Field Bookings')
        : 'Owner Bookings';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'QR Check-in',
            onPressed: () => context.push(
              '/owner/check-in',
              extra: {
                'fieldId': widget.fieldId,
                'fieldName': widget.fieldName,
              },
            ),
            icon: const Icon(Icons.qr_code_scanner_outlined),
          ),
          if (isFieldScope)
            IconButton(
              tooltip: 'Open all bookings',
              onPressed: () => context.go('/owner/bookings'),
              icon: const Icon(Icons.calendar_view_month_outlined),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => notifier.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _HeaderSection(
            fieldName: widget.fieldName,
            selectedStatus: state.selectedStatus,
            statuses: _statuses,
            bookingsCount: state.bookings.length,
            totalCount: state.pagination?.total ?? state.bookings.length,
            onStatusSelected: (value) {
              notifier.setStatusFilter(value == 'ALL' ? null : value);
            },
            onClearFilters: (state.selectedStatus != null ||
                    state.startDate != null ||
                    state.endDate != null)
                ? () => notifier.clearFilters()
                : null,
            onOpenCheckIn: () => context.push(
              '/owner/check-in',
              extra: {
                'fieldId': widget.fieldId,
                'fieldName': widget.fieldName,
              },
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.isLoading && !state.hasBookings) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.error != null && !state.hasBookings) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 52),
                          const SizedBox(height: 12),
                          const Text(
                            'Failed to load bookings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.error!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => notifier.refresh(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!state.isLoading && state.bookings.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: notifier.refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 80),
                        const Icon(Icons.calendar_month_outlined, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          isFieldScope
                              ? 'No bookings found for this field'
                              : 'No owner bookings found',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isFieldScope
                              ? 'Once players start booking this field, they will appear here.'
                              : 'When players make bookings for your fields, they will appear here.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: FilledButton.icon(
                            onPressed: () => context.push(
                              '/owner/check-in',
                              extra: {
                                'fieldId': widget.fieldId,
                                'fieldName': widget.fieldName,
                              },
                            ),
                            icon: const Icon(Icons.qr_code_scanner_outlined),
                            label: const Text('Open QR Check-in'),
                          ),
                        ),
                        if (state.selectedStatus != null ||
                            state.startDate != null ||
                            state.endDate != null) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: () => notifier.clearFilters(),
                              icon:
                                  const Icon(Icons.filter_alt_off_outlined),
                              label: const Text('Clear Filters'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount:
                        state.bookings.length + (state.isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index >= state.bookings.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final booking = state.bookings[index];
                      return _BookingCard(
                        booking: booking,
                        onViewDetails: () => context.push(
                          '/owner/bookings/${booking.id}',
                        ),
                        onOpenCheckIn: () => context.push(
                          '/owner/check-in',
                          extra: {
                            'fieldId': widget.fieldId ?? booking.fieldId,
                            'fieldName': widget.fieldName ??
                                ((booking.fieldNameAr ?? '').trim().isNotEmpty
                                    ? booking.fieldNameAr!.trim()
                                    : ((booking.fieldName ?? '').trim().isNotEmpty
                                        ? booking.fieldName!.trim()
                                        : 'Unknown field')),
                            'bookingId': booking.id,
                            'qrToken': booking.qrToken,
                          },
                        ),
                        onCancelBooking: () => _cancelBooking(booking),
                        onMarkNoShow: () => _markNoShow(booking),
                      );
                    },
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

class _HeaderSection extends StatelessWidget {
  final String? fieldName;
  final String? selectedStatus;
  final List<String> statuses;
  final int bookingsCount;
  final int totalCount;
  final VoidCallback? onClearFilters;
  final ValueChanged<String> onStatusSelected;
  final VoidCallback onOpenCheckIn;

  const _HeaderSection({
    required this.fieldName,
    required this.selectedStatus,
    required this.statuses,
    required this.bookingsCount,
    required this.totalCount,
    required this.onStatusSelected,
    required this.onClearFilters,
    required this.onOpenCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = selectedStatus ?? 'ALL';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fieldName != null && fieldName!.trim().isNotEmpty) ...[
              Text(
                fieldName!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              '$bookingsCount / $totalCount bookings',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: onOpenCheckIn,
                icon: const Icon(Icons.qr_code_scanner_outlined),
                label: const Text('QR Check-in'),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statuses.map((status) {
                  final isSelected = effectiveStatus == status;
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(_statusLabel(status)),
                      onSelected: (_) => onStatusSelected(status),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (onClearFilters != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Clear Filters'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onViewDetails;
  final VoidCallback onOpenCheckIn;
  final VoidCallback onCancelBooking;
  final VoidCallback onMarkNoShow;

  const _BookingCard({
    required this.booking,
    required this.onViewDetails,
    required this.onOpenCheckIn,
    required this.onCancelBooking,
    required this.onMarkNoShow,
  });

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(context, booking.status);
    final paymentStyle = _paymentStyle(context, booking.paymentStatus);
    final scheduleText = _formatSchedule(
      booking.scheduledDate,
      booking.scheduledStart,
      booking.scheduledEnd,
    );

    final normalizedStatus = booking.status.toUpperCase();
    final canCheckIn = normalizedStatus == 'CONFIRMED';
    final canCancel =
        normalizedStatus == 'CONFIRMED' ||
        normalizedStatus == 'PENDING_PAYMENT';
    final canMarkNoShow = normalizedStatus == 'CONFIRMED';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onViewDetails,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Badge(
                    label: _statusLabel(booking.status),
                    color: statusStyle.$1,
                    backgroundColor: statusStyle.$2,
                  ),
                  if ((booking.paymentStatus ?? '').trim().isNotEmpty)
                    _Badge(
                      label: _paymentStatusLabel(booking.paymentStatus!),
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
              const SizedBox(height: 12),
              Text(
                ((booking.fieldNameAr ?? '').trim().isNotEmpty
                    ? booking.fieldNameAr!.trim()
                    : ((booking.fieldName ?? '').trim().isNotEmpty
                        ? booking.fieldName!.trim()
                        : 'Unknown field')),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (((booking.email ?? '').trim().isNotEmpty ||
                  (booking.phone ?? '').trim().isNotEmpty)) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (booking.email?.trim().isNotEmpty == true)
                      _MetaChip(
                        icon: Icons.email_outlined,
                        label: booking.email!,
                      ),
                    if (booking.phone?.trim().isNotEmpty == true)
                      _MetaChip(
                        icon: Icons.phone_outlined,
                        label: booking.phone!,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.schedule_outlined,
                title: 'Schedule',
                value: scheduleText,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.payments_outlined,
                title: 'Financials',
                value:
                    'Total ${_money(booking.totalAsDouble)} • Deposit ${_money(booking.depositAsDouble)} • Remaining ${_money(booking.remainingAsDouble)}',
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.receipt_long_outlined,
                title: 'Booking ID',
                value: booking.id,
              ),
              if (booking.qrToken?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.qr_code_2_outlined,
                  title: 'QR Token',
                  value: booking.qrToken!,
                ),
              ],
              if (booking.checkedInAt != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.login_outlined,
                  title: 'Checked In At',
                  value: _formatDateTime(booking.checkedInAt!),
                ),
              ],
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.access_time_outlined,
                title: 'Created',
                value: _formatDateTime(booking.createdAt),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Details'),
                  ),
                  if (canCancel)
                    FilledButton.tonalIcon(
                      onPressed: onCancelBooking,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel'),
                    ),
                  if (canMarkNoShow)
                    FilledButton.tonalIcon(
                      onPressed: onMarkNoShow,
                      icon: const Icon(Icons.person_off_outlined),
                      label: const Text('No Show'),
                    ),
                  if (canCheckIn)
                    FilledButton.icon(
                      onPressed: onOpenCheckIn,
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                      label: const Text('Check In'),
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
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