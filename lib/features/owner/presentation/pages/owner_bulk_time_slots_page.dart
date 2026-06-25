import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/widgets/app_button.dart';
import 'package:football/features/owner/data/models/owner_bulk_slot_models.dart';
import 'package:football/features/owner/presentation/providers/owner_providers.dart';
import 'package:go_router/go_router.dart';

class OwnerBulkTimeSlotsPage extends ConsumerStatefulWidget {
  final String fieldId;
  final String fieldName;
  final DateTime? selectedDate;

  const OwnerBulkTimeSlotsPage({
    super.key,
    required this.fieldId,
    required this.fieldName,
    this.selectedDate,
  });

  @override
  ConsumerState<OwnerBulkTimeSlotsPage> createState() =>
      _OwnerBulkTimeSlotsPageState();
}

class _OwnerBulkTimeSlotsPageState
    extends ConsumerState<OwnerBulkTimeSlotsPage> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _startDate;
  late DateTime _endDate;

  final Map<int, bool> _selectedWeekdays = {
    0: true, // Sunday
    1: true, // Monday
    2: true, // Tuesday
    3: true, // Wednesday
    4: true, // Thursday
    5: true, // Friday
    6: true, // Saturday
  };

  final List<_TimeRangeFormItem> _timeRanges = [];

  @override
  void initState() {
    super.initState();
    // Bug Fix 4: Use the selected date from the main screen if provided
    final now = DateTime.now();
    final baseDate = widget.selectedDate ?? DateTime(now.year, now.month, now.day);
    _startDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    _endDate = _startDate;
    _timeRanges.add(_TimeRangeFormItem());
  }

  @override
  void dispose() {
    for (final item in _timeRanges) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(now) ? now : _startDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(DateTime.now().year + 2),
    );

    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  String _formatDate(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    return '$dd/$mm/$yyyy';
  }

  int _daysInclusive(DateTime start, DateTime end) {
    return end.difference(start).inDays + 1;
  }

  String _toApiTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  List<int> _selectedDaysOfWeek() {
    return _selectedWeekdays.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList()
      ..sort();
  }

  String _weekdayLabel(int value) {
    switch (value) {
      case 0:
        return 'Sun';
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      default:
        return value.toString();
    }
  }

  void _addTimeRange() {
    setState(() {
      _timeRanges.add(_TimeRangeFormItem());
    });
  }

  void _removeTimeRange(int index) {
    if (_timeRanges.length == 1) return;

    setState(() {
      final item = _timeRanges.removeAt(index);
      item.dispose();
    });
  }

  Future<void> _pickRangeStart(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _timeRanges[index].startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _timeRanges[index].startTime = picked;
      });
    }
  }

  Future<void> _pickRangeEnd(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _timeRanges[index].endTime ?? const TimeOfDay(hour: 10, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _timeRanges[index].endTime = picked;
      });
    }
  }

  String? _validatePrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Price is required';

    final parsed = double.tryParse(text);
    if (parsed == null) return 'Price must be a valid number';
    if (parsed <= 0) return 'Price must be greater than 0';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final selectedDays = _selectedDaysOfWeek();
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ranges = <BulkTimeRangeItem>[];

    for (final item in _timeRanges) {
      if (item.startTime == null || item.endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select start and end time for every range'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_minutesOfDay(item.startTime!) >= _minutesOfDay(item.endTime!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Every start time must be before end time'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final price = double.tryParse(item.priceController.text.trim());
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Every price must be greater than 0'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      ranges.add(
        BulkTimeRangeItem(
          startTime: _toApiTime(item.startTime!),
          endTime: _toApiTime(item.endTime!),
          price: price,
        ),
      );
    }

    final repo = ref.read(ownerRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await repo.bulkCreateTimeSlots(
        fieldId: widget.fieldId,
        startDate: _startDate,
        endDate: _endDate,
        daysOfWeek: selectedDays,
        timeRanges: ranges,
      );

      if (!mounted) return;

      // Check if backend sent created/skipped counts
      final created = result.count;
      final skipped = result.skipped;
      
      String message;
      if (skipped > 0) {
        // Show both created and skipped counts
        message = '$created slots created successfully. $skipped slots were skipped because they already existed.';
      } else if (result.message?.trim().isNotEmpty == true) {
        message = result.message!;
      } else {
        message = 'Created $created slots successfully';
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$message\n${result.dates} day(s) × ${result.timeRanges} range(s) = $created slot(s)',
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      // Bug Fix 1: Return the start date so the list can refresh with the correct date
      context.pop({'success': true, 'date': _startDate});
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e.toString().replaceFirst('Exception: ', '').trim();
      
      // Bug Fix 2: Handle overlapping slot error specially
      // If slots already exist, treat it as success and refresh the list
      if (errorMessage.contains('timeSlot.overlappingSlot') || 
          errorMessage.contains('timeSlot.overlappingSlotDetails') ||
          errorMessage.contains('overlappingSlot') ||
          errorMessage.toLowerCase().contains('overlapping')) {
        
        // Show friendly message in a dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Slots Already Exist'),
            content: const Text(
              'Some or all of these slots already exist. Please adjust your date range or time.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        
        // Return success with the date so the list refreshes
        if (!mounted) return;
        context.pop({'success': true, 'date': _startDate});
        return;
      }

      // Handle rate limit error
      if (errorMessage.contains('429') || 
          errorMessage.toLowerCase().contains('too many requests') ||
          errorMessage.toLowerCase().contains('toomanyrequests')) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Too many requests, please wait a moment'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // Show user-friendly error message
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

  @override
  Widget build(BuildContext context) {
    final selectedDays = _selectedDaysOfWeek();
    final totalDays = _daysInclusive(_startDate, _endDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Create Slots'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.fieldName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Create multiple recurring time slots across a date range.',
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.play_arrow_outlined),
                  title: const Text('Start Date'),
                  subtitle: Text(_formatDate(_startDate)),
                  trailing: TextButton(
                    onPressed: _pickStartDate,
                    child: const Text('Change'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.stop_outlined),
                  title: const Text('End Date'),
                  subtitle: Text(_formatDate(_endDate)),
                  trailing: TextButton(
                    onPressed: _pickEndDate,
                    child: const Text('Change'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Days of Week',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  return _DayChip(
                    label: _weekdayLabel(index),
                    value: _selectedWeekdays[index] ?? false,
                    onChanged: (v) => setState(() {
                              _selectedWeekdays[index] = v;
                            }),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Time Ranges',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _addTimeRange,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Range'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(_timeRanges.length, (index) {
                final item = _timeRanges[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Range ${index + 1}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              if (_timeRanges.length > 1)
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: () => _removeTimeRange(index),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.schedule_outlined),
                              title: const Text('Start Time'),
                              subtitle: Text(
                                item.startTime == null
                                    ? 'Not selected'
                                    : item.startTime!.format(context),
                              ),
                              trailing: TextButton(
                                onPressed: () => _pickRangeStart(index),
                                child: const Text('Select'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.schedule_outlined),
                              title: const Text('End Time'),
                              subtitle: Text(
                                item.endTime == null
                                    ? 'Not selected'
                                    : item.endTime!.format(context),
                              ),
                              trailing: TextButton(
                                onPressed: () => _pickRangeEnd(index),
                                child: const Text('Select'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: item.priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              hintText: '150',
                              suffixText: 'EGP',
                              border: OutlineInputBorder(),
                            ),
                            validator: _validatePrice,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text(
                    'Preview',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Date range: $totalDays day(s)\nSelected weekdays: ${selectedDays.length}\nTime ranges: ${_timeRanges.length}',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Create Bulk Slots',
                icon: Icons.auto_awesome_motion_outlined,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              AppButton(
                text: 'Cancel',
                outlined: true,
                onPressed: () async => context.pop(),
              ),
              const SizedBox(height: 12),
              Text(
                'Note: bulk creation is all-or-nothing. If any slot overlaps with an existing slot, the whole request will fail.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeRangeFormItem {
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  final TextEditingController priceController = TextEditingController();

  void dispose() {
    priceController.dispose();
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _DayChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: value,
      label: Text(label),
      onSelected: onChanged,
    );
  }
}
