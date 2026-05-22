import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/network/media_url.dart';
import 'package:football/core/routing/app_navigation.dart';
import 'package:football/core/widgets/app_button.dart';
import 'package:football/core/theme/app_theme.dart';
import 'package:football/features/fields/data/models/field_model.dart';
import 'package:football/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/error_utils.dart';
import '../../../../core/errors/api_exception.dart';
import '../providers/booking_providers.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/payment_result_model.dart';
import '../../data/models/payment_verification_status_model.dart';
import '../providers/payment_local_store_provider.dart';

class BookingConfirmationArgs {
  final BookingModel booking;
  final FieldModel? field;

  const BookingConfirmationArgs({required this.booking, this.field});
}

enum ManualPaymentGateway { vodafoneCash, instapay }

extension ManualPaymentGatewayX on ManualPaymentGateway {
  String get apiValue {
    switch (this) {
      case ManualPaymentGateway.vodafoneCash:
        return 'vodafone_cash';
      case ManualPaymentGateway.instapay:
        return 'instapay';
    }
  }

  String get label {
    switch (this) {
      case ManualPaymentGateway.vodafoneCash:
        return 'Vodafone Cash';
      case ManualPaymentGateway.instapay:
        return 'InstaPay';
    }
  }

  String get labelAr {
    switch (this) {
      case ManualPaymentGateway.vodafoneCash:
        return 'فودافون كاش';
      case ManualPaymentGateway.instapay:
        return 'إنستا باي';
    }
  }
}

class BookingConfirmationPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? args;

  const BookingConfirmationPage({super.key, this.args});

  @override
  ConsumerState<BookingConfirmationPage> createState() =>
      _BookingConfirmationPageState();
}

class _BookingConfirmationPageState
    extends ConsumerState<BookingConfirmationPage>
    with WidgetsBindingObserver {
  // ─── Timers ───────────────────────────────────────────────────────────────
  Timer? _timer;
  Timer? _paymentPollTimer;

  // ─── Countdown ───────────────────────────────────────────────────────────
  Duration? _remaining;

  /// الـ deadline الأخير اللي اتحسب منه الـ countdown
  /// بنحتفظ بيه عشان نتجنب restart مكرر لو نفس الـ deadline
  DateTime? _lastDeadline;

  // ─── Loading flags ────────────────────────────────────────────────────────
  int _pollCount = 0;
  bool _paying = false;
  bool _cancelling = false;
  bool _refreshingAfterPayment = false;
  bool _uploadingScreenshot = false;
  bool _refreshingVerificationStatus = false;
  bool _restoringStoredPayment = false;

  // ─── Payment state ────────────────────────────────────────────────────────
  ManualPaymentGateway? _selectedGateway = ManualPaymentGateway.vodafoneCash;
  PaymentResultModel? _paymentResult;
  PaymentVerificationStatusModel? _verificationStatus;
  File? _selectedScreenshotFile;
  double? _uploadProgress;

  // ─── Text controllers ─────────────────────────────────────────────────────
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _transactionIdController =
      TextEditingController();
  final TextEditingController _senderNumberController = TextEditingController();

  // ─── Static queries list ──────────────────────────────────────────────────
  static const _allBookingsQueries = [
    MyBookingsQuery(page: 1, limit: 20),
    MyBookingsQuery(category: 'upcoming', page: 1, limit: 20),
    MyBookingsQuery(category: 'cancelled', page: 1, limit: 20),
    MyBookingsQuery(category: 'played', page: 1, limit: 20),
    MyBookingsQuery(category: 'expired', page: 1, limit: 20),
    MyBookingsQuery(status: 'CONFIRMED', page: 1, limit: 20),
    MyBookingsQuery(status: 'PENDING_PAYMENT', page: 1, limit: 20),
    MyBookingsQuery(status: 'CHECKED_IN', page: 1, limit: 20),
    MyBookingsQuery(status: 'CANCELLED_REFUNDED', page: 1, limit: 20),
    MyBookingsQuery(status: 'CANCELLED_NO_REFUND', page: 1, limit: 20),
    MyBookingsQuery(status: 'PLAYED', page: 1, limit: 20),
    MyBookingsQuery(status: 'EXPIRED_NO_SHOW', page: 1, limit: 20),
    MyBookingsQuery(status: 'PAYMENT_FAILED', page: 1, limit: 20),
  ];

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreStoredPaymentState();
    });
  }

  @override
  void didUpdateWidget(covariant BookingConfirmationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.args?['bookingId']?.toString();
    final newId = widget.args?['bookingId']?.toString();
    // لو الـ bookingId اتغير، نعيد ضبط الـ countdown
    if (oldId != newId) {
      _lastDeadline = null;
      _stopCountdown();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _paymentResult != null &&
        _paymentResult!.paymentId.trim().isNotEmpty) {
      _refreshVerificationStatus(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCountdown();
    _stopPaymentStatusPolling();
    _notesController.dispose();
    _transactionIdController.dispose();
    _senderNumberController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Countdown helpers
  // ──────────────────────────────────────────────────────────────────────────

  void _stopCountdown() {
    _timer?.cancel();
    _timer = null;
  }

  /// يشغّل الـ countdown بس لو الـ deadline اتغير فعلاً.
  /// ده بيمنع إعادة إنشاء الـ Timer في كل rebuild.
  void _maybeStartCountdown(DateTime? deadline) {
    if (deadline == null) {
      if (_remaining != null) {
        _stopCountdown();
        if (mounted) setState(() => _remaining = null);
      }
      return;
    }

    // نفس الـ deadline — مش محتاجين نعمل حاجة
    if (_lastDeadline == deadline) return;

    _lastDeadline = deadline;
    _stopCountdown();

    void tick() {
      if (!mounted) return;
      final diff = deadline.difference(DateTime.now());
      setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Payment polling
  // ──────────────────────────────────────────────────────────────────────────

  static const int _maxPolls = 20;
  static const int _defaultPollingIntervalSeconds = 10;

  void _startPaymentStatusPolling() {
    _stopPaymentStatusPolling();
    _pollCount = 0;
    _paymentPollTimer = Timer.periodic(
      const Duration(seconds: _defaultPollingIntervalSeconds),
      (_) async {
        if (!mounted) return;
        if (_paymentResult == null ||
            _paymentResult!.paymentId.trim().isEmpty) {
          return;
        }

        _pollCount++;
        if (_pollCount >= _maxPolls) {
          _stopPaymentStatusPolling();
          if (mounted) _showPaymentExpired();
          return;
        }

        try {
          await _refreshVerificationStatus(
            silent: true,
            refreshBooking: false,
          );

          if (!mounted) return;

          final status =
              _verificationStatus?.verificationStatus.toUpperCase() ?? '';
          if (status == 'APPROVED' ||
              status == 'REJECTED' ||
              status == 'EXPIRED') {
            _stopPaymentStatusPolling();
            await _refreshBookingAfterPaymentStatus(silent: true);
          }
        } catch (e) {
          if (!mounted) return;
          final msg = e.toString().toLowerCase();
          if (msg.contains('401') || msg.contains('unauthorized')) {
            _stopPaymentStatusPolling();
            return;
          }
          // Handle 429 Too Many Requests
          if (msg.contains('429') || msg.contains('too many requests')) {
            await _handle429Response(e);
          }
        }
      },
    );
  }

  Future<void> _handle429Response(Object error) async {
    // Try to extract retryAfter from the error
    int retryAfterSeconds = _defaultPollingIntervalSeconds;
    
    // Check if it's our custom TooManyRequestsException
    if (error is TooManyRequestsException) {
      retryAfterSeconds = error.retryAfter;
    } else {
      // Fallback: try to parse retryAfter from error message
      try {
        final errorStr = error.toString();
        final retryAfterMatch = RegExp(r'retryAfter[:\s]+(\d+)').firstMatch(errorStr);
        if (retryAfterMatch != null) {
          retryAfterSeconds = int.tryParse(retryAfterMatch.group(1) ?? '') ?? _defaultPollingIntervalSeconds;
        }
      } catch (_) {
        // If parsing fails, use default
      }
    }

    if (kDebugMode) {
      debugPrint('[PAYMENT_POLLING] 429 received, waiting $retryAfterSeconds seconds before retry');
    }

    // Stop current polling timer
    _stopPaymentStatusPolling();
    
    // Wait for the specified retry period
    await Future.delayed(Duration(seconds: retryAfterSeconds));
    
    // Restart polling if still mounted and payment session is active
    if (mounted && _paymentResult != null && _paymentResult!.paymentId.trim().isNotEmpty) {
      _startPaymentStatusPolling();
    }
  }

  void _showPaymentExpired() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'انتهت مهلة مراجعة الدفع. يمكنك تحديث الحالة يدويًا أو بدء عملية دفع جديدة.',
          ),
        ),
      );
  }

  void _stopPaymentStatusPolling() {
    _paymentPollTimer?.cancel();
    _paymentPollTimer = null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Local storage helpers
  // ──────────────────────────────────────────────────────────────────────────

  String? get _bookingId => widget.args?['bookingId']?.toString();

  Future<void> _savePaymentIdLocally({
    required String bookingId,
    required String paymentId,
  }) async {
    await ref
        .read(paymentLocalStoreProvider)
        .savePaymentId(bookingId: bookingId, paymentId: paymentId);
  }

  Future<String?> _readStoredPaymentId(String bookingId) async {
    return ref
        .read(paymentLocalStoreProvider)
        .getPaymentId(bookingId: bookingId);
  }

  Future<void> _clearStoredPaymentId(String bookingId) async {
    await ref
        .read(paymentLocalStoreProvider)
        .clearPaymentId(bookingId: bookingId);
  }

  Future<void> _restoreStoredPaymentState() async {
    final bookingId = _bookingId;
    if (bookingId == null || bookingId.trim().isEmpty) return;
    if (_restoringStoredPayment) return;

    setState(() => _restoringStoredPayment = true);

    try {
      final paymentId = await _readStoredPaymentId(bookingId);
      if (!mounted || paymentId == null || paymentId.trim().isEmpty) return;

      setState(() {
        _paymentResult = PaymentResultModel(
          success: true,
          data: PaymentDataModel(
            paymentId: paymentId,
            bookingId: bookingId,
            amount: '',
            currency: '',
            gateway: '',
            paymentType: '',
            referenceCode: '',
            paymentExpiresAt: null,
            expiryMinutes: 0,
            instructions: const {},
            accountDetails: const {},
            nextStep: const {},
          ),
          error: null,
          message: null,
          status: null,
          raw: const {},
        );
      });

      await _refreshVerificationStatus(silent: true);
      _startPaymentStatusPolling();
    } finally {
      if (mounted) setState(() => _restoringStoredPayment = false);
    }
  }

  void _invalidateAllBookings() {
    for (final query in _allBookingsQueries) {
      ref.invalidate(myBookingsProvider(query));
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Error helper
  // ──────────────────────────────────────────────────────────────────────────

  String _errorMessageAr(Object e) {
    const fallback = 'حدث خطأ، حاول مرة أخرى';
    if (e is PaymentResultModel) return e.userMessageAr;

    final text = e.toString().replaceFirst('Exception: ', '').trim();
    final lower = text.toLowerCase();

    if (lower.contains('toomanyrequests') ||
        lower.contains('too many requests') ||
        text == 'common.tooManyRequests') {
      return 'طلبات كثيرة جدًا. يرجى الانتظار قليلاً ثم المحاولة مرة أخرى.';
    }

    return text.isEmpty ? fallback : text;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // File picker
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _pickScreenshotFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
      );

      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null || path.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر قراءة الملف المختار')),
        );
        return;
      }

      setState(() => _selectedScreenshotFile = File(path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorMessageAr(e))));
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Payment actions
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _startManualPayment(BookingModel booking) async {
    if (_paying) return;

    final gateway = _selectedGateway;
    if (gateway == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر وسيلة الدفع أولًا')),
      );
      return;
    }

    setState(() => _paying = true);

    try {
      final result = await ref.read(
        initiateDepositPaymentProvider(
          ManualPaymentInitParams(
            bookingId: booking.id,
            gateway: gateway.apiValue,
          ),
        ).future,
      );

      if (!mounted) return;

      if (!result.isSuccess || result.data == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(result.userMessageAr)));
        return;
      }

      setState(() {
        _paymentResult = result;
        _verificationStatus = null;
        _selectedScreenshotFile = null;
        _notesController.clear();
        _transactionIdController.clear();
        _senderNumberController.clear();
      });

      await _savePaymentIdLocally(
        bookingId: booking.id,
        paymentId: result.paymentId,
      );

      _startPaymentStatusPolling();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'تم إنشاء طلب الدفع. حوّل المبلغ ثم ارفع لقطة الشاشة',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_errorMessageAr(e))));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _uploadScreenshot() async {
    final payment = _paymentResult;
    if (payment == null || payment.paymentId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ابدأ عملية الدفع أولًا')),
      );
      return;
    }

    if (_selectedScreenshotFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر لقطة شاشة أو PDF أولًا')),
      );
      return;
    }

    if (_uploadingScreenshot) return;

    setState(() {
      _uploadingScreenshot = true;
      _uploadProgress = 0;
    });

    try {
      final repo = ref.read(bookingsRepositoryProvider);
      final result = await repo.uploadPaymentScreenshot(
        paymentId: payment.paymentId,
        screenshotFile: _selectedScreenshotFile!,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        transactionId: _transactionIdController.text.trim().isEmpty
            ? null
            : _transactionIdController.text.trim(),
        senderNumber: _senderNumberController.text.trim().isEmpty
            ? null
            : _senderNumberController.text.trim(),
        onProgress: (sent, total) {
          if (mounted && total > 0) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.messageAr.trim().isNotEmpty
                  ? result.messageAr
                  : 'تم رفع لقطة الشاشة بنجاح',
            ),
          ),
        );

      await _refreshVerificationStatus();
      _startPaymentStatusPolling();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_errorMessageAr(e))));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingScreenshot = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _refreshVerificationStatus({
    bool silent = false,
    bool refreshBooking = true,
  }) async {
    final payment = _paymentResult;
    if (payment == null || payment.paymentId.trim().isEmpty) return;
    if (_refreshingVerificationStatus) return;

    setState(() => _refreshingVerificationStatus = true);

    try {
      ref.invalidate(paymentVerificationStatusProvider(payment.paymentId));
      final status = await ref.read(
        paymentVerificationStatusProvider(payment.paymentId).future,
      );

      if (!mounted) return;
      setState(() => _verificationStatus = status);

      if (refreshBooking) {
        await _refreshBookingAfterPaymentStatus(silent: silent);
      }
    } catch (e) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorMessageAr(e))));
    } finally {
      if (mounted) setState(() => _refreshingVerificationStatus = false);
    }
  }

  Future<void> _refreshBookingAfterPaymentStatus({bool silent = false}) async {
    final bookingId = widget.args?['bookingId']?.toString();
    if (_refreshingAfterPayment || !mounted || bookingId == null) return;

    setState(() => _refreshingAfterPayment = true);

    try {
      ref.invalidate(bookingByIdProvider(bookingId));
      ref.invalidate(bookingQrProvider(bookingId));
      _invalidateAllBookings();

      final updated =
          await ref.refresh(bookingByIdProvider(bookingId).future);

      if (!mounted) return;

      final bookingStatus = updated.statusUpper;
      final verificationStatus =
          _verificationStatus?.verificationStatus.toUpperCase() ?? '';

      final shouldClearStoredPayment = bookingStatus == 'CONFIRMED' ||
          bookingStatus == 'PAYMENT_FAILED' ||
          verificationStatus == 'APPROVED' ||
          verificationStatus == 'REJECTED' ||
          verificationStatus == 'EXPIRED';

      if (shouldClearStoredPayment) {
        await _clearStoredPaymentId(bookingId);
        if (mounted &&
            (verificationStatus == 'REJECTED' ||
                verificationStatus == 'EXPIRED' ||
                bookingStatus == 'PAYMENT_FAILED')) {
          _resetLocalPaymentDraftUi();
        }
      }

      if (!mounted) return;

      if (verificationStatus == 'REJECTED' ||
          verificationStatus == 'EXPIRED' ||
          bookingStatus == 'PAYMENT_FAILED') {
        _stopPaymentStatusPolling();
      }

      if (bookingStatus == 'CONFIRMED') {
        _stopPaymentStatusPolling();
        await ref.read(walletProvider.notifier).refreshWallet();
        ref.invalidate(bookingQrProvider(bookingId));

        if (!mounted || silent) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'تم قبول الدفع وتأكيد الحجز — يمكنك عرض الـ QR الآن',
              ),
            ),
          );
      } else if (!silent) {
        _showVerificationSnackbar(verificationStatus, bookingStatus);
      }
    } catch (_) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث حالة الحجز')),
      );
    } finally {
      if (mounted) setState(() => _refreshingAfterPayment = false);
    }
  }

  void _showVerificationSnackbar(
      String verificationStatus, String bookingStatus) {
    String? message;

    if (verificationStatus == 'PENDING' || verificationStatus == 'LOCKED') {
      message = 'تم رفع الإثبات والحالة الآن قيد المراجعة';
    } else if (verificationStatus == 'REJECTED') {
      final reason = _verificationStatus?.rejectionReason?.trim() ?? '';
      message = reason.isNotEmpty
          ? 'تم رفض الدفع: $reason'
          : 'تم رفض إثبات الدفع لهذه العملية';
    } else if (verificationStatus == 'EXPIRED') {
      message = 'انتهت مهلة عملية الدفع الحالية';
    } else if (bookingStatus == 'PAYMENT_FAILED') {
      message =
          'فشل الدفع أو انتهت المهلة. يمكنك إنشاء عملية دفع جديدة إذا ظل الحجز متاحًا';
    }

    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmAndCancel(BookingModel booking) async {
    if (_cancelling) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الحجز؟'),
        content: const Text(
          'هل أنت متأكد أنك تريد إلغاء هذا الحجز؟\n\n'
          'لو الحجز مستحق للاسترداد، سيتم إضافة الرصيد للمحفظة تلقائيًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _cancelling = true);

    try {
      final res = await ref
          .read(cancelBookingProvider.notifier)
          .cancel(CancelBookingParams(
            bookingId: booking.id,
            reason: 'Cancelled by player',
          ));

      await _clearStoredPaymentId(booking.id);

      if (!mounted) return;

      _resetLocalPaymentDraftUi();
      ref.invalidate(bookingByIdProvider(booking.id));
      ref.invalidate(bookingQrProvider(booking.id));
      _invalidateAllBookings();
      await ref.read(walletProvider.notifier).refreshWallet();

      if (!mounted) return;

      final refund = res.refund;
      final msg = (res.messageAr?.trim().isNotEmpty == true)
          ? res.messageAr!.trim()
          : 'تم إلغاء الحجز';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '$msg\nالاسترداد: ${refund.percentage}% (${_formatMoney(refund.amount)} EGP)',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_errorMessageAr(e))));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _resetLocalPaymentDraftUi() {
    setState(() {
      _paymentResult = null;
      _verificationStatus = null;
      _selectedScreenshotFile = null;
      _notesController.clear();
      _transactionIdController.clear();
      _senderNumberController.clear();
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final args = widget.args;

    if (args == null) return _missingDataScaffold(context);

    final bookingId = args['bookingId']?.toString() ?? '';
    if (bookingId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Confirmation')),
        body: const Center(child: Text('Invalid booking id')),
      );
    }

    // ✅ FIX: استخدم ref.listen هنا بدل addPostFrameCallback جوا build
    // بيشغّل الـ countdown مرة واحدة بس لما الـ deadline يتغير فعلاً
    ref.listen<AsyncValue<BookingModel>>(
      bookingByIdProvider(bookingId),
      (_, next) {
        next.whenData((booking) {
          _maybeStartCountdown(booking.paymentDeadline);
        });
      },
    );

    final bookingAsync = ref.watch(bookingByIdProvider(bookingId));

    return bookingAsync.when(
      loading: () => _loadingScaffold(context),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Booking Confirmation')),
        body: Center(child: Text('Error: ${extractErrorMessage(e)}')),
      ),
      // ✅ FIX: _buildPage هي method منفصلة مش nested function جوا build()
      data: (booking) => _buildPage(booking, bookingId: bookingId),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // _buildPage  (كانت pageFor — اتنقلت لـ method منفصلة)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPage(BookingModel booking, {required String bookingId}) {
    final statusUpper = booking.statusUpper;
    final qrEligibility = ref.watch(bookingQrEligibilityProvider(booking));

    const cancelledStatuses = {
      'CANCELLED',
      'CANCELLED_REFUNDED',
      'CANCELLED_NO_REFUND',
    };

    final isCancelled = cancelledStatuses.contains(statusUpper);
    final canOpenQrPage = qrEligibility.canShowQr;
    final canShowQrPreview = qrEligibility.canShowQr;

    final payableAmount = booking.depositAsDouble > 0
        ? booking.depositAsDouble
        : booking.totalAsDouble;

    final computedCashAtField =
        booking.totalAsDouble - booking.depositAsDouble;

    final cashAtFieldAmount = booking.remainingAmount.trim().isNotEmpty
        ? booking.remainingAsDouble
        : (computedCashAtField < 0 ? 0.0 : computedCashAtField);

    final qrAsync = canShowQrPreview && !isCancelled
        ? ref.watch(bookingQrProvider(booking.id))
        : null;

    final paymentStatusUpper =
        _verificationStatus?.verificationStatus.toUpperCase() ?? '';

    final hasExistingPaymentSession =
        _paymentResult != null && _paymentResult!.paymentId.trim().isNotEmpty;

    final hasBlockingPaymentSession = hasExistingPaymentSession &&
        paymentStatusUpper != 'REJECTED' &&
        paymentStatusUpper != 'EXPIRED';

    final deadlineOpen = booking.paymentDeadline == null ||
        (_remaining == null || _remaining! > Duration.zero);

    final canPay = !isCancelled &&
        statusUpper == 'PENDING_PAYMENT' &&
        deadlineOpen &&
        !hasBlockingPaymentSession;

    final canUploadProof = !isCancelled &&
        statusUpper == 'PENDING_PAYMENT' &&
        hasExistingPaymentSession &&
        paymentStatusUpper != 'REJECTED' &&
        paymentStatusUpper != 'EXPIRED' &&
        paymentStatusUpper != 'APPROVED';

    final canCancel = !isCancelled &&
        (statusUpper == 'CONFIRMED' || statusUpper == 'PENDING_PAYMENT');

    final fieldName =
        booking.fieldDisplayName != '—' ? booking.fieldDisplayName : '—';

    final manualInfoAsync = _selectedGateway != null
        ? ref.watch(manualPaymentInfoProvider(_selectedGateway!.apiValue))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.safePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/home'),
          ),
          IconButton(
            tooltip: 'My Bookings',
            icon: const Icon(Icons.list_alt),
            onPressed: () => context.go('/my-bookings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Restoring indicator ─────────────────────────────────────
            if (_restoringStoredPayment)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _CardShell(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'جاري استرجاع حالة الدفع السابقة...',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── QR / Status card ────────────────────────────────────────
            _CardShell(
              child: Column(
                children: [
                  if (canShowQrPreview && !isCancelled)
                    qrAsync!.when(
                      loading: () => _qrBoxLoading(),
                      error: (e, _) => _qrBoxError(
                        message: booking.isConfirmed || booking.isCheckedInStatus
                            ? 'حجزك مؤكد، لكن تعذر تحميل الـ QR الآن. حاول مرة أخرى.'
                            : qrEligibility.message,
                        onRetry: () async =>
                            ref.invalidate(bookingQrProvider(booking.id)),
                      ),
                      data: (qr) {
                        final url = qr.imageUrl.trim().isNotEmpty
                            ? qr.imageUrl
                            : (booking.qrImageUrl ?? '');
                        if (url.trim().isEmpty) {
                          return _qrBoxError(
                            message:
                                'تم تأكيد الحجز لكن صورة الـ QR غير متاحة الآن.',
                            onRetry: () async =>
                                ref.invalidate(bookingQrProvider(booking.id)),
                          );
                        }
                        return _qrBoxImage(url);
                      },
                    )
                  else if (isCancelled)
                    _qrBoxCancelled()
                  else
                    _qrBoxPending(message: qrEligibility.message),
                  const SizedBox(height: 14),
                  Text(
                    booking.bookingNumberDisplay,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusBadge(status: booking.status),
                  if (!isCancelled && booking.paymentDeadline != null) ...[
                    const SizedBox(height: 10),
                    _CountdownPill(
                      deadline: booking.paymentDeadline!,
                      remaining: _remaining,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Booking details ─────────────────────────────────────────
            _CardShell(
              child: Column(
                children: [
                  _RowItem(label: 'Field', value: fieldName),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _RowItem(
                    label: 'Date',
                    value: _formatDate(booking.scheduledDate),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _RowItem(
                    label: 'Time',
                    value:
                        '${_formatTime(booking.scheduledStart)} - ${_formatTime(booking.scheduledEnd)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Payment summary ─────────────────────────────────────────
            _CardShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RowItem(
                    label: 'Total Price',
                    value: '${_formatMoney(booking.totalAsDouble)} EGP',
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _RowItem(
                    label: 'Pay Now (Deposit)',
                    value: '${_formatMoney(payableAmount)} EGP',
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _RowItem(
                    label: 'Pay at Field',
                    value: '${_formatMoney(cashAtFieldAmount)} EGP',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.orange
                          .withAlpha((0.08 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.orange
                            .withAlpha((0.20 * 255).round()),
                      ),
                    ),
                    child: Text(
                      statusUpper == 'CONFIRMED'
                          ? 'تم تأكيد الحجز بنجاح. سيظهر الـ QR عند الحاجة حسب حالة الحجز.'
                          : statusUpper == 'PAYMENT_FAILED'
                              ? 'فشل الدفع أو تم رفضه أو انتهت صلاحيته. ستحتاج إلى إنشاء حجز جديد للمحاولة مرة أخرى.'
                              : 'ادفع العربون يدويًا عبر فودافون كاش أو إنستا باي، ثم ارفع لقطة شاشة للتحويل. سيتم مراجعة العملية من الأدمن قبل تأكيد الحجز.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: statusUpper == 'CONFIRMED'
                            ? AppColors.green
                            : statusUpper == 'PAYMENT_FAILED'
                                ? Colors.red
                                : AppColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Saved payment session card ───────────────────────────────
            if (statusUpper == 'PENDING_PAYMENT' && hasExistingPaymentSession)
              ..._buildSavedPaymentSection(booking),

            // ── Gateway selector ────────────────────────────────────────
            if (canPay) ..._buildGatewaySection(booking, manualInfoAsync),

            // ── Payment result details ──────────────────────────────────
            if (_paymentResult != null) ...[
              const SizedBox(height: 16),
              _buildPaymentResultCard(),
            ],

            // ── Upload proof ────────────────────────────────────────────
            if (canUploadProof) ...[
              const SizedBox(height: 16),
              _buildUploadProofCard(),
            ],

            // ── Verification status ─────────────────────────────────────
            if (_verificationStatus != null) ...[
              const SizedBox(height: 16),
              _buildVerificationStatusCard(),
            ],

            // ── Under review indicator ──────────────────────────────────
            if (paymentStatusUpper == 'PENDING' ||
                paymentStatusUpper == 'LOCKED') ...[
              const SizedBox(height: 12),
              const _CardShell(
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'عملية الدفع الآن قيد المراجعة من الأدمن',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Rejected ────────────────────────────────────────────────
            if (paymentStatusUpper == 'REJECTED') ...[
              const SizedBox(height: 12),
              _CardShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تم رفض الدفع',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (_verificationStatus?.rejectionReason ?? '')
                              .trim()
                              .isNotEmpty
                          ? _verificationStatus!.rejectionReason!.trim()
                          : 'تم رفض إثبات الدفع لهذه العملية.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'يمكنك بدء عملية دفع جديدة طالما أن الحجز ما زال في حالة Pending Payment.',
                    ),
                  ],
                ),
              ),
            ],

            // ── Expired ─────────────────────────────────────────────────
            if (paymentStatusUpper == 'EXPIRED') ...[
              const SizedBox(height: 12),
              const _CardShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'انتهت مهلة الدفع',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, color: Colors.red),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'انتهت صلاحية عملية الدفع الحالية. يمكنك بدء عملية جديدة إذا كان الحجز ما زال متاحًا للدفع.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],

            // ── Payment failed ───────────────────────────────────────────
            if (statusUpper == 'PAYMENT_FAILED') ...[
              const SizedBox(height: 12),
              _CardShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الحجز لم يتأكد',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (_verificationStatus?.rejectionReason ?? '')
                              .trim()
                              .isNotEmpty
                          ? 'سبب الرفض: ${_verificationStatus!.rejectionReason!.trim()}'
                          : 'فشل الدفع أو تم رفضه أو انتهت صلاحيته. يلزم إنشاء حجز جديد إذا أردت المحاولة مرة أخرى.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],

            // ── Action buttons ───────────────────────────────────────────
            const SizedBox(height: 20),
            if (canOpenQrPage)
              _PrimaryButton(
                text: booking.qrIsUsed ? 'Show Used QR' : 'Show QR',
                color: AppColors.green,
                onPressed: () =>
                    context.push('/booking/${booking.id}/qr'),
              ),
            if (canCancel)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed:
                      _cancelling ? null : () => _confirmAndCancel(booking),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _cancelling
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Cancel Booking',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            const SizedBox(height: 8),
            _SecondaryButton(
              text: 'Refresh Booking Status',
              loading: _refreshingAfterPayment,
              onPressed: () => _refreshBookingAfterPaymentStatus(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _GhostButton(
                    text: 'Back to My Bookings',
                    onPressed: () => context.go('/my-bookings'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GhostButton(
                    text: 'Go Home',
                    onPressed: () => context.go('/home'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sub-section builders  (منفصلة عشان build() متبقاش ضخمة)
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildSavedPaymentSection(BookingModel booking) {
    return [
      const SizedBox(height: 16),
      _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'عملية دفع محفوظة',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text(
              'تم العثور على عملية دفع محفوظة لهذا الحجز. يمكنك استكمال رفع إثبات التحويل أو متابعة حالة المراجعة.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_verificationStatus == null)
                  OutlinedButton.icon(
                    onPressed: _refreshingVerificationStatus
                        ? null
                        : _refreshVerificationStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث حالة الدفع'),
                  ),
                OutlinedButton.icon(
                  onPressed: _restoringStoredPayment
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await _clearStoredPaymentId(booking.id);
                          if (!mounted) return;
                          _resetLocalPaymentDraftUi();
                          if (!mounted) return;
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تم حذف حالة الدفع المحلية لهذه الشاشة فقط',
                                ),
                              ),
                            );
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('مسح الحالة المحلية'),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildGatewaySection(
      BookingModel booking, AsyncValue? manualInfoAsync) {
    final paymentStatusUpper =
        _verificationStatus?.verificationStatus.toUpperCase() ?? '';
    final hasExistingPaymentSession =
        _paymentResult != null && _paymentResult!.paymentId.trim().isNotEmpty;

    return [
      const SizedBox(height: 16),
      _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر وسيلة الدفع',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 12),
            _GatewaySelector(
              selected: _selectedGateway,
              onChanged: (value) {
                setState(() {
                  _selectedGateway = value;
                  _paymentResult = null;
                  _verificationStatus = null;
                  _selectedScreenshotFile = null;
                  _notesController.clear();
                  _transactionIdController.clear();
                  _senderNumberController.clear();
                });
              },
            ),
            if (manualInfoAsync != null) ...[
              const SizedBox(height: 14),
              manualInfoAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => _InfoBox(
                  icon: Icons.error_outline,
                  text: _errorMessageAr(e),
                  color: Colors.red,
                ),
                data: (info) {
                  if (!info.isAvailable) {
                    return const _InfoBox(
                      icon: Icons.info_outline,
                      text: 'وسيلة الدفع المختارة غير متاحة حاليًا',
                      color: Colors.red,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (info.instructionsAr.trim().isNotEmpty)
                        _InfoBox(
                          icon: Icons.info_outline,
                          text: info.instructionsAr,
                        ),
                      if (info.accountDetails.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _AccountDetailsCard(
                          gateway: info.gateway,
                          accountDetails: info.accountDetails,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 14),
            _PrimaryButton(
              text: hasExistingPaymentSession &&
                      (paymentStatusUpper == 'REJECTED' ||
                          paymentStatusUpper == 'EXPIRED')
                  ? 'ابدأ عملية دفع جديدة'
                  : 'ابدأ الدفع اليدوي',
              color: AppColors.orange,
              loading: _paying,
              onPressed: () => _startManualPayment(booking),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildPaymentResultCard() {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'بيانات التحويل',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _RowItem(label: 'Payment ID', value: _paymentResult!.paymentId),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _RowItem(
            label: 'Reference',
            value: _paymentResult!.referenceCode.isNotEmpty
                ? _paymentResult!.referenceCode
                : (_verificationStatus?.referenceCode.isNotEmpty == true
                    ? _verificationStatus!.referenceCode
                    : '—'),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _RowItem(
            label: 'Gateway',
            value: _paymentResult!.gateway.isNotEmpty
                ? _paymentResult!.gateway
                : (_selectedGateway?.label ?? '—'),
          ),
          if (_paymentResult!.amount.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _RowItem(
              label: 'Amount',
              value:
                  '${_paymentResult!.amount} ${_paymentResult!.currency}',
            ),
          ],
          if (_paymentResult!.paymentExpiresAt != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _RowItem(
              label: 'Expires At',
              value: _formatDateTime(_paymentResult!.paymentExpiresAt!),
            ),
          ],
          if (_paymentResult!.instructionsAr.isNotEmpty) ...[
            const SizedBox(height: 14),
            _InfoBox(
              icon: Icons.info_outline,
              text: _paymentResult!.instructionsAr,
            ),
          ],
          if (_paymentResult!.nextStepAr.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoBox(
              icon: Icons.arrow_forward_rounded,
              text: _paymentResult!.nextStepAr,
            ),
          ],
          if (_paymentResult!.accountDetails.isNotEmpty) ...[
            const SizedBox(height: 14),
            _AccountDetailsCard(
              gateway: _paymentResult!.gateway,
              accountDetails: _paymentResult!.accountDetails,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadProofCard() {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'رفع إثبات التحويل',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _uploadingScreenshot ? null : _pickScreenshotFile,
            icon: const Icon(Icons.attach_file),
            label: Text(
              _selectedScreenshotFile == null
                  ? 'اختر صورة أو PDF'
                  : _selectedScreenshotFile!.path
                      .split(Platform.pathSeparator)
                      .last,
            ),
          ),
          if (_uploadingScreenshot && _uploadProgress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _uploadProgress),
            const SizedBox(height: 4),
            Text(
              '${(_uploadProgress! * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _senderNumberController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم المحول (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transactionIdController,
            decoration: const InputDecoration(
              labelText: 'رقم العملية (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ملاحظات (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          _PrimaryButton(
            text: 'رفع لقطة الشاشة',
            color: AppColors.green,
            loading: _uploadingScreenshot,
            onPressed: _uploadScreenshot,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStatusCard() {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'حالة التحقق',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _VerificationBadge(
              status: _verificationStatus!.verificationStatus),
          const SizedBox(height: 12),
          _RowItem(
              label: 'Reference',
              value: _verificationStatus!.referenceCode),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _RowItem(
            label: 'Submitted At',
            value: _verificationStatus!.submittedAt != null
                ? _formatDateTime(_verificationStatus!.submittedAt!)
                : '—',
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _RowItem(
            label: 'Verification ETA',
            value: _verificationStatus!.estimatedVerificationTime,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _RowItem(
            label: 'Upload Attempts',
            value:
                '${_verificationStatus!.uploadAttempts}/${_verificationStatus!.maxUploadAttempts}',
          ),
          if ((_verificationStatus!.rejectionReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _InfoBox(
              icon: Icons.error_outline,
              text: _verificationStatus!.rejectionReason!.trim(),
              color: Colors.red,
            ),
          ],
          const SizedBox(height: 14),
          _SecondaryButton(
            text: 'تحديث حالة الدفع',
            loading:
                _refreshingVerificationStatus || _refreshingAfterPayment,
            onPressed: _refreshVerificationStatus,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Scaffold helpers
  // ──────────────────────────────────────────────────────────────────────────

  Widget _missingDataScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.safePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Missing booking data',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'We could not load the booking details for this page.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/my-bookings'),
                child: const Text('Go to My Bookings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.safePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // QR box helpers
  // ──────────────────────────────────────────────────────────────────────────

  Widget _qrBoxLoading() {
    return const _QrBox(
        child: Center(child: CircularProgressIndicator()));
  }

  Widget _qrBoxError({required Future<void> Function() onRetry, String? message}) {
    return _QrBox(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, size: 40, color: Colors.orange),
            const SizedBox(height: 8),
            const Text(
              'QR is not available right now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message ??
                  'Your booking may still be confirmed. Please try again later.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppButton(
              text: 'Retry',
              width: 120,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }

  Widget _qrBoxCancelled() {
    return const _QrBox(
      child: Center(
        child: Text(
          'Booking Cancelled',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _qrBoxPending({required String message}) {
    return _QrBox(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  String _resolveQrUrl(String imageUrl) {
    final resolved = resolvePublicMediaUrl(imageUrl);
    if (kDebugMode && imageUrl.trim().isNotEmpty) {
      debugPrint('[QR] raw=$imageUrl -> $resolved');
    }
    return resolved;
  }

  Widget _qrBoxImage(String imageUrl) {
    final resolvedUrl = _resolveQrUrl(imageUrl);
    if (resolvedUrl.isEmpty) return _qrBoxError(onRetry: () async {});

    return _QrBox(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          resolvedUrl,
          height: 190,
          width: 190,
          fit: BoxFit.contain,
          errorBuilder: (_, error, stackTrace) {
            if (kDebugMode) {
              debugPrint('[QR] failed url=$resolvedUrl err=$error');
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_2, size: 48),
                  const SizedBox(height: 8),
                  const Text(
                    'QR image could not be loaded',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    resolvedUrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Stateless UI widgets  (مفيش تغيير عليهم — كما هم)
// ════════════════════════════════════════════════════════════════════════════

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _QrBox extends StatelessWidget {
  final Widget child;
  const _QrBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final Color color;
  final bool loading;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.text,
    required this.color,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(text,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;

  const _SecondaryButton({
    required this.text,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blueGrey,
          side: const BorderSide(color: Colors.blueGrey),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(text,
                style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _GhostButton({required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    final fg = _statusColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fg.withAlpha((0.14 * 255).round()),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(s),
        style:
            TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'CONFIRMED':
      case 'CHECKED_IN':
        return AppColors.green;
      case 'PLAYED':
      case 'COMPLETED':
        return Colors.blue;
      case 'PENDING_PAYMENT':
        return AppColors.orange;
      case 'CANCELLED':
      case 'CANCELLED_REFUNDED':
      case 'CANCELLED_NO_REFUND':
      case 'PAYMENT_FAILED':
      case 'NO_SHOW':
      case 'EXPIRED_NO_SHOW':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'PENDING_PAYMENT':
        return 'Pending Payment';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'PLAYED':
        return 'Played';
      case 'CHECKED_IN':
        return 'Checked In';
      case 'COMPLETED':
        return 'Completed';
      case 'PAYMENT_FAILED':
        return 'Payment Failed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'CANCELLED_REFUNDED':
        return 'Cancelled + Refunded';
      case 'CANCELLED_NO_REFUND':
        return 'Cancelled بدون استرداد';
      case 'NO_SHOW':
        return 'No Show';
      case 'EXPIRED_NO_SHOW':
        return 'Expired / No Show';
      default:
        return s;
    }
  }
}

class _VerificationBadge extends StatelessWidget {
  final String status;
  const _VerificationBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    final fg = _color(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fg.withAlpha((0.14 * 255).round()),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(_label(s),
          style: TextStyle(color: fg, fontWeight: FontWeight.w900)),
    );
  }

  static Color _color(String s) {
    switch (s) {
      case 'APPROVED':
        return AppColors.green;
      case 'PENDING':
      case 'LOCKED':
        return AppColors.orange;
      case 'REJECTED':
      case 'EXPIRED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String _label(String s) {
    switch (s) {
      case 'APPROVED':
        return 'Approved';
      case 'PENDING':
        return 'Pending Review';
      case 'LOCKED':
        return 'Under Review';
      case 'REJECTED':
        return 'Rejected';
      case 'EXPIRED':
        return 'Expired';
      default:
        return s;
    }
  }
}

class _GatewaySelector extends StatelessWidget {
  final ManualPaymentGateway? selected;
  final ValueChanged<ManualPaymentGateway?> onChanged;

  const _GatewaySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ManualPaymentGateway.values.map((gateway) {
        final active = selected == gateway;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onChanged(gateway),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      active ? AppColors.orange : Colors.grey.shade300,
                  width: active ? 1.6 : 1,
                ),
                color: active
                    ? AppColors.orange
                        .withAlpha((0.08 * 255).round())
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    active
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: active ? AppColors.orange : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(gateway.labelAr,
                        style:
                            const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  Text(
                    gateway.label,
                    style: const TextStyle(
                        color: AppColors.subText,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AccountDetailsCard extends StatelessWidget {
  final String gateway;
  final Map<String, dynamic> accountDetails;

  const _AccountDetailsCard({
    required this.gateway,
    required this.accountDetails,
  });

  @override
  Widget build(BuildContext context) {
    final entries = accountDetails.entries
        .where(
            (e) => e.value != null && e.value.toString().trim().isNotEmpty)
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account Details (${gateway.toUpperCase()})',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RowItem(
                  label: _beautifyKey(entry.key),
                  value: entry.value.toString()),
            ),
          ),
        ],
      ),
    );
  }

  static String _beautifyKey(String key) {
    switch (key) {
      case 'accountNumber':
        return 'Account Number';
      case 'accountName':
        return 'Account Name';
      case 'mobileNumber':
        return 'Mobile Number';
      case 'ipn':
        return 'IPN';
      case 'bankAccount':
        return 'Bank Account';
      default:
        return key;
    }
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoBox({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.orange;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: resolvedColor.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: resolvedColor.withAlpha((0.18 * 255).round())),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: resolvedColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: resolvedColor)),
          ),
        ],
      ),
    );
  }
}

class _CountdownPill extends StatelessWidget {
  final DateTime deadline;
  final Duration? remaining;

  const _CountdownPill({required this.deadline, required this.remaining});

  @override
  Widget build(BuildContext context) {
    final rem = remaining ?? deadline.difference(DateTime.now());
    final safe = rem.isNegative ? Duration.zero : rem;

    final hh = safe.inHours.toString().padLeft(2, '0');
    final mm = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = safe.inSeconds.remainder(60).toString().padLeft(2, '0');

    final text = safe == Duration.zero
        ? 'Payment expired'
        : 'Complete payment in $hh:$mm:$ss';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.orange.withAlpha((0.14 * 255).round()),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w900, color: AppColors.orange)),
    );
  }
}

class _RowItem extends StatelessWidget {
  final String label;
  final String value;

  const _RowItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.subText, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value.trim().isEmpty ? '—' : value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Formatting helpers
// ════════════════════════════════════════════════════════════════════════════

String _formatDate(DateTime d) {
  final x = d.toLocal();
  return '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
}

String _formatTime(DateTime d) {
  final x = d.toLocal();
  int h = x.hour;
  final m = x.minute.toString().padLeft(2, '0');
  final ampm = h >= 12 ? 'PM' : 'AM';
  h = h % 12;
  if (h == 0) h = 12;
  return '$h:$m $ampm';
}

String _formatDateTime(DateTime d) => '${_formatDate(d)} ${_formatTime(d)}';

String _formatMoney(double value) {
  if (value == value.truncateToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}