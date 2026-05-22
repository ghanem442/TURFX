import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_users_provider.dart';

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final Set<String> _processingUserIds = <String>{};

  Future<void> _toggleUserSuspension({
    required String userId,
    required bool suspended,
  }) async {
    if (_processingUserIds.contains(userId)) return;

    setState(() {
      _processingUserIds.add(userId);
    });

    final repo = ref.read(adminUsersRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (suspended) {
        await repo.unsuspendUser(userId);
      } else {
        await repo.suspendUser(userId);
      }

      ref.invalidate(adminUsersProvider);

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            suspended
                ? 'User activated successfully'
                : 'User suspended successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingUserIds.remove(userId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminUsersProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load users',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(adminUsersProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminUsersProvider),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final suspended = user.suspendedUntil != null;
                final isProcessing = _processingUserIds.contains(user.id);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(user.email),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Role: ${user.role}'),
                        Text('No Shows: ${user.noShowCount}'),
                        Text('Verified: ${user.isVerified ? "YES" : "NO"}'),
                        if (suspended)
                          const Text(
                            'SUSPENDED',
                            style: TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: suspended ? Colors.green : Colors.red,
                      ),
                      onPressed: isProcessing
                          ? null
                          : () => _toggleUserSuspension(
                                userId: user.id,
                                suspended: suspended,
                              ),
                      child: isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(suspended ? 'Activate' : 'Suspend'),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}