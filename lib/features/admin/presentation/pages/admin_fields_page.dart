import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/features/admin/data/providers/admin_fields_provider.dart';

import '../../data/models/admin_field_model.dart';
import '../../data/providers/admin_fields_repository_provider.dart';

class AdminFieldsPage extends ConsumerStatefulWidget {
  const AdminFieldsPage({super.key});

  @override
  ConsumerState<AdminFieldsPage> createState() => _AdminFieldsPageState();
}

class _AdminFieldsPageState extends ConsumerState<AdminFieldsPage> {
  late final TextEditingController _searchController;

  static const List<String> _statuses = [
    'ALL',
    'ACTIVE',
    'INACTIVE',
    'HIDDEN',
    'DISABLED',
    'PENDING_APPROVAL',
    'REJECTED',
    'DELETED',
  ];

  @override
  void initState() {
    super.initState();
    final initialSearch = ref.read(adminFieldsProvider).search;
    _searchController = TextEditingController(text: initialSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteField(AdminFieldModel field) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Field'),
            content: Text(
              'Are you sure you want to delete "${field.name}"?\n\nThis action is soft delete.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    if (!mounted) return;

    final repo = ref.read(adminFieldsRepositoryProvider);
    final notifier = ref.read(adminFieldsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repo.deleteField(field.id);

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Field deleted successfully')),
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

  Future<void> _changeStatus(AdminFieldModel field) async {
    const options = [
      'ACTIVE',
      'INACTIVE',
      'HIDDEN',
    ];

    final currentStatus = (field.status ?? '').trim().toUpperCase();

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Change Field Status',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ...options
                .where((status) => status != currentStatus)
                .map(
                  (status) => ListTile(
                    title: Text(status),
                    onTap: () => Navigator.pop(context, status),
                  ),
                ),
          ],
        ),
      ),
    );

    debugPrint('SELECTED STATUS => $selected');

    if (selected == null || selected.trim().isEmpty) return;
    if (!mounted) return;

    final repo = ref.read(adminFieldsRepositoryProvider);
    final notifier = ref.read(adminFieldsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    try {
      debugPrint('CALLING API WITH => ${selected.trim()}');

      await repo.updateFieldStatus(
        fieldId: field.id,
        status: selected.trim(),
      );

      debugPrint('STATUS UPDATED SUCCESS');

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Field status updated to ${selected.trim()}')),
      );

      await notifier.refresh();
    } catch (e) {
      debugPrint('ERROR => $e');

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
    final state = ref.watch(adminFieldsProvider);
    final notifier = ref.read(adminFieldsProvider.notifier);

    final effectiveStatus = state.status ?? 'ALL';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fields Management'),
        actions: [
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
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: notifier.applySearch,
                  decoration: InputDecoration(
                    hintText: 'Search by field name or address',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              notifier.applySearch('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statuses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final status = _statuses[index];
                      final selected = effectiveStatus == status;

                      return ChoiceChip(
                        selected: selected,
                        label: Text(status),
                        onSelected: (_) {
                          notifier.setStatus(status == 'ALL' ? null : status);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.isLoading && state.fields.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.error != null && state.fields.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 52),
                          const SizedBox(height: 12),
                          const Text(
                            'Failed to load fields',
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

                if (!state.isLoading && state.fields.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: notifier.refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 90),
                        Icon(Icons.stadium_outlined, size: 64),
                        SizedBox(height: 16),
                        Text(
                          'No fields found',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try changing your search or filter.',
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: state.fields.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final field = state.fields[index];

                      return _FieldCard(
                        field: field,
                        onDelete: () => _deleteField(field),
                        onChangeStatus: () => _changeStatus(field),
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

class _FieldCard extends StatelessWidget {
  final AdminFieldModel field;
  final VoidCallback onDelete;
  final VoidCallback onChangeStatus;

  const _FieldCard({
    required this.field,
    required this.onDelete,
    required this.onChangeStatus,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusText = _fieldStatusLabel(field);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(
                  label: statusText,
                  color: _statusColor(field, context),
                  backgroundColor: _statusBgColor(field, context),
                ),
                if (field.basePrice != null)
                  _Badge(
                    label: '${_money(field.basePrice!)} / hr',
                    color: scheme.primary,
                    backgroundColor: scheme.primaryContainer,
                  ),
                if (field.commissionRate != null)
                  _Badge(
                    label:
                        'Commission ${field.commissionRate!.toStringAsFixed(field.commissionRate! % 1 == 0 ? 0 : 2)}%',
                    color: Colors.deepPurple.shade800,
                    backgroundColor: Colors.deepPurple.shade100,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              field.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              field.address,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.person_outline,
              title: 'Owner',
              value: (field.ownerName?.trim().isNotEmpty ?? false)
                  ? field.ownerName!.trim()
                  : 'Unknown owner',
            ),
            if (field.ownerEmail?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.email_outlined,
                title: 'Owner Email',
                value: field.ownerEmail!.trim(),
              ),
            ],
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.receipt_long_outlined,
              title: 'Field ID',
              value: field.id,
            ),
            if (field.createdAt.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.access_time_outlined,
                title: 'Created',
                value: field.createdAt,
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onChangeStatus,
                  icon: const Icon(Icons.sync_alt_outlined),
                  label: const Text('Change Status'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
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

String _fieldStatusLabel(AdminFieldModel field) {
  if (field.deletedAt != null) return 'DELETED';
  final status = (field.status ?? '').trim().toUpperCase();
  if (status.isEmpty) return 'UNKNOWN';
  return status;
}

Color _statusColor(AdminFieldModel field, BuildContext context) {
  final status = _fieldStatusLabel(field);

  switch (status) {
    case 'ACTIVE':
      return Colors.green.shade800;
    case 'INACTIVE':
      return Colors.orange.shade800;
    case 'HIDDEN':
      return Colors.blueGrey.shade800;
    case 'DISABLED':
      return Colors.red.shade700;
    case 'PENDING_APPROVAL':
      return Colors.amber.shade900;
    case 'REJECTED':
      return Colors.deepOrange.shade800;
    case 'DELETED':
      return Colors.red.shade800;
    default:
      return Theme.of(context).colorScheme.primary;
  }
}

Color _statusBgColor(AdminFieldModel field, BuildContext context) {
  final status = _fieldStatusLabel(field);

  switch (status) {
    case 'ACTIVE':
      return Colors.green.shade100;
    case 'INACTIVE':
      return Colors.orange.shade100;
    case 'HIDDEN':
      return Colors.blueGrey.shade100;
    case 'DISABLED':
      return Colors.red.shade100;
    case 'PENDING_APPROVAL':
      return Colors.amber.shade100;
    case 'REJECTED':
      return Colors.deepOrange.shade100;
    case 'DELETED':
      return Colors.red.shade100;
    default:
      return Theme.of(context).colorScheme.primaryContainer;
  }
}

String _money(double value) {
  final text = value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '$text EGP';
}