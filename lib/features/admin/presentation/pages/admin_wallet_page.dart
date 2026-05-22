import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/admin_wallet_transaction_model.dart';
import '../providers/admin_wallet_provider.dart';

class AdminWalletPage extends ConsumerStatefulWidget {
  const AdminWalletPage({super.key});

  @override
  ConsumerState<AdminWalletPage> createState() => _AdminWalletPageState();
}

class _AdminWalletPageState extends ConsumerState<AdminWalletPage> {
  static const List<String> _types = [
    'ALL',
    'DEPOSIT',
    'WITHDRAWAL',
    'REFUND',
    'BOOKING_PAYMENT',
    'COMMISSION_DEDUCTION',
    'CREDIT',
    'DEBIT',
    'PAYOUT',
  ];

  String? _selectedPurpose;

  Future<void> _pickDateRange() async {
    final state = ref.read(adminWalletProvider);
    final notifier = ref.read(adminWalletProvider.notifier);

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDateRange: (state.startDate != null && state.endDate != null)
          ? DateTimeRange(start: state.startDate!, end: state.endDate!)
          : null,
    );

    if (range == null) return;

    await notifier.setDateRange(
      startDate: range.start,
      endDate: range.end,
    );
  }

  Future<void> _copyCsv(List<AdminWalletTransactionModel> transactions) async {
    final csv = _buildCsv(transactions);
    await Clipboard.setData(ClipboardData(text: csv));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          transactions.isEmpty
              ? 'No transactions to export'
              : 'CSV copied to clipboard',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminWalletProvider);
    final notifier = ref.read(adminWalletProvider.notifier);

    final effectiveType = state.type ?? 'ALL';
    final availablePurposes = _extractPurposes(state.transactions);
    final filteredTransactions = _applyPurposeFilter(
      state.transactions,
      _selectedPurpose,
    );
    final summary = _calculateSummary(filteredTransactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Transactions'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            onPressed:
                state.isLoading ? null : () => _copyCsv(filteredTransactions),
            icon: const Icon(Icons.download_outlined),
          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(
                          (state.startDate != null && state.endDate != null)
                              ? '${_formatDate(state.startDate!)} - ${_formatDate(state.endDate!)}'
                              : 'Date Range',
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
                    itemCount: _types.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final type = _types[index];
                      final selected = effectiveType == type;

                      return ChoiceChip(
                        selected: selected,
                        label: Text(_filterLabel(type)),
                        onSelected: (_) {
                          notifier.setType(type == 'ALL' ? null : type);
                        },
                      );
                    },
                  ),
                ),
                if (availablePurposes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: availablePurposes.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ChoiceChip(
                            selected: _selectedPurpose == null,
                            label: const Text('All Purposes'),
                            onSelected: (_) {
                              setState(() {
                                _selectedPurpose = null;
                              });
                            },
                          );
                        }

                        final purpose = availablePurposes[index - 1];
                        final selected = _selectedPurpose == purpose;

                        return ChoiceChip(
                          selected: selected,
                          label: Text(_purposeLabel(purpose)),
                          onSelected: (_) {
                            setState(() {
                              _selectedPurpose = selected ? null : purpose;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
                if (state.hasFilters || _selectedPurpose != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        setState(() {
                          _selectedPurpose = null;
                        });
                        await notifier.clearFilters();
                      },
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
                if (state.isLoading && state.transactions.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.error != null && state.transactions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 52),
                          const SizedBox(height: 12),
                          const Text(
                            'Failed to load wallet transactions',
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

                if (!state.isLoading && filteredTransactions.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: notifier.refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 90),
                        Icon(Icons.account_balance_wallet_outlined, size: 64),
                        SizedBox(height: 16),
                        Text(
                          'No wallet transactions found',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try changing your filters.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
                    children: [
                      _WalletSummaryCard(summary: summary),
                      const SizedBox(height: 8),
                      ...List.generate(
                        filteredTransactions.length,
                        (index) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _TransactionCard(
                            transaction: filteredTransactions[index],
                          ),
                        ),
                      ),
                    ],
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

class _TransactionCard extends StatelessWidget {
  final AdminWalletTransactionModel transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final visual = _transactionVisual(transaction);
    final isMoneyIn = _isMoneyIn(transaction);

    final displayUser = transaction.userName?.trim().isNotEmpty == true
        ? transaction.userName!.trim()
        : (transaction.userEmail?.trim().isNotEmpty == true
              ? transaction.userEmail!.trim()
              : 'Unknown user');

    final rawType = transaction.type?.trim().isNotEmpty == true
        ? transaction.type!.trim()
        : 'UNKNOWN';

    final actorRole = transaction.metadata?.actorRole;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showTransactionDetails(context, transaction),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: visual.backgroundColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        visual.icon,
                        color: visual.color,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visual.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          visual.subtitle,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _moneyWithSign(transaction.amount, isMoneyIn),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isMoneyIn
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(
                    label: _filterLabel(rawType),
                    color: visual.color,
                    backgroundColor: visual.backgroundColor,
                  ),
                  if (actorRole?.trim().isNotEmpty == true)
                    _Badge(
                      label: _actorRoleLabel(actorRole),
                      color: Colors.indigo.shade800,
                      backgroundColor: Colors.indigo.shade100,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                displayUser,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.receipt_long_outlined,
                title: 'Transaction ID',
                value: transaction.id,
              ),
              if (transaction.reference?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.link_outlined,
                  title: _referenceLabel(transaction),
                  value: transaction.reference!.trim(),
                ),
              ],
              if (transaction.userId?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.person_outline,
                  title: 'User ID',
                  value: transaction.userId!.trim(),
                ),
              ],
              if (transaction.userEmail?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: transaction.userEmail!.trim(),
                ),
              ],
              if (transaction.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.notes_outlined,
                  title: 'Description',
                  value: transaction.description!.trim(),
                ),
              ],
              if (transaction.metadata?.transactionPurpose?.trim().isNotEmpty ==
                  true) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.category_outlined,
                  title: 'Purpose',
                  value: _purposeLabel(
                    transaction.metadata!.transactionPurpose!.trim(),
                  ),
                ),
              ],
              if (transaction.balanceBefore != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Balance Before',
                  value: _money(transaction.balanceBefore!),
                ),
              ],
              if (transaction.balanceAfter != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Balance After',
                  value: _money(transaction.balanceAfter!),
                ),
              ],
              if (transaction.createdAt?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.access_time_outlined,
                  title: 'Created',
                  value: _formatDateTime(transaction.createdAt!),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap for details',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
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

class _TransactionVisual {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _TransactionVisual({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}

class _WalletSummary {
  final double totalIn;
  final double totalOut;

  const _WalletSummary({
    required this.totalIn,
    required this.totalOut,
  });

  double get net => totalIn - totalOut;
}

class _WalletSummaryCard extends StatelessWidget {
  final _WalletSummary summary;

  const _WalletSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryStatChip(
                  title: 'Money In',
                  value: _money(summary.totalIn),
                  icon: Icons.south_west_rounded,
                  color: Colors.green,
                  background: Colors.green.shade50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStatChip(
                  title: 'Money Out',
                  value: _money(summary.totalOut),
                  icon: Icons.north_east_rounded,
                  color: Colors.red,
                  background: Colors.red.shade50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NetSummaryChip(net: summary.net),
        ],
      ),
    );
  }
}

class _SummaryStatChip extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;

  const _SummaryStatChip({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetSummaryChip extends StatelessWidget {
  final double net;

  const _NetSummaryChip({required this.net});

  @override
  Widget build(BuildContext context) {
    final isPositive = net >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final background = isPositive ? Colors.green.shade50 : Colors.red.shade50;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Net Balance',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            '${net >= 0 ? '+' : '-'}${_money(net.abs())}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

void _showTransactionDetails(
  BuildContext context,
  AdminWalletTransactionModel transaction,
) {
  final visual = _transactionVisual(transaction);
  final isMoneyIn = _isMoneyIn(transaction);
  final referenceTitle = _referenceLabel(transaction);
  final purpose = transaction.metadata?.transactionPurpose;
  final actorRole = transaction.metadata?.actorRole;
  final canOpenBooking = _canOpenBooking(transaction);
  final bookingId = transaction.reference?.trim();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: visual.backgroundColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          visual.icon,
                          color: visual.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        visual.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      _moneyWithSign(transaction.amount, isMoneyIn),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isMoneyIn
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  visual.subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(
                      label: _filterLabel(transaction.type ?? 'UNKNOWN'),
                      color: visual.color,
                      backgroundColor: visual.backgroundColor,
                    ),
                    if (actorRole?.trim().isNotEmpty == true)
                      _Badge(
                        label: _actorRoleLabel(actorRole),
                        color: Colors.indigo.shade800,
                        backgroundColor: Colors.indigo.shade100,
                      ),
                    if (purpose?.trim().isNotEmpty == true)
                      _Badge(
                        label: _purposeLabel(purpose),
                        color: Colors.deepPurple.shade800,
                        backgroundColor: Colors.deepPurple.shade100,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _DetailTile(
                  title: 'Transaction ID',
                  value: transaction.id,
                ),
                if (transaction.reference?.trim().isNotEmpty == true)
                  _DetailTile(
                    title: referenceTitle,
                    value: transaction.reference!.trim(),
                  ),
                if (transaction.userName?.trim().isNotEmpty == true)
                  _DetailTile(
                    title: 'User Name',
                    value: transaction.userName!.trim(),
                  ),
                if (transaction.userEmail?.trim().isNotEmpty == true)
                  _DetailTile(
                    title: 'Email',
                    value: transaction.userEmail!.trim(),
                  ),
                if (transaction.userId?.trim().isNotEmpty == true)
                  _DetailTile(
                    title: 'User ID',
                    value: transaction.userId!.trim(),
                  ),
                if (transaction.description?.trim().isNotEmpty == true)
                  _DetailTile(
                    title: 'Description',
                    value: transaction.description!.trim(),
                  ),
                if (transaction.balanceBefore != null)
                  _DetailTile(
                    title: 'Balance Before',
                    value: _money(transaction.balanceBefore!),
                  ),
                if (transaction.balanceAfter != null)
                  _DetailTile(
                    title: 'Balance After',
                    value: _money(transaction.balanceAfter!),
                  ),
                if (transaction.createdAt?.trim().isNotEmpty == true)
                  _DetailTile(
                    title: 'Created',
                    value: _formatDateTime(transaction.createdAt!),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: transaction.id),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transaction ID copied'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy Transaction ID'),
                      ),
                    ),
                  ],
                ),
                if (transaction.reference?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: transaction.reference!.trim()),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reference copied'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy Reference'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (canOpenBooking && bookingId != null && bookingId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.push(
                              '/admin/bookings?search=${Uri.encodeComponent(bookingId)}',
                            );
                          },
                          icon: const Icon(Icons.open_in_new_outlined),
                          label: const Text('Open Booking'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _DetailTile extends StatelessWidget {
  final String title;
  final String value;

  const _DetailTile({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

_TransactionVisual _transactionVisual(AdminWalletTransactionModel tx) {
  final type = (tx.type ?? '').trim().toUpperCase();
  final actorRole = (tx.metadata?.actorRole ?? '').trim().toUpperCase();
  final purpose = (tx.metadata?.transactionPurpose ?? '').trim().toUpperCase();
  final description = (tx.description ?? '').trim().toLowerCase();

  switch (purpose) {
    case 'OWNER_ONLINE_SHARE':
      return _TransactionVisual(
        title: 'Owner Online Share',
        subtitle: 'Owner share from booking deposit',
        icon: Icons.sports_soccer_outlined,
        color: Colors.green.shade800,
        backgroundColor: Colors.green.shade100,
      );

    case 'PLAYER_REFUND':
      return _TransactionVisual(
        title: 'Player Refund',
        subtitle: 'Refund added back to player wallet',
        icon: Icons.replay_circle_filled_outlined,
        color: Colors.orange.shade800,
        backgroundColor: Colors.orange.shade100,
      );

    case 'REFUND_REVERSAL':
      return _TransactionVisual(
        title: 'Refund Reversal',
        subtitle: 'Previously refunded amount reversed',
        icon: Icons.undo_outlined,
        color: Colors.deepOrange.shade800,
        backgroundColor: Colors.deepOrange.shade100,
      );

    case 'OWNER_WITHDRAWAL':
      return _TransactionVisual(
        title: 'Owner Withdrawal',
        subtitle: 'Owner withdrawal request',
        icon: Icons.call_made_outlined,
        color: Colors.red.shade800,
        backgroundColor: Colors.red.shade100,
      );

    case 'OWNER_WITHDRAWAL_REVERSAL':
      return _TransactionVisual(
        title: 'Owner Withdrawal Reversal',
        subtitle: 'Rejected withdrawal restored to balance',
        icon: Icons.restore_outlined,
        color: Colors.blue.shade800,
        backgroundColor: Colors.blue.shade100,
      );
  }

  if (type == 'REFUND') {
    return _TransactionVisual(
      title: 'Player Refund',
      subtitle: 'Refund returned to wallet',
      icon: Icons.replay_circle_filled_outlined,
      color: Colors.orange.shade800,
      backgroundColor: Colors.orange.shade100,
    );
  }

  if (type == 'WITHDRAWAL' && actorRole == 'OWNER') {
    return _TransactionVisual(
      title: 'Owner Withdrawal',
      subtitle: 'Owner withdrawal request',
      icon: Icons.call_made_outlined,
      color: Colors.red.shade800,
      backgroundColor: Colors.red.shade100,
    );
  }

  if (type == 'DEPOSIT' &&
      description.contains('withdrawal') &&
      description.contains('restored')) {
    return _TransactionVisual(
      title: 'Withdrawal Reversal',
      subtitle: 'Balance restored after rejection',
      icon: Icons.restore_outlined,
      color: Colors.blue.shade800,
      backgroundColor: Colors.blue.shade100,
    );
  }

  if (type == 'DEBIT' && description.contains('payment for booking')) {
    return _TransactionVisual(
      title: 'Booking Deposit Payment',
      subtitle: 'Player paid booking deposit',
      icon: Icons.payments_outlined,
      color: Colors.purple.shade800,
      backgroundColor: Colors.purple.shade100,
    );
  }

  if (type == 'BOOKING_PAYMENT') {
    return _TransactionVisual(
      title: 'Booking Payment',
      subtitle: 'Payment related to booking',
      icon: Icons.payments_outlined,
      color: Colors.green.shade800,
      backgroundColor: Colors.green.shade100,
    );
  }

  if (type == 'COMMISSION_DEDUCTION') {
    return _TransactionVisual(
      title: 'Commission Deduction',
      subtitle: 'Platform commission deducted',
      icon: Icons.percent_outlined,
      color: Colors.deepPurple.shade800,
      backgroundColor: Colors.deepPurple.shade100,
    );
  }

  if (type == 'CREDIT') {
    return _TransactionVisual(
      title: 'Wallet Credit',
      subtitle: 'Amount added to wallet',
      icon: Icons.add_circle_outline,
      color: Colors.teal.shade800,
      backgroundColor: Colors.teal.shade100,
    );
  }

  if (type == 'DEBIT') {
    return _TransactionVisual(
      title: 'Wallet Debit',
      subtitle: 'Amount deducted from wallet',
      icon: Icons.remove_circle_outline,
      color: Colors.brown.shade800,
      backgroundColor: Colors.brown.shade100,
    );
  }

  if (type == 'DEPOSIT') {
    return _TransactionVisual(
      title: 'Wallet Deposit',
      subtitle: 'Amount deposited to wallet',
      icon: Icons.arrow_downward_outlined,
      color: Colors.blue.shade800,
      backgroundColor: Colors.blue.shade100,
    );
  }

  if (type == 'PAYOUT') {
    return _TransactionVisual(
      title: 'Payout',
      subtitle: 'Wallet payout transaction',
      icon: Icons.account_balance_outlined,
      color: Colors.indigo.shade800,
      backgroundColor: Colors.indigo.shade100,
    );
  }

  return _TransactionVisual(
    title: 'Wallet Transaction',
    subtitle: 'General wallet activity',
    icon: Icons.account_balance_wallet_outlined,
    color: Colors.grey.shade800,
    backgroundColor: Colors.grey.shade200,
  );
}

_WalletSummary _calculateSummary(List<AdminWalletTransactionModel> list) {
  double totalIn = 0;
  double totalOut = 0;

  for (final tx in list) {
    final isIn = _isMoneyIn(tx);

    if (isIn) {
      totalIn += tx.amount;
    } else {
      totalOut += tx.amount;
    }
  }

  return _WalletSummary(
    totalIn: totalIn,
    totalOut: totalOut,
  );
}

bool _isMoneyIn(AdminWalletTransactionModel tx) {
  final type = (tx.type ?? '').trim().toUpperCase();
  final purpose = (tx.metadata?.transactionPurpose ?? '').trim().toUpperCase();

  if (purpose == 'OWNER_WITHDRAWAL') return false;
  if (purpose == 'OWNER_WITHDRAWAL_REVERSAL') return true;

  if (type == 'DEBIT') return false;
  if (type == 'WITHDRAWAL') return false;

  return true;
}

bool _canOpenBooking(AdminWalletTransactionModel tx) {
  final reference = tx.reference?.trim();
  final purpose = (tx.metadata?.transactionPurpose ?? '').trim().toUpperCase();
  final type = (tx.type ?? '').trim().toUpperCase();

  if (reference == null || reference.isEmpty) return false;

  if (type == 'DEBIT' || type == 'BOOKING_PAYMENT' || type == 'REFUND') {
    return true;
  }

  if (purpose == 'OWNER_ONLINE_SHARE' ||
      purpose == 'PLAYER_REFUND' ||
      purpose == 'REFUND_REVERSAL') {
    return true;
  }

  return false;
}

List<String> _extractPurposes(List<AdminWalletTransactionModel> list) {
  final values = list
      .map((e) => e.metadata?.transactionPurpose?.trim())
      .whereType<String>()
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  return values;
}

List<AdminWalletTransactionModel> _applyPurposeFilter(
  List<AdminWalletTransactionModel> list,
  String? selectedPurpose,
) {
  if (selectedPurpose == null || selectedPurpose.trim().isEmpty) {
    return list;
  }

  return list.where((tx) {
    final purpose = tx.metadata?.transactionPurpose?.trim().toUpperCase();
    return purpose == selectedPurpose.trim().toUpperCase();
  }).toList();
}

String _actorRoleLabel(String? value) {
  switch ((value ?? '').trim().toUpperCase()) {
    case 'OWNER':
      return 'Owner';
    case 'PLAYER':
      return 'Player';
    default:
      return 'Unknown Actor';
  }
}

String _purposeLabel(String? value) {
  switch ((value ?? '').trim().toUpperCase()) {
    case 'OWNER_ONLINE_SHARE':
      return 'Owner Online Share';
    case 'PLAYER_REFUND':
      return 'Player Refund';
    case 'REFUND_REVERSAL':
      return 'Refund Reversal';
    case 'OWNER_WITHDRAWAL':
      return 'Owner Withdrawal';
    case 'OWNER_WITHDRAWAL_REVERSAL':
      return 'Owner Withdrawal Reversal';
    default:
      return value?.trim().isNotEmpty == true ? value!.trim() : 'Unknown';
  }
}

String _referenceLabel(AdminWalletTransactionModel tx) {
  final purpose = (tx.metadata?.transactionPurpose ?? '').trim().toUpperCase();
  final type = (tx.type ?? '').trim().toUpperCase();

  if (purpose.contains('WITHDRAWAL')) return 'Withdrawal Ref';
  if (purpose.contains('REFUND')) return 'Refund Ref';
  if (type == 'DEBIT' || type == 'BOOKING_PAYMENT') return 'Booking ID';

  return 'Reference';
}

String _filterLabel(String value) {
  switch (value.trim().toUpperCase()) {
    case 'ALL':
      return 'All';
    case 'DEPOSIT':
      return 'Deposit';
    case 'WITHDRAWAL':
      return 'Withdrawal';
    case 'REFUND':
      return 'Refund';
    case 'BOOKING_PAYMENT':
      return 'Booking Payment';
    case 'COMMISSION_DEDUCTION':
      return 'Commission';
    case 'CREDIT':
      return 'Credit';
    case 'DEBIT':
      return 'Debit';
    case 'PAYOUT':
      return 'Payout';
    default:
      return value;
  }
}

String _money(double value) {
  final text = value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '$text EGP';
}

String _moneyWithSign(double value, bool isIn) {
  final text = value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '${isIn ? '+' : '-'}$text EGP';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yyyy = local.year.toString();
  return '$dd/$mm/$yyyy';
}

String _formatDateTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;

  final local = parsed.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yyyy = local.year.toString();

  final hour24 = local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

  return '$dd/$mm/$yyyy - $hour12:$minute $period';
}

String _escapeCsv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _buildCsv(List<AdminWalletTransactionModel> list) {
  final buffer = StringBuffer();
  buffer.writeln(
    'Transaction ID,Title,Type,Purpose,Actor Role,Amount,Direction,Reference,Description,User Name,User Email,User ID,Balance Before,Balance After,Created At',
  );

  for (final tx in list) {
    final title = _transactionVisual(tx).title;
    final type = _filterLabel(tx.type ?? 'UNKNOWN');
    final purpose = _purposeLabel(tx.metadata?.transactionPurpose);
    final actorRole = _actorRoleLabel(tx.metadata?.actorRole);
    final direction = _isMoneyIn(tx) ? 'IN' : 'OUT';

    buffer.writeln([
      _escapeCsv(tx.id),
      _escapeCsv(title),
      _escapeCsv(type),
      _escapeCsv(purpose),
      _escapeCsv(actorRole),
      _escapeCsv(tx.amount.toString()),
      _escapeCsv(direction),
      _escapeCsv(tx.reference ?? ''),
      _escapeCsv(tx.description ?? ''),
      _escapeCsv(tx.userName ?? ''),
      _escapeCsv(tx.userEmail ?? ''),
      _escapeCsv(tx.userId ?? ''),
      _escapeCsv(tx.balanceBefore?.toString() ?? ''),
      _escapeCsv(tx.balanceAfter?.toString() ?? ''),
      _escapeCsv(tx.createdAt ?? ''),
    ].join(','));
  }

  return buffer.toString();
}