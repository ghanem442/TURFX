import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/payment_account_model.dart';

// Global provider to access payment accounts from anywhere
final paymentAccountsProvider =
    StateNotifierProvider<PaymentAccountsNotifier, PaymentAccountsState>((ref) {
  return PaymentAccountsNotifier();
});

// Provider to get a specific account by gateway
final paymentAccountByGatewayProvider = 
    Provider.family<PaymentAccountModel?, String>((ref, gateway) {
  final state = ref.watch(paymentAccountsProvider);
  return state.accounts[gateway.toUpperCase()];
});

class PaymentAccountsState {
  final Map<String, PaymentAccountModel> accounts;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const PaymentAccountsState({
    this.accounts = const {},
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  PaymentAccountsState copyWith({
    Map<String, PaymentAccountModel>? accounts,
    bool? isLoading,
    bool? isSaving,
    String? error,
  }) {
    return PaymentAccountsState(
      accounts: accounts ?? this.accounts,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class PaymentAccountsNotifier extends StateNotifier<PaymentAccountsState> {
  PaymentAccountsNotifier() : super(const PaymentAccountsState()) {
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (kDebugMode) {
        debugPrint('[PAYMENT_ACCOUNTS] Loading default accounts (Firebase removed)...');
      }

      // Return default accounts (Firebase removed)
      final defaultAccounts = {
        'VODAFONE_CASH': const PaymentAccountModel(
          gateway: 'VODAFONE_CASH',
          isEnabled: true,
          mobileNumber: '',
          accountName: '',
          instructionsAr: 'حول المبلغ المطلوب على رقم فودافون كاش الموضح أدناه',
          instructionsEn: 'Transfer the required amount to the Vodafone Cash number below',
        ),
        'INSTAPAY': const PaymentAccountModel(
          gateway: 'INSTAPAY',
          isEnabled: true,
          mobileNumber: '',
          accountName: '',
          instructionsAr: 'حول المبلغ المطلوب على رقم إنستا باي الموضح أدناه',
          instructionsEn: 'Transfer the required amount to the InstaPay number below',
        ),
      };

      state = state.copyWith(accounts: defaultAccounts, isLoading: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PAYMENT_ACCOUNTS] Error: $e');
      }
      
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load payment accounts: ${e.toString()}',
      );
    }
  }

  Future<void> saveAccount(PaymentAccountModel account) async {
    state = state.copyWith(isSaving: true, error: null);

    try {
      if (kDebugMode) {
        debugPrint('[PAYMENT_ACCOUNTS] Saving ${account.gateway} locally (Firebase removed)...');
      }

      // Save to local state only (Firebase removed)
      final updatedAccounts = Map<String, PaymentAccountModel>.from(state.accounts);
      updatedAccounts[account.gateway] = account;

      state = state.copyWith(accounts: updatedAccounts, isSaving: false);
      
      if (kDebugMode) {
        debugPrint('[PAYMENT_ACCOUNTS] Saved successfully (local only)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PAYMENT_ACCOUNTS] Save error: $e');
      }
      
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save account: ${e.toString()}',
      );
      rethrow;
    }
  }

  Future<void> refresh() async {
    await _loadAccounts();
  }
}
