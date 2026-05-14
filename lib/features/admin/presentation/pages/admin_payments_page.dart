import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/admin_payment_model.dart';
import '../providers/admin_payments_provider.dart';

class AdminPaymentsPage extends ConsumerStatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  ConsumerState<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends ConsumerState<AdminPaymentsPage> {
  static const List<String> _methods = [
    'ALL',
    'VODAFONE_CASH',
    'INSTAPAY',
  ];

  Future<void> _pickDateRange() async {
    final state = ref.read(adminPaymentsProvider);
    final notifier = ref.read(adminPaymentsProvider.notifier);

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDateRange: (state.startDate != null && state.endDate != null)
          ? DateTimeRange(
              start: state.startDate!,
              end: state.endDate!,
            )
          : null,
    );

    if (range == null) return;

    await notifier.setDateRange(
      startDate: range.start,
      endDate: range.end,
    );
  }

  Future<void> _approve(AdminPaymentModel payment) async {
    final notifier = ref.read(adminPaymentsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await notifier.approve(payment.id);

      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Payment approved for booking ${payment.bookingNumber.isNotEmpty ? payment.bookingNumber : payment.bookingId}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _reject(AdminPaymentModel payment) async {
    final controller = TextEditingController();
    final notifier = ref.read(adminPaymentsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter a reason for rejecting payment ${payment.bookingNumber.isNotEmpty ? payment.bookingNumber : payment.bookingId}.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(context, text);
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null || reason.trim().isEmpty) return;

    try {
      await notifier.reject(
        paymentId: payment.id,
        reason: reason,
      );

      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Payment rejected for booking ${payment.bookingNumber.isNotEmpty ? payment.bookingNumber : payment.bookingId}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showScreenshotPreview(String url) {
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
    final state = ref.watch(adminPaymentsProvider);
    final notifier = ref.read(adminPaymentsProvider.notifier);

    final effectiveMethod = state.paymentMethod ?? 'ALL';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Payments'),
        actions: [
          IconButton(
            tooltip: 'Pick date range',
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.isLoading ? null : notifier.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.orange.withAlpha(55),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'These are manual payment submissions awaiting admin verification.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(
                          (state.startDate != null && state.endDate != null)
                              ? '${_formatDate(state.startDate!)} - ${_formatDate(state.endDate!)}'
                              : 'Date range',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (state.startDate != null || state.endDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Clear date range',
                        onPressed: () => notifier.setDateRange(
                          startDate: null,
                          endDate: null,
                        ),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _methods.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final method = _methods[index];
                      final selected = effectiveMethod == method;

                      return ChoiceChip(
                        selected: selected,
                        label: Text(_methodLabel(method)),
                        onSelected: (_) {
                          notifier.setPaymentMethod(
                            method == 'ALL' ? null : method,
                          );
                        },
                      );
                    },
                  ),
                ),
                if (state.hasFilters) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => notifier.clearFilters(),
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Clear Filters'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.isLoading && state.payments.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (state.error != null && state.payments.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 52),
                          const SizedBox(height: 12),
                          const Text(
                            'Failed to load pending payments',
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
                            onPressed: notifier.refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!state.isLoading && state.payments.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: notifier.refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 90),
                        Icon(Icons.payments_outlined, size: 64),
                        SizedBox(height: 16),
                        Text(
                          'No pending payments found',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Everything is reviewed, or filters returned no results.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: state.payments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final payment = state.payments[index];
                      final isSubmitting =
                          state.isSubmitting &&
                          state.activePaymentId == payment.id;

                      return _PaymentCard(
                        payment: payment,
                        isSubmitting: isSubmitting,
                        onApprove: isSubmitting ? null : () => _approve(payment),
                        onReject: isSubmitting ? null : () => _reject(payment),
                        onPreviewScreenshot:
                            payment.screenshotUrl?.trim().isNotEmpty == true
                                ? () => _showScreenshotPreview(
                                      payment.screenshotUrl!.trim(),
                                    )
                                : null,
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

class _PaymentCard extends StatelessWidget {
  final AdminPaymentModel payment;
  final bool isSubmitting;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onPreviewScreenshot;

  const _PaymentCard({
    required this.payment,
    required this.isSubmitting,
    required this.onApprove,
    required this.onReject,
    required this.onPreviewScreenshot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasScreenshot = payment.screenshotUrl?.trim().isNotEmpty == true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(.5),
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
                        payment.fieldName.trim().isEmpty
                            ? 'Unknown field'
                            : payment.fieldName.trim(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        payment.playerName.trim().isEmpty
                            ? 'Unknown player'
                            : payment.playerName.trim(),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _Badge(
                  label: _gatewayLabel(payment.gateway),
                  color: _gatewayColor(payment.gateway),
                  backgroundColor:
                      _gatewayColor(payment.gateway).withAlpha(30),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Payment Info',
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    title: 'Amount',
                    value: _money(payment.amount),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Booking',
                    value: payment.bookingNumber.trim().isNotEmpty
                        ? payment.bookingNumber.trim()
                        : payment.bookingId,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.event_note_outlined,
                    title: 'Submitted At',
                    value: _formatDateTime(payment.createdAt),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Player Info',
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.person_outline,
                    title: 'Name',
                    value: payment.playerName.trim().isNotEmpty
                        ? payment.playerName.trim()
                        : 'Unknown',
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: payment.playerEmail.trim().isNotEmpty
                        ? payment.playerEmail.trim()
                        : '—',
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    value: payment.playerPhone.trim().isNotEmpty
                        ? payment.playerPhone.trim()
                        : '—',
                  ),
                ],
              ),
            ),
            if ((payment.playerNotes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _Section(
                title: 'Player Notes',
                child: Text(
                  payment.playerNotes!.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _Section(
              title: 'Proof of Transfer',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasScreenshot)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            payment.screenshotUrl!.trim(),
                            height: 180,
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
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: onPreviewScreenshot,
                          icon: const Icon(Icons.open_in_full),
                          label: const Text('Open Screenshot'),
                        ),
                      ],
                    )
                  else
                    const Text(
                      'No screenshot attached',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSubmitting ? null : onReject,
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isSubmitting ? null : onApprove,
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(.35),
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

String _gatewayLabel(String raw) {
  switch (raw.toUpperCase()) {
    case 'VODAFONE_CASH':
      return 'Vodafone Cash';
    case 'INSTAPAY':
      return 'InstaPay';
    default:
      return raw.replaceAll('_', ' ');
  }
}

String _methodLabel(String raw) {
  switch (raw.toUpperCase()) {
    case 'ALL':
      return 'All';
    case 'VODAFONE_CASH':
      return 'Vodafone Cash';
    case 'INSTAPAY':
      return 'InstaPay';
    default:
      return raw.replaceAll('_', ' ');
  }
}

Color _gatewayColor(String raw) {
  switch (raw.toUpperCase()) {
    case 'VODAFONE_CASH':
      return Colors.red;
    case 'INSTAPAY':
      return Colors.blue;
    default:
      return Colors.grey;
  }
}

String _money(double value) {
  final text = value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '$text EGP';
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