import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'payment_accounts';

  Future<void> _loadAccounts() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (kDebugMode) {
        debugPrint('[PAYMENT_ACCOUNTS] Loading from Firestore...');
      }

      final snapshot = await _firestore.collection(_collection).get();
      
      if (kDebugMode) {
        debugPrint('[PAYMENT_ACCOUNTS] Found ${snapshot.docs.length} documents');
      }
      
      if (snapshot.docs.isEmpty) {
        // Create default accounts if none exist
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

        if (kDebugMode) {
          debugPrint('[PAYMENT_ACCOUNTS] Creating default accounts...');
        }

        // Save defaults to Firestore
        for (var entry in defaultAccounts.entries) {
          await _firestore
              .collection(_collection)
              .doc(entry.key)
              .set(entry.value.toJson());
        }

        state = state.copyWith(accounts: defaultAccounts, isLoading: false);
      } else {
        final Map<String, PaymentAccountModel> accounts = {};
        
        for (var doc in snapshot.docs) {
          if (kDebugMode) {
            debugPrint('[PAYMENT_ACCOUNTS] Loading doc: ${doc.id}');
          }
          accounts[doc.id] = PaymentAccountModel.fromJson(doc.data());
        }

        state = state.copyWith(accounts: accounts, isLoading: false);
      }
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
        debugPrint('[PAYMENT_ACCOUNTS] Saving ${account.gateway}...');
      }

      await _firestore
          .collection(_collection)
          .doc(account.gateway)
          .set(account.toJson());

      final updatedAccounts = Map<String, PaymentAccountModel>.from(state.accounts);
      updatedAccounts[account.gateway] = account;

      state = state.copyWith(accounts: updatedAccounts, isSaving: false);
      
      if (kDebugMode) {
        debugPrint('[PAYMENT_ACCOUNTS] Saved successfully');
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
