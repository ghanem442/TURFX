import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../providers/admin_dashboard_provider.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await ref.read(authSessionProvider.notifier).logout();

    if (!context.mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(adminDashboardProvider);

    final items = <_DashboardMenuItem>[
      const _DashboardMenuItem(
        title: 'Users',
        subtitle: 'Manage app users',
        icon: Icons.people_alt_outlined,
        route: '/admin/users',
      ),
      const _DashboardMenuItem(
        title: 'Fields',
        subtitle: 'Manage football fields',
        icon: Icons.sports_soccer_outlined,
        route: '/admin/fields',
      ),
      const _DashboardMenuItem(
        title: 'Bookings',
        subtitle: 'Track all bookings',
        icon: Icons.event_note_outlined,
        route: '/admin/bookings',
      ),
      const _DashboardMenuItem(
        title: 'Pending Payments',
        subtitle: 'Review manual payment submissions',
        icon: Icons.payments_outlined,
        route: '/admin/payments',
      ),
      const _DashboardMenuItem(
        title: 'Payment Accounts',
        subtitle: 'Manage payment phone numbers',
        icon: Icons.phone_android_outlined,
        route: '/admin/payment-accounts',
      ),
      const _DashboardMenuItem(
        title: 'Withdrawal Requests',
        subtitle: 'Review owner withdrawal requests',
        icon: Icons.outbox_outlined,
        route: '/admin/withdrawal-requests',
      ),
      const _DashboardMenuItem(
        title: 'Settings',
        subtitle: 'System settings',
        icon: Icons.settings_outlined,
        route: '/admin/settings',
      ),
      const _DashboardMenuItem(
        title: 'Wallet',
        subtitle: 'User wallet transactions',
        icon: Icons.account_balance_wallet_outlined,
        route: '/admin/wallet',
      ),
      const _DashboardMenuItem(
        title: 'Platform Wallet',
        subtitle: 'Manage platform balance and withdrawals',
        icon: Icons.account_balance_outlined,
        route: '/admin/platform-wallet',
      ),
      const _DashboardMenuItem(
        title: 'Admin Account',
        subtitle: 'Change email and password',
        icon: Icons.manage_accounts_outlined,
        route: '/admin/account',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminDashboardProvider),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminDashboardProvider);
          await ref.read(adminDashboardProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _WelcomeCard(),
            const SizedBox(height: 16),
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            dashboardAsync.when(
              loading: () => const _DashboardLoadingGrid(),
              error: (error, _) => _DashboardErrorCard(
                message: error.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(adminDashboardProvider),
              ),
              data: (dashboard) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.08,
                children: [
                  _StatCard(
                    title: 'Active Bookings',
                    value: dashboard.activeBookings.toString(),
                    icon: Icons.event_available_outlined,
                  ),
                  _StatCard(
                    title: 'Pending Payments',
                    value: dashboard.pendingPayments.toString(),
                    icon: Icons.payments_outlined,
                  ),
                  _StatCard(
                    title: 'Total Users',
                    value: dashboard.totalUsers.toString(),
                    icon: Icons.people_outline,
                  ),
                  _StatCard(
                    title: 'Total Fields',
                    value: dashboard.totalFields.toString(),
                    icon: Icons.stadium_outlined,
                  ),
                  _StatCard(
                    title: 'Total Bookings',
                    value: dashboard.totalBookings.toString(),
                    icon: Icons.receipt_long_outlined,
                  ),
                  _StatCard(
                    title: 'Today Revenue',
                    value: _formatMoney(dashboard.todayRevenue),
                    icon: Icons.trending_up_outlined,
                  ),
                  _StatCard(
                    title: 'Today Commission',
                    value: _formatMoney(dashboard.todayCommission),
                    icon: Icons.account_balance_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Quick Access',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MenuCard(item: item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.admin_panel_settings_outlined,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, Admin',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage users, fields, bookings, pending manual payments, wallet activity, platform balance, withdrawal requests, and system settings from here.',
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final subColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final _DashboardMenuItem item;

  const _MenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(item.route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                child: Icon(item.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardLoadingGrid extends StatelessWidget {
  const _DashboardLoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.08,
      children: const [
        _LoadingCard(),
        _LoadingCard(),
        _LoadingCard(),
        _LoadingCard(),
        _LoadingCard(),
        _LoadingCard(),
        _LoadingCard(),
        _LoadingCard(),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _DashboardErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 10),
            const Text(
              'Failed to load dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  const _DashboardMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}

String _formatMoney(num value) {
  final number = value.toDouble();
  final text = number.truncateToDouble() == number
      ? number.toStringAsFixed(0)
      : number.toStringAsFixed(2);
  return '$text EGP';
}