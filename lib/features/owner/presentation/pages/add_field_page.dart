import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/widgets/app_button.dart';
import 'package:football/features/fields/data/models/create_field_request.dart';
import 'package:football/features/fields/data/models/field_model.dart';
import 'package:football/features/fields/presentation/providers/fields_providers.dart';
import 'package:football/features/owner/presentation/providers/owner_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class AddFieldPage extends ConsumerStatefulWidget {
  final String? fieldId;
  final FieldModel? field;

  const AddFieldPage({super.key, this.fieldId, this.field});

  bool get isEdit => field != null || (fieldId != null && fieldId!.trim().isNotEmpty);

  @override
  ConsumerState<AddFieldPage> createState() => _AddFieldPageState();
}

class _AddFieldPageState extends ConsumerState<AddFieldPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _commissionRateController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = [];
  final List<FieldImage> _existingImages = [];

  bool _isSubmitting = false;
  String? _deletingImageId;
  bool _fieldLoaded = false;

  @override
  void initState() {
    super.initState();
    _populateFromField(widget.field);
  }

  void _populateFromField(FieldModel? field) {
    if (field == null) return;
    _nameController.text = field.displayName;
    _descriptionController.text = field.description ?? '';
    _addressController.text = field.displayAddress;
    _latitudeController.text = field.latitude.toString();
    _longitudeController.text = field.longitude.toString();
    _basePriceController.text =
        field.basePrice == null ? '' : field.basePrice.toString();
    _commissionRateController.text =
        field.commissionRate == null ? '' : field.commissionRate.toString();

    _existingImages.clear();
    _existingImages.addAll(
      [...field.images]..sort((a, b) => a.order.compareTo(b.order)),
    );
    _fieldLoaded = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _basePriceController.dispose();
    _commissionRateController.dispose();
    super.dispose();
  }

  String? _validateRequiredText(
    String? value, {
    required String fieldName,
    int? minLength,
    int? maxLength,
  }) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return '$fieldName is required';
    }

    if (minLength != null && text.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    if (maxLength != null && text.length > maxLength) {
      return '$fieldName must be at most $maxLength characters';
    }

    return null;
  }

  String? _validateLatitude(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Latitude is required';

    final parsed = double.tryParse(text);
    if (parsed == null) return 'Latitude must be a valid number';
    if (parsed < -90 || parsed > 90) {
      return 'Latitude must be between -90 and 90';
    }
    return null;
  }

  String? _validateLongitude(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Longitude is required';

    final parsed = double.tryParse(text);
    if (parsed == null) return 'Longitude must be a valid number';
    if (parsed < -180 || parsed > 180) {
      return 'Longitude must be between -180 and 180';
    }
    return null;
  }

  String? _validateOptionalPositiveNumber(
    String? value, {
    String fieldName = 'Value',
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    final parsed = double.tryParse(text);
    if (parsed == null) return '$fieldName must be a valid number';
    if (parsed <= 0) return '$fieldName must be greater than 0';
    return null;
  }

  String? _validateOptionalCommission(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    final parsed = double.tryParse(text);
    if (parsed == null) return 'Commission rate must be a valid number';
    if (parsed < 0 || parsed > 100) {
      return 'Commission rate must be between 0 and 100';
    }
    return null;
  }

  Future<void> _pickImages() async {
    if (_isSubmitting) return;

    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );

      if (picked.isEmpty) return;

      final remainingSlots =
          10 - (_selectedImages.length + _existingImages.length);
      final imagesToAdd = picked.take(remainingSlots).toList();

      setState(() {
        _selectedImages.addAll(imagesToAdd);
      });

      if (!mounted) return;

      if (picked.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 10 images allowed per field'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImageAt(int index) {
    if (_isSubmitting) return;

    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _deleteExistingImage(FieldImage image) async {
    if (_isSubmitting || _deletingImageId != null || !widget.isEdit) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
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
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(ownerRepositoryProvider);

    setState(() {
      _deletingImageId = image.id;
    });

    try {
      await repo.deleteFieldImage(
        fieldId: (widget.field?.id ?? widget.fieldId)!,
        imageId: image.id,
      );

      if (!mounted) return;

      setState(() {
        _existingImages.removeWhere((e) => e.id == image.id);
      });

      ref.invalidate(ownerMyFieldsProvider);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Image deleted successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingImageId = null;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(ownerRepositoryProvider);

    final latitude = double.parse(_latitudeController.text.trim());
    final longitude = double.parse(_longitudeController.text.trim());
    final basePriceText = _basePriceController.text.trim();
    final commissionText = _commissionRateController.text.trim();

    final request = CreateFieldRequest(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      address: _addressController.text.trim(),
      latitude: latitude,
      longitude: longitude,
      basePrice: basePriceText.isEmpty ? null : double.parse(basePriceText),
      commissionRate:
          commissionText.isEmpty ? null : double.parse(commissionText),
    );

    setState(() => _isSubmitting = true);

    try {
      String fieldId;

      if (widget.isEdit) {
        await repo.updateField(
          fieldId: (widget.field?.id ?? widget.fieldId)!,
          name: request.name,
          description: request.description,
          address: request.address,
          latitude: request.latitude,
          longitude: request.longitude,
          basePrice: request.basePrice,
          commissionRate: request.commissionRate,
        );

        fieldId = (widget.field?.id ?? widget.fieldId)!;
      } else {
        final result = await repo.createField(request);
        fieldId = result.data.id;
      }

      for (final image in _selectedImages) {
        await repo.uploadFieldImage(
          fieldId: fieldId,
          imageFile: File(image.path),
        );
      }

      ref.invalidate(ownerMyFieldsProvider);

      if (!mounted) return;

      final uploadedCount = _selectedImages.length;
      final successText = widget.isEdit
          ? (uploadedCount > 0
              ? 'Field updated successfully and $uploadedCount image(s) uploaded'
              : 'Field updated successfully')
          : (uploadedCount > 0
              ? 'Field created successfully with $uploadedCount image(s)'
              : 'Field created successfully');

      messenger.showSnackBar(
        SnackBar(content: Text(successText)),
      );

      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _fillSampleData() {
    _nameController.text = 'Champions Field';
    _descriptionController.text =
        'Professional 5-a-side football field with artificial turf and floodlights.';
    _addressController.text = 'Nasr City, Cairo';
    _latitudeController.text = '30.0444';
    _longitudeController.text = '31.2357';
    _basePriceController.text = '200';
    _commissionRateController.text = '';
  }

  Widget _buildExistingImagesSection() {
    if (!widget.isEdit || _existingImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Images',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap delete on any image to remove it from this field.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _existingImages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final image = _existingImages[index];
              final isDeleting = _deletingImageId == image.id;

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      image.url,
                      width: 120,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 120,
                        height: 110,
                        alignment: Alignment.center,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  if (image.isPrimary)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Primary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: isDeleting ? null : () => _deleteExistingImage(image),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: isDeleting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImagesSection() {
    final totalImagesCount = _existingImages.length + _selectedImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Field Images',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isEdit
              ? 'You can keep current images, delete any existing image, and upload new ones. Maximum 10 images total.'
              : 'You can upload up to 10 images. The first uploaded image becomes the primary image automatically.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (widget.isEdit && _existingImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildExistingImagesSection(),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isSubmitting || totalImagesCount >= 10 ? null : _pickImages,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            _selectedImages.isEmpty
                ? 'Choose Images'
                : 'Add More Images ($totalImagesCount/10)',
          ),
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'New Images to Upload',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final image = _selectedImages[index];
                final isPrimaryPreview =
                    _existingImages.isEmpty && index == 0;

                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(image.path),
                        width: 120,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (isPrimaryPreview)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Primary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _removeImageAt(index),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.field == null &&
        widget.fieldId != null &&
        widget.fieldId!.trim().isNotEmpty &&
        !_fieldLoaded) {
      final async = ref.watch(fieldByIdProvider(widget.fieldId!));
      final field = async.valueOrNull;
      if (field != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _populateFromField(field));
          }
        });
      }
      if (async.isLoading) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.isEdit ? 'Edit Field' : 'Add Field')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
    }

    final helperText = _isSubmitting
        ? (_selectedImages.isEmpty
            ? (widget.isEdit ? 'Updating field...' : 'Creating field...')
            : widget.isEdit
                ? 'Updating field and uploading ${_selectedImages.length} image(s)...'
                : 'Creating field and uploading ${_selectedImages.length} image(s)...')
        : widget.isEdit
            ? 'Update the field details below. You can also manage the field images here.'
            : 'Enter the field details below. Images are optional and will be uploaded after field creation.';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Field' : 'Add Field'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _fillSampleData,
            child: const Text('Fill Sample'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.isEdit ? 'Edit Field' : 'Create New Field',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                helperText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Field Name',
                  hintText: 'Enter field name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateRequiredText(
                  value,
                  fieldName: 'Field name',
                  minLength: 3,
                  maxLength: 100,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe the field',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) => _validateRequiredText(
                  value,
                  fieldName: 'Description',
                  minLength: 10,
                  maxLength: 1000,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateRequiredText(
                  value,
                  fieldName: 'Address',
                  minLength: 10,
                  maxLength: 500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: '30.0444',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateLatitude,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: '31.2357',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateLongitude,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _basePriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Base Price (optional)',
                  hintText: '200',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateOptionalPositiveNumber(
                  value,
                  fieldName: 'Base price',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commissionRateController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Commission Rate % (optional)',
                  hintText: '10',
                  border: OutlineInputBorder(),
                ),
                validator: _validateOptionalCommission,
              ),
              const SizedBox(height: 24),
              _buildImagesSection(),
              const SizedBox(height: 24),
              AppButton(
                text: widget.isEdit ? 'Update Field' : 'Create Field',
                icon: widget.isEdit
                    ? Icons.save_outlined
                    : Icons.add_business_outlined,
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