import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/utils/error_utils.dart';
import 'package:football/core/widgets/app_button.dart';
import 'package:football/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:football/features/fields/data/models/field_model.dart';
import 'package:football/features/owner/presentation/providers/owner_providers.dart';
import 'package:go_router/go_router.dart';

class OwnerFieldsPage extends ConsumerWidget {
  const OwnerFieldsPage({super.key});

  Future<void> _refreshFields(WidgetRef ref) async {
    ref.invalidate(ownerMyFieldsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<void> _openAddField(BuildContext context, WidgetRef ref) async {
    final result = await context.push<bool>('/owner/add-field');

    if (result == true) {
      ref.invalidate(ownerMyFieldsProvider);
    }
  }

  Future<void> _openFieldSlots(
    BuildContext context,
    String fieldId,
    String fieldName,
  ) async {
    await context.push(
      '/owner/field-slots',
      extra: {
        'fieldId': fieldId,
        'fieldName': fieldName,
      },
    );
  }

  Future<void> _openFieldBookings(
    BuildContext context,
    String fieldId,
    String fieldName,
  ) async {
    await context.push(
      '/owner/bookings',
      extra: {
        'fieldId': fieldId,
        'fieldName': fieldName,
      },
    );
  }

  Future<void> _deleteField(
    BuildContext context,
    WidgetRef ref,
    FieldModel field,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Field'),
        content: const Text(
          'Are you sure you want to delete this field?',
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
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    final repo = ref.read(ownerRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repo.deleteField(field.id);
      ref.invalidate(ownerMyFieldsProvider);

      if (!context.mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Field deleted successfully'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(ownerMyFieldsProvider);
    final user = ref.watch(authUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Fields'),
        actions: [
          IconButton(
            tooltip: 'Add Field',
            onPressed: () => _openAddField(context, ref),
            icon: const Icon(Icons.add_business_outlined),
          ),
          IconButton(
            tooltip: 'All Bookings',
            onPressed: () => context.push('/owner/bookings'),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _refreshFields(ref),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddField(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Field'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshFields(ref),
        child: fieldsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 120),
              const Icon(Icons.error_outline, size: 52, color: Colors.red),
              const SizedBox(height: 10),
              const Text(
                'Failed to load fields',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                friendlyErrorMessage(e),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Center(
                child: AppButton(
                  text: 'Retry',
                  width: 140,
                  onPressed: () async => _refreshFields(ref),
                ),
              ),
            ],
          ),
          data: (res) {
            final fields = res.data;

            if (fields.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 120),
                  const Icon(Icons.stadium_outlined, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'No fields found',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.email ?? '',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your account is connected successfully, but no fields are assigned yet.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _openAddField(context, ref),
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Create Your First Field'),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: fields.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final field = fields[index];

                return _FieldCard(
                  field: field,
                  onManageSlots: () => _openFieldSlots(
                    context,
                    field.id,
                    field.displayName,
                  ),
                  onEditField: () async {
                    final result = await context.push<bool>(
                      '/owner/edit-field?fieldId=${field.id}',
                    );

                    if (result == true) {
                      ref.invalidate(ownerMyFieldsProvider);
                    }
                  },
                  onBookings: () => _openFieldBookings(
                    context,
                    field.id,
                    field.displayName,
                  ),
                  onDeleteField: () => _deleteField(context, ref, field),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final FieldModel field;
  final VoidCallback onManageSlots;
  final VoidCallback onDeleteField;
  final VoidCallback onEditField;
  final VoidCallback onBookings;

  const _FieldCard({
    required this.field,
    required this.onManageSlots,
    required this.onDeleteField,
    required this.onEditField,
    required this.onBookings,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = field.primaryImageUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onManageSlots,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.trim().isNotEmpty)
              Image.network(
                imageUrl,
                width: double.infinity,
                height: 190,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackImage(),
              )
            else
              _fallbackImage(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    field.displayAddress.isEmpty ? '—' : field.displayAddress,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.photo_library_outlined,
                        label: '${field.images.length} images',
                      ),
                      _InfoChip(
                        icon: Icons.star_outline,
                        label: '${field.averageRating ?? 0.0}',
                      ),
                      _InfoChip(
                        icon: Icons.reviews_outlined,
                        label: '${field.totalReviews} reviews',
                      ),
                      _InfoChip(
                        icon: Icons.percent,
                        label: field.commissionRate != null
                            ? '${field.commissionRate}%'
                            : '—%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onManageSlots,
                        icon: const Icon(Icons.schedule_outlined),
                        label: const Text('Manage Slots'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onEditField,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onBookings,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('Bookings'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: onDeleteField,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: double.infinity,
      height: 190,
      alignment: Alignment.center,
      child: const Icon(Icons.stadium_outlined, size: 56),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
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
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}