import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/admin_platform_wallet_model.dart';
import '../../data/providers/admin_platform_wallet_repository_provider.dart';

class AdminPlatformWalletState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSubmittingWithdrawal;
  final String? error;
  final AdminPlatformWalletModel? wallet;
  final AdminPlatformWalletSummaryModel? summary;
  final List<AdminPlatformWalletTransactionModel> transactions;
  final AdminPlatformWalletPaginationModel pagination;
  final String? type;
  final String bookingId;

  const AdminPlatformWalletState({
    required this.isLoading,
    required this.isLoadingMore,
    required this.isSubmittingWithdrawal,
    required this.error,
    required this.wallet,
    required this.summary,
    required this.transactions,
    required this.pagination,
    required this.type,
    required this.bookingId,
  });

  factory AdminPlatformWalletState.initial() {
    return const AdminPlatformWalletState(
      isLoading: false,
      isLoadingMore: false,
      isSubmittingWithdrawal: false,
      error: null,
      wallet: null,
      summary: null,
      transactions: [],
      pagination: AdminPlatformWalletPaginationModel(
        page: 1,
        limit: 20,
        total: 0,
        totalPages: 1,
      ),
      type: null,
      bookingId: '',
    );
  }

  AdminPlatformWalletState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSubmittingWithdrawal,
    String? error,
    bool clearError = false,
    AdminPlatformWalletModel? wallet,
    AdminPlatformWalletSummaryModel? summary,
    List<AdminPlatformWalletTransactionModel>? transactions,
    AdminPlatformWalletPaginationModel? pagination,
    String? type,
    bool clearType = false,
    String? bookingId,
  }) {
    return AdminPlatformWalletState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSubmittingWithdrawal:
          isSubmittingWithdrawal ?? this.isSubmittingWithdrawal,
      error: clearError ? null : (error ?? this.error),
      wallet: wallet ?? this.wallet,
      summary: summary ?? this.summary,
      transactions: transactions ?? this.transactions,
      pagination: pagination ?? this.pagination,
      type: clearType ? null : (type ?? this.type),
      bookingId: bookingId ?? this.bookingId,
    );
  }

  bool get hasFilters => type != null || bookingId.trim().isNotEmpty;
}

class AdminPlatformWalletNotifier extends Notifier<AdminPlatformWalletState> {
  @override
  AdminPlatformWalletState build() {
    Future.microtask(refresh);
    return AdminPlatformWalletState.initial();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repo = ref.read(adminPlatformWalletRepositoryProvider);

      final walletFuture = repo.getWallet();
      final summaryFuture = repo.getSummary();
      final txFuture = repo.getTransactions(
        page: 1,
        limit: state.pagination.limit,
        type: state.type,
        bookingId: state.bookingId.trim().isEmpty ? null : state.bookingId.trim(),
      );

      final results = await Future.wait([
        walletFuture,
        summaryFuture,
        txFuture,
      ]);

      final wallet = results[0] as AdminPlatformWalletModel;
      final summary = results[1] as AdminPlatformWalletSummaryModel;
      final result = results[2] as AdminPlatformWalletTransactionsResult;

      state = state.copyWith(
        isLoading: false,
        wallet: wallet,
        summary: summary,
        transactions: result.transactions,
        pagination: result.pagination,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.pagination.hasMore) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final repo = ref.read(adminPlatformWalletRepositoryProvider);

      final nextPage = state.pagination.page + 1;

      final result = await repo.getTransactions(
        page: nextPage,
        limit: state.pagination.limit,
        type: state.type,
        bookingId: state.bookingId.trim().isEmpty ? null : state.bookingId.trim(),
      );

      final merged = <String, AdminPlatformWalletTransactionModel>{
        for (final item in state.transactions) item.id: item,
        for (final item in result.transactions) item.id: item,
      }.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        isLoadingMore: false,
        transactions: merged,
        pagination: result.pagination,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> setType(String? value) async {
    state = value == null
        ? state.copyWith(clearType: true)
        : state.copyWith(type: value);
    await refresh();
  }

  Future<void> setBookingId(String value) async {
    state = state.copyWith(bookingId: value);
    await refresh();
  }

  Future<void> clearFilters() async {
    state = state.copyWith(
      clearType: true,
      bookingId: '',
    );
    await refresh();
  }

  Future<String> withdraw({
    required double amount,
    String? description,
    String? reference,
    required String payoutMethod,
    String? phoneNumber,
    String? walletProvider,
    String? accountDetails,
    required String accountHolderName,
  }) async {
    state = state.copyWith(
      isSubmittingWithdrawal: true,
      clearError: true,
    );

    try {
      final repo = ref.read(adminPlatformWalletRepositoryProvider);

      await repo.withdraw(
        amount: amount,
        description: description,
        reference: reference,
        payoutMethod: payoutMethod,
        phoneNumber: phoneNumber,
        walletProvider: walletProvider,
        accountDetails: accountDetails,
        accountHolderName: accountHolderName,
      );

      state = state.copyWith(isSubmittingWithdrawal: false);
      await refresh();

      return 'Withdrawal processed successfully';
    } catch (e) {
      state = state.copyWith(
        isSubmittingWithdrawal: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }
}

final adminPlatformWalletProvider =
    NotifierProvider<AdminPlatformWalletNotifier, AdminPlatformWalletState>(
      AdminPlatformWalletNotifier.new,
    );