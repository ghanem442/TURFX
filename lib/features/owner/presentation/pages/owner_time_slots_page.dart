import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/features/bookings/data/models/time_slot_model.dart';
import 'package:football/features/owner/presentation/providers/owner_providers.dart';
import 'package:go_router/go_router.dart';

class OwnerTimeSlotsPage extends ConsumerStatefulWidget {
  final String fieldId;
  final String fieldName;

  const OwnerTimeSlotsPage({
    super.key,
    required this.fieldId,
    required this.fieldName,
  });

  @override
  ConsumerState<OwnerTimeSlotsPage> createState() => _OwnerTimeSlotsPageState();
}

class _OwnerTimeSlotsPageState extends ConsumerState<OwnerTimeSlotsPage> {
  late DateTime _selectedDate;
  // Bug Fix 3: Use a key to control FutureBuilder refresh instead of setState
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _refreshList({DateTime? forDate}) {
    setState(() {
      if (forDate != null) {
        _selectedDate = forDate;
      }
      _refreshKey++;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _openAddSlot() async {
    final result = await context.push<dynamic>(
      '/owner/field-slots/edit',
      extra: {
        'fieldId': widget.fieldId,
        'fieldName': widget.fieldName,
        'date': _selectedDate,
      },
    );

    // Bug Fix 1: Refresh with the date from the result, not today's date
    if (result is Map && result['success'] == true && mounted) {
      final dateFromResult = result['date'] as DateTime?;
      _refreshList(forDate: dateFromResult ?? _selectedDate);
    }
  }

  Future<void> _openBulkSlots() async {
    // Bug Fix 4: Pass the selected date to bulk creation
    final result = await context.push<dynamic>(
      '/owner/field-slots/bulk',
      extra: {
        'fieldId': widget.fieldId,
        'fieldName': widget.fieldName,
        'selectedDate': _selectedDate,
      },
    );

    // Bug Fix 1: Refresh with the date from the result
    if (result is Map && result['success'] == true && mounted) {
      final dateFromResult = result['date'] as DateTime?;
      _refreshList(forDate: dateFromResult ?? _selectedDate);
    } else if (result == true && mounted) {
      // Fallback for old boolean return
      _refreshList();
    }
  }

  Future<void> _openEditSlot(TimeSlotModel slot) async {
    final result = await context.push<dynamic>(
      '/owner/field-slots/edit',
      extra: {
        'fieldId': widget.fieldId,
        'fieldName': widget.fieldName,
        'slot': slot,
      },
    );

    // Bug Fix 1: Refresh with the date from the result
    if (result is Map && result['success'] == true && mounted) {
      final dateFromResult = result['date'] as DateTime?;
      _refreshList(forDate: dateFromResult ?? _selectedDate);
    }
  }

  Future<void> _deleteSlot(TimeSlotModel slot) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(ownerRepositoryProvider);

    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Time Slot'),
            content: Text(
              'Delete slot ${_formatTime(slot.start)} - ${_formatTime(slot.end)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => context.pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await repo.deleteTimeSlot(slot.id);

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Time slot deleted successfully')),
      );

      // Bug Fix 3: Use _refreshList instead of setState
      _refreshList();
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e.toString().replaceFirst('Exception: ', '').trim();
      final friendlyMessage = _getFriendlyErrorMessage(errorMessage);
      
      messenger.showSnackBar(
        SnackBar(
          content: Text(friendlyMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _getFriendlyErrorMessage(String error) {
    final lower = error.toLowerCase();
    
    // Check for common error patterns
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (lower.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (lower.contains('unauthorized') || lower.contains('401')) {
      return 'Session expired. Please log in again.';
    }
    if (lower.contains('forbidden') || lower.contains('403')) {
      return 'You do not have permission to perform this action.';
    }
    if (lower.contains('not found') || lower.contains('404')) {
      return 'Resource not found. Please try again.';
    }
    if (lower.contains('server') || lower.contains('500') || lower.contains('502') || lower.contains('503')) {
      return 'Server error. Please try again later.';
    }
    if (lower.contains('429') || lower.contains('too many requests') || lower.contains('toomanyrequests')) {
      return 'Too many requests, please wait a moment';
    }
    
    // If error looks like a backend key (no spaces, has dots), show generic message
    if (!error.contains(' ') && error.contains('.')) {
      return 'Something went wrong, please try again';
    }
    
    // If we have a readable message, show it
    if (error.isNotEmpty && error.length < 200) {
      return error;
    }
    
    // Fallback
    return 'Something went wrong, please try again';
  }

  IconData _getErrorIcon(String error) {
    final lower = error.toLowerCase();
    
    if (lower.contains('network') || lower.contains('connection')) {
      return Icons.wifi_off;
    }
    if (lower.contains('429') || lower.contains('too many requests')) {
      return Icons.hourglass_empty;
    }
    if (lower.contains('unauthorized') || lower.contains('401')) {
      return Icons.lock_outline;
    }
    if (lower.contains('server') || lower.contains('500')) {
      return Icons.cloud_off;
    }
    
    return Icons.error_outline;
  }

  Color _getErrorColor(String error) {
    final lower = error.toLowerCase();
    
    if (lower.contains('429') || lower.contains('too many requests')) {
      return Colors.orange;
    }
    if (lower.contains('unauthorized') || lower.contains('401')) {
      return Colors.amber;
    }
    
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(ownerRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fieldName),
        actions: [
          IconButton(
            tooltip: 'Pick Date',
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
          ),
          IconButton(
            tooltip: 'Bulk Create',
            onPressed: _openBulkSlots,
            icon: const Icon(Icons.auto_awesome_motion_outlined),
          ),
          IconButton(
            tooltip: 'Add Slot',
            onPressed: _openAddSlot,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'bulk_slots_fab',
            onPressed: _openBulkSlots,
            icon: const Icon(Icons.auto_awesome_motion_outlined),
            label: const Text('Bulk Slots'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_slot_fab',
            onPressed: _openAddSlot,
            icon: const Icon(Icons.add),
            label: const Text('Add Slot'),
          ),
        ],
      ),
      // Bug Fix 3: Add key to FutureBuilder to control when it rebuilds
      body: FutureBuilder<List<TimeSlotModel>>(
        key: ValueKey(_refreshKey),
        future: repo.getFieldTimeSlots(
          fieldId: widget.fieldId,
          startDate: _selectedDate,
          endDate: _selectedDate,
          limit: 100,
        ),
        builder: (context, snapshot) {
          final titleDate =
              '${_selectedDate.day.toString().padLeft(2, '0')}/'
              '${_selectedDate.month.toString().padLeft(2, '0')}/'
              '${_selectedDate.year}';

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final errorText = snapshot.error.toString();
            final friendlyError = _getFriendlyErrorMessage(errorText);
            
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getErrorIcon(errorText),
                      size: 48,
                      color: _getErrorColor(errorText),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      friendlyError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _refreshList(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final slots = [...(snapshot.data ?? [])]
            ..sort((a, b) => a.start.compareTo(b.start));

          return RefreshIndicator(
            onRefresh: () async => _refreshList(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text(
                      'Selected Date',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(titleDate),
                    trailing: TextButton(
                      onPressed: _pickDate,
                      child: const Text('Change'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome_motion_outlined),
                    title: const Text(
                      'Bulk Create Slots',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Create the same time slot across multiple dates at once.',
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: _openBulkSlots,
                      child: const Text('Open'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Available Time Slots',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Booked slots do not appear here because the current backend query returns available slots only.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (slots.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.access_time_outlined, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'No time slots for this date',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create the first available slot for this field.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: _openAddSlot,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Time Slot'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _openBulkSlots,
                                icon: const Icon(
                                  Icons.auto_awesome_motion_outlined,
                                ),
                                label: const Text('Bulk Slots'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...slots.map(
                    (slot) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_formatTime(slot.start)} - ${_formatTime(slot.end)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      slot.status,
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_formatMoney(slot.priceAsDouble)} EGP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _openEditSlot(slot),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _deleteSlot(slot),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _formatMoney(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}