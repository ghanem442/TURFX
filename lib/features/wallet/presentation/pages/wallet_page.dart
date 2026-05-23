import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/utils/error_utils.dart';
import 'package:football/core/widgets/app_button.dart';
import 'package:football/features/wallet/data/wallet_repository.dart';
import 'package:football/core/routing/app_navigation.dart';
import 'package:go_router/go_router.dart';

import '../providers/wallet_providers.dart';

const List<String> _walletTransactionTypes = [
  'ALL',
  'REFUND',
  'BOOKING_PAYMENT',
  'DEPOSIT',
  'WITHDRAWAL',
  'CREDIT',
  'DEBIT',
  'PAYOUT',
  'COMMISSION_DEDUCTION',
];

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  final _scrollCtrl = ScrollController();
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 220) {
      _tryLoadMore();
    }
  }

  Future<void> _tryLoadMore() async {
    if (_loadingMore) return;

    final async = ref.read(walletProvider);
    final ui = async.valueOrNull;
    if (ui == null || !ui.pagination.hasMore) return;

    setState(() => _loadingMore = true);

    try {
      await ref.read(walletProvider.notifier).loadMore();
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _refresh() async {
    await ref.read(walletProvider.notifier).refreshWallet();
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final previousData = walletAsync.valueOrNull;

    final canPop = context.canPop();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        leading: canPop
            ? BackButton(
                onPressed: () => context.safePop(fallback: '/owner'),
              )
            : null,
        automaticallyImplyLeading: canPop,
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/home'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: walletAsync.when(
        loading: () {
          if (previousData != null) {
            return _WalletContent(
              ui: previousData,
              scrollCtrl: _scrollCtrl,
              loadingMore: _loadingMore,
              onRefresh: _refresh,
              onLoadMore: _tryLoadMore,
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
        error: (e, _) {
          if (previousData != null) {
            return Stack(
              children: [
                _WalletContent(
                  ui: previousData,
                  scrollCtrl: _scrollCtrl,
                  loadingMore: _loadingMore,
                  onRefresh: _refresh,
                  onLoadMore: _tryLoadMore,
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Material(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _friendlyError(e),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return _ErrorState(
            error: _friendlyError(e),
            onRetry: _refresh,
          );
        },
        data: (ui) => _WalletContent(
          ui: ui,
          scrollCtrl: _scrollCtrl,
          loadingMore: _loadingMore,
          onRefresh: _refresh,
          onLoadMore: _tryLoadMore,
        ),
      ),
    );
  }
}

class _WalletContent extends ConsumerWidget {
  final WalletUiState ui;
  final ScrollController scrollCtrl;
  final bool loadingMore;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;

  const _WalletContent({
    required this.ui,
    required this.scrollCtrl,
    required this.loadingMore,
    required this.onRefresh,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ui.allTransactions;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        controller: scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _BalanceCard(
            balance: ui.balance,
            updatedAt: ui.wallet.updatedAt,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Incoming',
                  value: _money(ui.totalIncoming),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: 'Outgoing',
                  value: _money(ui.totalOutgoing),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Transaction Filters',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _walletTransactionTypes.map((type) {
                final isSelected = (ui.selectedType ?? 'ALL') == type;

                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    selected: isSelected,
                    label: Text(_transactionTypeLabel(type)),
                    onSelected: (_) {
                      ref
                          .read(walletProvider.notifier)
                          .setTypeFilter(type == 'ALL' ? null : type);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Transactions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const Spacer(),
              Text(
                '${ui.pagination.total} total',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tx.isEmpty) ...[
            const SizedBox(height: 110),
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'No wallet transactions yet',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                ui.selectedType == null
                    ? 'Refunds, payments, and wallet activity will appear here.'
                    : 'No transactions found for the selected filter.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
          ] else ...[
            ...tx.map((t) => _TxTile(tx: t)),
            const SizedBox(height: 8),
            if (loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (ui.pagination.hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: TextButton(
                    onPressed: onLoadMore,
                    child: const Text('Load more'),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text('No more transactions'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  final DateTime updatedAt;

  const _BalanceCard({
    required this.balance,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: theme.colorScheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  _money(balance),
                  style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Updated ${_formatDateTime(updatedAt)}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final WalletTransactionModel tx;

  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isDebit = tx.isOutgoing;
    final isRefund = tx.type.toUpperCase() == 'REFUND';
    final color = isRefund
        ? Colors.blue
        : (isDebit ? Colors.red : Colors.green);
    final sign = isDebit ? '-' : '+';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            _transactionIcon(tx.type),
            color: color,
          ),
        ),
        title: Text(
          _transactionTitle(tx),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDateTime(tx.createdAt)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _MetaChip(
                    label: _transactionTypeLabel(tx.type),
                    icon: Icons.category_outlined,
                  ),
                  if (tx.type.toUpperCase() == 'REFUND')
                    const _MetaChip(
                      label: 'Refund',
                      icon: Icons.replay,
                    ),
                  if ((tx.status ?? '').trim().isNotEmpty)
                    _MetaChip(
                      label: _transactionStatusLabel(tx.status!),
                      icon: Icons.info_outline,
                    ),
                  if (tx.hasReference)
                    _MetaChip(
                      label: 'Ref: ${tx.reference}',
                      icon: Icons.tag_outlined,
                    ),
                  _MetaChip(
                    label: 'Balance: ${_money(tx.balanceAfter)}',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: Text(
          '$sign${_money(tx.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  String _transactionTitle(WalletTransactionModel tx) {
    final desc = tx.description.trim();
    if (desc.isNotEmpty) return desc;

    switch (tx.type.toUpperCase()) {
      case 'REFUND':
        return 'Refund from cancelled booking 💸';
      case 'BOOKING_PAYMENT':
        return 'Paid booking using wallet';
      case 'DEPOSIT':
        return 'Wallet deposit';
      case 'WITHDRAWAL':
        return 'Wallet withdrawal';
      case 'CREDIT':
        return 'Wallet credit';
      case 'DEBIT':
        return 'Wallet debit';
      case 'PAYOUT':
        return 'Payout';
      case 'COMMISSION_DEDUCTION':
        return 'Commission deduction';
      default:
        return _transactionTypeLabel(tx.type);
    }
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MetaChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade800),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            AppButton(
              text: 'Retry',
              width: 140,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _transactionIcon(String type) {
  switch (type.toUpperCase()) {
    case 'REFUND':
      return Icons.replay_circle_filled_rounded;
    case 'BOOKING_PAYMENT':
      return Icons.qr_code_scanner_rounded;
    case 'DEPOSIT':
      return Icons.south_west_rounded;
    case 'WITHDRAWAL':
      return Icons.north_east_rounded;
    case 'CREDIT':
      return Icons.add_circle_outline_rounded;
    case 'DEBIT':
      return Icons.remove_circle_outline_rounded;
    case 'PAYOUT':
      return Icons.payments_outlined;
    case 'COMMISSION_DEDUCTION':
      return Icons.percent_rounded;
    default:
      return Icons.receipt_long_rounded;
  }
}

String _transactionTypeLabel(String type) {
  switch (type.toUpperCase()) {
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
      return type;
  }
}

String _transactionStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return 'Pending';
    case 'COMPLETED':
      return 'Completed';
    case 'FAILED':
      return 'Failed';
    case 'CANCELLED':
      return 'Cancelled';
    case 'REFUNDED':
      return 'Refunded';
    default:
      return status;
  }
}

String _friendlyError(Object error) {
  return friendlyErrorMessage(
    error,
    fallback: 'تعذر تحميل بيانات المحفظة',
  );
}

String _money(double value) {
  final text = value.toStringAsFixed(
    value.truncateToDouble() == value ? 0 : 2,
  );
  return '$text EGP';
}

String _formatDateTime(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year.toString();

  int h = d.hour;
  final m = d.minute.toString().padLeft(2, '0');
  final ampm = h >= 12 ? 'PM' : 'AM';
  h = h % 12;
  if (h == 0) h = 12;

  return '$dd/$mm/$yyyy • $h:$m $ampm';
}