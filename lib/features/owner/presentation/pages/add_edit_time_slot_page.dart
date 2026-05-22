import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/widgets/app_button.dart';
import 'package:football/features/bookings/data/models/time_slot_model.dart';
import 'package:football/features/owner/presentation/providers/owner_providers.dart';
import 'package:go_router/go_router.dart';

class AddEditTimeSlotPage extends ConsumerStatefulWidget {
  final String fieldId;
  final String fieldName;
  final Map<String, dynamic>? slotData;
  final DateTime? initialDate;

  const AddEditTimeSlotPage({
    super.key,
    required this.fieldId,
    required this.fieldName,
    this.slotData,
    this.initialDate,
  });

  @override
  ConsumerState<AddEditTimeSlotPage> createState() =>
      _AddEditTimeSlotPageState();
}

class _AddEditTimeSlotPageState extends ConsumerState<AddEditTimeSlotPage> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();

  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  TimeSlotModel? _slot;

  bool get _isEdit => _slot != null;

  @override
  void initState() {
    super.initState();

    final data = widget.slotData;
    if (data != null) {
      try {
        _slot = TimeSlotModel.fromJson(data);
      } catch (_) {
        _slot = null;
      }
    }

    final now = DateTime.now();
    _selectedDate = _slot?.date ??
        widget.initialDate ??
        DateTime(now.year, now.month, now.day);

    if (_slot != null) {
      _startTime = TimeOfDay(
        hour: _slot!.start.hour,
        minute: _slot!.start.minute,
      );
      _endTime = TimeOfDay(
        hour: _slot!.end.hour,
        minute: _slot!.end.minute,
      );
      _priceController.text = _slot!.priceAsDouble ==
              _slot!.priceAsDouble.truncateToDouble()
          ? _slot!.priceAsDouble.toStringAsFixed(0)
          : _slot!.priceAsDouble.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
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

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 10, minute: 0),
    );

    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  String _toApiTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  String? _validatePrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Price is required';

    final parsed = double.tryParse(text);
    if (parsed == null) return 'Price must be a valid number';
    if (parsed <= 0) return 'Price must be greater than 0';
    return null;
  }

  Future<void> _submit() async {
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start time and end time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_minutesOfDay(_startTime!) >= _minutesOfDay(_endTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start time must be before end time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(ownerRepositoryProvider);
    final price = double.parse(_priceController.text.trim());

    try {
      if (_isEdit) {
        await repo.updateTimeSlot(
          slotId: _slot!.id,
          date: _selectedDate,
          startTime: _toApiTime(_startTime!),
          endTime: _toApiTime(_endTime!),
          price: price,
        );
      } else {
        await repo.createTimeSlot(
          fieldId: widget.fieldId,
          date: _selectedDate,
          startTime: _toApiTime(_startTime!),
          endTime: _toApiTime(_endTime!),
          price: price,
        );
      }

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Time slot updated successfully'
                : 'Time slot created successfully',
          ),
        ),
      );

      // Bug Fix 1: Return the date that was used for creation/update
      // so the list can refresh with the correct date
      context.pop({'success': true, 'date': _selectedDate});
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e.toString().replaceFirst('Exception: ', '').trim();
      
      // Bug Fix 2: Handle overlapping slot error specially
      // If the slot already exists, treat it as success and refresh the list
      if (errorMessage.contains('timeSlot.overlappingSlot') || 
          errorMessage.contains('overlappingSlot') ||
          errorMessage.toLowerCase().contains('overlapping')) {
        
        // Show friendly message in a dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Time Slot Already Exists'),
            content: const Text(
              'A time slot already exists for this date and time. Showing you the existing slots.',
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
        context.pop({'success': true, 'date': _selectedDate});
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
    final title = _isEdit ? 'Edit Time Slot' : 'Add Time Slot';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
              Text(
                _isEdit
                    ? 'Update the selected slot details.'
                    : 'Create a new available time slot for this field.',
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Date'),
                  subtitle: Text(
                    '${_selectedDate.day.toString().padLeft(2, '0')}/'
                    '${_selectedDate.month.toString().padLeft(2, '0')}/'
                    '${_selectedDate.year}',
                  ),
                  trailing: TextButton(
                    onPressed: _pickDate,
                    child: const Text('Change'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Start Time'),
                  subtitle: Text(
                    _startTime == null
                        ? 'Not selected'
                        : _startTime!.format(context),
                  ),
                  trailing: TextButton(
                    onPressed: _pickStartTime,
                    child: const Text('Select'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('End Time'),
                  subtitle: Text(
                    _endTime == null ? 'Not selected' : _endTime!.format(context),
                  ),
                  trailing: TextButton(
                    onPressed: _pickEndTime,
                    child: const Text('Select'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price',
                  hintText: '150',
                  suffixText: 'EGP',
                  border: OutlineInputBorder(),
                ),
                validator: _validatePrice,
              ),
              const SizedBox(height: 24),
              AppButton(
                text: _isEdit ? 'Update Slot' : 'Create Slot',
                icon: Icons.save_outlined,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              AppButton(
                text: 'Cancel',
                outlined: true,
                onPressed: () async => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}