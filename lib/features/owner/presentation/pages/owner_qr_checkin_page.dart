import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/widgets/app_button.dart';
import 'package:football/features/owner/data/owner_repository.dart';
import 'package:football/features/owner/presentation/providers/owner_providers.dart';
import 'package:football/core/routing/app_navigation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class OwnerQrCheckInPage extends ConsumerStatefulWidget {
  final String? fieldId;
  final String? fieldName;
  final String? initialBookingId;
  final String? initialQrToken;

  const OwnerQrCheckInPage({
    super.key,
    this.fieldId,
    this.fieldName,
    this.initialBookingId,
    this.initialQrToken,
  });

  @override
  ConsumerState<OwnerQrCheckInPage> createState() => _OwnerQrCheckInPageState();
}

class _OwnerQrCheckInPageState extends ConsumerState<OwnerQrCheckInPage> {
  final _bookingIdController = TextEditingController();
  final _qrTokenController = TextEditingController();

  bool _verifyingBookingId = false;
  bool _verifyingQr = false;

  bool _scannerOpen = false;
  bool _scannerProcessing = false;
  MobileScannerController? _scannerController;

  String? _lastScannedToken;
  OwnerCheckInResult? _lastCheckInResult;

  bool get _busy =>
      _verifyingBookingId || _verifyingQr || _scannerProcessing;

  @override
  void initState() {
    super.initState();
    _bookingIdController.text = widget.initialBookingId ?? '';
    _qrTokenController.text = widget.initialQrToken ?? '';
  }

  @override
  void dispose() {
    _bookingIdController.dispose();
    _qrTokenController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _refreshAfterSuccess() async {
    await ref.read(ownerBookingsProvider.notifier).forceRefresh();
  }

  Future<void> _verifyBookingId() async {
    if (_busy) return;

    final bookingId = _bookingIdController.text.trim();
    if (bookingId.isEmpty) {
      _showSnack('Please enter booking ID', isError: true);
      return;
    }

    setState(() {
      _verifyingBookingId = true;
      _lastCheckInResult = null;
    });

    try {
      final repo = ref.read(ownerRepositoryProvider);
      final result = await repo.verifyBookingId(
        bookingId: bookingId,
        fieldId: widget.fieldId,
      );

      if (!mounted) return;

      if (_isAlreadyCheckedIn(result)) {
        _showSnack('Booking already checked-in ❌', isError: true);
        return;
      }

      _showSnack(
        result.message.trim().isNotEmpty
            ? result.message
            : 'Check-in successful ✅',
      );

      _clearInputs(keepBookingId: true);
      await _showSuccessDialog(result);
      await _refreshAfterSuccess();
    } catch (e) {
      if (!mounted) return;
      _showMappedError(e);
    } finally {
      if (mounted) {
        setState(() => _verifyingBookingId = false);
      }
    }
  }

  Future<void> _validateQrToken() async {
    if (_busy) return;

    final qrToken = _qrTokenController.text.trim();
    if (qrToken.isEmpty) {
      _showSnack('Please enter QR token', isError: true);
      return;
    }

    setState(() {
      _verifyingQr = true;
      _lastCheckInResult = null;
    });

    try {
      final repo = ref.read(ownerRepositoryProvider);
      final result = await repo.validateQrToken(
        qrToken: qrToken,
        fieldId: widget.fieldId,
      );

      if (!mounted) return;

      _showSnack(
        result.message.trim().isNotEmpty
            ? result.message
            : 'Check-in successful ✅',
      );

      _clearInputs(keepQrToken: true);
      await _showSuccessDialog(result);
      await _refreshAfterSuccess();
    } catch (e) {
      if (!mounted) return;
      _showMappedError(e);
    } finally {
      if (mounted) {
        setState(() => _verifyingQr = false);
      }
    }
  }

  Future<void> _validateQrTokenFromScanner(String qrToken) async {
    if (_busy) return;

    final token = qrToken.trim();
    if (token.isEmpty) return;

    if (_lastScannedToken == token) return;
    _lastScannedToken = token;

    setState(() {
      _scannerProcessing = true;
      _lastCheckInResult = null;
    });

    try {
      await _scannerController?.stop();

      _qrTokenController.text = token;

      final repo = ref.read(ownerRepositoryProvider);
      final result = await repo.validateQrToken(
        qrToken: token,
        fieldId: widget.fieldId,
      );

      if (!mounted) return;

      setState(() => _lastCheckInResult = result);

      await _closeScannerSheetIfOpen();

      if (!mounted) return;

      _showSnack(
        result.message.trim().isNotEmpty
            ? result.message
            : 'Check-in successful ✅',
      );

      _clearInputs(keepQrToken: true);

      await _showSuccessDialog(result);
      await _refreshAfterSuccess();
    } catch (e) {
      if (!mounted) return;

      setState(() => _lastCheckInResult = null);
      await _closeScannerSheetIfOpen();

      if (!mounted) return;
      final msg = _extractErrorMessage(e);
      await _showErrorDialog(msg);
    } finally {
      if (mounted) {
        setState(() => _scannerProcessing = false);
      }
    }
  }

  Future<void> _openScanner() async {
    if (_busy || _scannerOpen) return;

    _lastScannedToken = null;
    _scannerController?.dispose();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    setState(() {
      _scannerOpen = true;
      _scannerProcessing = false;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.black,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController!,
                    onDetect: (capture) async {
                      if (_scannerProcessing) return;

                      for (final barcode in capture.barcodes) {
                        final raw = barcode.rawValue?.trim() ?? '';
                        if (raw.isNotEmpty) {
                          await _scannerController?.stop();
                          _validateQrTokenFromScanner(raw);
                          break;
                        }
                      }
                    },
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'Point the camera at the player QR code',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            await _scannerController?.toggleTorch();
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.flash_on),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_scannerProcessing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() {
        _scannerOpen = false;
        _scannerProcessing = false;
      });
    }

    await _scannerController?.dispose();
    _scannerController = null;
  }

  Future<void> _closeScannerSheetIfOpen() async {
    if (!_scannerOpen || !mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  void _clearInputs({
    bool keepBookingId = false,
    bool keepQrToken = false,
  }) {
    if (!keepBookingId) {
      _bookingIdController.clear();
    }
    if (!keepQrToken) {
      _qrTokenController.clear();
    }
  }

  bool _isAlreadyCheckedIn(OwnerCheckInResult result) {
    final status = result.data.status.trim().toUpperCase();
    return status == 'CHECKED_IN' || status == 'USED';
  }

  String _extractErrorMessage(Object e) {
    final text = e.toString().replaceFirst('Exception: ', '').trim();
    if (text.isNotEmpty) return text;
    return 'Check-in failed';
  }

  void _showMappedError(Object e) {
    final msg = _extractErrorMessage(e);
    final lower = msg.toLowerCase();

    if (lower.contains('used') ||
        lower.contains('already checked') ||
        lower.contains('already used') ||
        lower.contains('checked-in')) {
      _showSnack(
        'QR already used / booking already checked-in ❌',
        isError: true,
      );
      return;
    }

    if (lower.contains('expired') || lower.contains('expire')) {
      _showSnack('QR expired ⏰', isError: true);
      return;
    }

    if (lower.contains('invalid') ||
        lower.contains('not found') ||
        lower.contains('qr token is required')) {
      _showSnack('Invalid QR ❌', isError: true);
      return;
    }

    _showSnack(msg, isError: true);
  }

  void _showSnack(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _showSuccessDialog(OwnerCheckInResult result) async {
    final data = _lastCheckInResult?.data ?? result.data;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check-in Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking ID: ${data.bookingId}'),
            const SizedBox(height: 8),
            Text('Status: ${data.status}'),
            const SizedBox(height: 8),
            Text('Player: ${data.playerName.isEmpty ? '—' : data.playerName}'),
            const SizedBox(height: 8),
            Text('Field: ${data.fieldName.isEmpty ? '—' : data.fieldName}'),
            if (data.scheduledStartTime != null &&
                data.scheduledEndTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Time: ${_formatTime(data.scheduledStartTime!)} - ${_formatTime(data.scheduledEndTime!)}',
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Check-in Failed'),
        content: Text(message.isEmpty ? 'Invalid QR' : message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = (widget.fieldName?.trim().isNotEmpty ?? false)
        ? 'Check-in • ${widget.fieldName!.trim()}'
        : 'QR Check-in';

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
        actions: [
          IconButton(
            tooltip: 'Back to bookings',
            onPressed: _busy ? null : () => context.safePop(fallback: '/owner'),
            icon: const Icon(Icons.list_alt_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'QR Check-in',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.fieldName?.trim().isNotEmpty == true
                        ? 'Scan player QR or use manual verification for ${widget.fieldName}.'
                        : 'Scan player QR or use manual verification.',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _openScanner,
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                      label: const Text('Scan QR with Camera'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manual Check-in by Booking ID',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bookingIdController,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Booking ID',
                      hintText: 'Enter booking ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    text: 'Verify by Booking ID',
                    icon: Icons.verified_outlined,
                    enabled: !_busy,
                    onPressed: _verifyBookingId,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manual Check-in by QR Token',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _qrTokenController,
                    enabled: !_busy,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'QR Token',
                      hintText: 'Paste QR token here',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    text: 'Validate QR Token',
                    icon: Icons.qr_code_2_outlined,
                    enabled: !_busy,
                    onPressed: _validateQrToken,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}