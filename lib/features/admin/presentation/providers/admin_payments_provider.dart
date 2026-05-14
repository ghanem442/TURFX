import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/admin_payment_model.dart';
import '../../data/providers/admin_payments_repository_provider.dart';

class AdminPaymentsState {
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final List<AdminPaymentModel> payments;
  final String? paymentMethod;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? activePaymentId;

  const AdminPaymentsState({
    required this.isLoading,
    required this.isSubmitting,
    required this.error,
    required this.payments,
    required this.paymentMethod,
    required this.startDate,
    required this.endDate,
    required this.activePaymentId,
  });

  factory AdminPaymentsState.initial() {
    return const AdminPaymentsState(
      isLoading: false,
      isSubmitting: false,
      error: null,
      payments: [],
      paymentMethod: null,
      startDate: null,
      endDate: null,
      activePaymentId: null,
    );
  }

  AdminPaymentsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    List<AdminPaymentModel>? payments,
    String? paymentMethod,
    bool clearPaymentMethod = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    String? activePaymentId,
    bool clearActivePaymentId = false,
  }) {
    return AdminPaymentsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      payments: payments ?? this.payments,
      paymentMethod:
          clearPaymentMethod ? null : (paymentMethod ?? this.paymentMethod),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      activePaymentId: clearActivePaymentId
          ? null
          : (activePaymentId ?? this.activePaymentId),
    );
  }

  bool get hasFilters =>
      paymentMethod != null || startDate != null || endDate != null;
}

class AdminPaymentsNotifier extends Notifier<AdminPaymentsState> {
  @override
  AdminPaymentsState build() {
    Future.microtask(loadPendingPayments);
    return AdminPaymentsState.initial();
  }

  Future<void> loadPendingPayments() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repo = ref.read(adminPaymentsRepositoryProvider);

      final payments = await repo.getPendingPayments(
        paymentMethod: state.paymentMethod,
        startDate: state.startDate,
        endDate: state.endDate,
      );

      state = state.copyWith(
        isLoading: false,
        payments: payments,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> setPaymentMethod(String? value) async {
    state = value == null
        ? state.copyWith(clearPaymentMethod: true)
        : state.copyWith(paymentMethod: value);
    await loadPendingPayments();
  }

  Future<void> setDateRange({
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    state = state.copyWith(
      startDate: startDate,
      endDate: endDate,
    );
    await loadPendingPayments();
  }

  Future<void> clearFilters() async {
    state = state.copyWith(
      clearPaymentMethod: true,
      clearStartDate: true,
      clearEndDate: true,
    );
    await loadPendingPayments();
  }

  Future<void> approve(String paymentId) async {
    state = state.copyWith(
      isSubmitting: true,
      activePaymentId: paymentId,
      clearError: true,
    );

    try {
      final repo = ref.read(adminPaymentsRepositoryProvider);
      await repo.approvePayment(paymentId: paymentId);

      final updated = state.payments.where((e) => e.id != paymentId).toList();

      state = state.copyWith(
        isSubmitting: false,
        payments: updated,
        clearActivePaymentId: true,
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst('Exception: ', ''),
        clearActivePaymentId: true,
      );
      rethrow;
    }
  }

  Future<void> reject({
    required String paymentId,
    required String reason,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      activePaymentId: paymentId,
      clearError: true,
    );

    try {
      final repo = ref.read(adminPaymentsRepositoryProvider);
      await repo.rejectPayment(
        paymentId: paymentId,
        reason: reason,
      );

      final updated = state.payments.where((e) => e.id != paymentId).toList();

      state = state.copyWith(
        isSubmitting: false,
        payments: updated,
        clearActivePaymentId: true,
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst('Exception: ', ''),
        clearActivePaymentId: true,
      );
      rethrow;
    }
  }

  Future<void> refresh() async {
    await loadPendingPayments();
  }
}

final adminPaymentsProvider =
    NotifierProvider<AdminPaymentsNotifier, AdminPaymentsState>(
  AdminPaymentsNotifier.new,
);