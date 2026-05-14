import 'package:dio/dio.dart';
import 'package:football/core/network/api_client.dart';
import 'package:football/core/network/backend_error_text.dart';

import '../models/admin_platform_wallet_model.dart';

class AdminPlatformWalletRepository {
  AdminPlatformWalletRepository(this._api);

  final ApiClient _api;

  String _extractErrorMessage(dynamic raw) {
    if (raw is Map) {
      final body = Map<String, dynamic>.from(raw);

      final error = body['error'];
      if (error is Map) {
        final msg = error['message'];

        if (msg is Map) {
          final ar = msg['ar']?.toString().trim();
          final en = msg['en']?.toString().trim();

          if (ar != null && ar.isNotEmpty) return ar;
          if (en != null && en.isNotEmpty) return en;
        }

        final plainMsg = error['message']?.toString().trim();
        if (plainMsg != null && plainMsg.isNotEmpty) {
          return humanizeBackendErrorText(plainMsg);
        }

        final code = error['code']?.toString().trim();
        if (code != null && code.isNotEmpty) {
          return humanizeBackendErrorText(code);
        }
      }

      final message = body['message'];

      if (message is List && message.isNotEmpty) {
        final joined = message.map((e) => e.toString()).join('\n').trim();
        if (joined.isNotEmpty) return joined;
      }

      if (message is Map) {
        final ar = message['ar']?.toString().trim();
        final en = message['en']?.toString().trim();

        if (ar != null && ar.isNotEmpty) return ar;
        if (en != null && en.isNotEmpty) return en;
      }

      final plain = body['message']?.toString().trim();
      if (plain != null && plain.isNotEmpty) {
        return humanizeBackendErrorText(plain);
      }
    }

    if (raw is String && raw.trim().isNotEmpty) {
      return humanizeBackendErrorText(raw.trim());
    }

    return 'Request failed';
  }

  String? _normalizeType(String? value) {
    final v = value?.trim().toUpperCase();

    const allowed = {
      'BOOKING_DEPOSIT',
      'BOOKING_REFUND',
      'ADMIN_WITHDRAWAL',
      'MANUAL_ADJUSTMENT',
    };

    if (v == null || v.isEmpty) return null;
    return allowed.contains(v) ? v : null;
  }

  String? _normalizePayoutMethod(String? value) {
    final v = value?.trim().toUpperCase();

    const allowed = {'MOBILE_WALLET', 'INSTAPAY'};

    if (v == null || v.isEmpty) return null;
    return allowed.contains(v) ? v : null;
  }

  String? _normalizeWalletProvider(String? value) {
    final v = value?.trim().toUpperCase();

    const allowed = {'VODAFONE', 'ORANGE', 'ETISALAT', 'WE'};

    if (v == null || v.isEmpty) return null;
    return allowed.contains(v) ? v : null;
  }

  Future<AdminPlatformWalletModel> getWallet() async {
    try {
      final res = await _api.get(
        'admin/platform-wallet',
        options: Options(validateStatus: (s) => s != null && s < 600),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid platform wallet response');
      }

      final body = Map<String, dynamic>.from(raw);

      if (res.statusCode != null && res.statusCode! >= 400) {
        throw Exception(_extractErrorMessage(body));
      }

      if (body['success'] != true) {
        throw Exception(_extractErrorMessage(body));
      }

      final data = body['data'];
      if (data is! Map) {
        throw Exception('Invalid platform wallet data');
      }

      return AdminPlatformWalletModel.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map) {
        throw Exception(_extractErrorMessage(raw));
      }
      throw Exception(formatDioFailure(e));
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<AdminPlatformWalletSummaryModel> getSummary() async {
    try {
      final res = await _api.get(
        'admin/platform-wallet/summary',
        options: Options(validateStatus: (s) => s != null && s < 600),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid platform wallet summary response');
      }

      final body = Map<String, dynamic>.from(raw);

      if (res.statusCode != null && res.statusCode! >= 400) {
        throw Exception(_extractErrorMessage(body));
      }

      if (body['success'] != true) {
        throw Exception(_extractErrorMessage(body));
      }

      final data = body['data'];
      if (data is! Map) {
        throw Exception('Invalid platform wallet summary data');
      }

      return AdminPlatformWalletSummaryModel.fromJson(
        Map<String, dynamic>.from(data),
      );
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map) {
        throw Exception(_extractErrorMessage(raw));
      }
      throw Exception(formatDioFailure(e));
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<AdminPlatformWalletTransactionsResult> getTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    String? bookingId,
  }) async {
    try {
      final normalizedType = _normalizeType(type);

      final res = await _api.get(
        'admin/platform-wallet/transactions',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (normalizedType != null) 'type': normalizedType,
          if (bookingId != null && bookingId.trim().isNotEmpty)
            'bookingId': bookingId.trim(),
        },
        options: Options(validateStatus: (s) => s != null && s < 600),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid platform transactions response');
      }

      final body = Map<String, dynamic>.from(raw);

      if (res.statusCode != null && res.statusCode! >= 400) {
        throw Exception(_extractErrorMessage(body));
      }

      if (body['success'] != true) {
        throw Exception(_extractErrorMessage(body));
      }

      final data = body['data'];
      if (data is! Map) {
        return const AdminPlatformWalletTransactionsResult(
          transactions: [],
          pagination: AdminPlatformWalletPaginationModel(
            page: 1,
            limit: 20,
            total: 0,
            totalPages: 1,
          ),
        );
      }

      final txNode = data['transactions'];
      final paginationNode = data['pagination'];

      final List<AdminPlatformWalletTransactionModel> transactions;

      if (txNode is List) {
        transactions = txNode
            .whereType<Map>()
            .map(
              (e) => AdminPlatformWalletTransactionModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList();

        transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        transactions = <AdminPlatformWalletTransactionModel>[];
      }

      final pagination = paginationNode is Map
          ? AdminPlatformWalletPaginationModel.fromJson(
              Map<String, dynamic>.from(paginationNode),
            )
          : const AdminPlatformWalletPaginationModel(
              page: 1,
              limit: 20,
              total: 0,
              totalPages: 1,
            );

      return AdminPlatformWalletTransactionsResult(
        transactions: transactions,
        pagination: pagination,
      );
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map) {
        throw Exception(_extractErrorMessage(raw));
      }
      throw Exception(formatDioFailure(e));
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<AdminPlatformWithdrawalResult> withdraw({
    required double amount,
    String? description,
    String? reference,
    required String payoutMethod,
    String? phoneNumber,
    String? walletProvider,
    String? accountDetails,
    required String accountHolderName,
  }) async {
    try {
      final normalizedMethod = _normalizePayoutMethod(payoutMethod);
      if (normalizedMethod == null) {
        throw Exception('Invalid payout method');
      }

      final payload = <String, dynamic>{
        'amount': amount,
        'payoutMethod': normalizedMethod,
        'accountHolderName': accountHolderName.trim(),
      };

      if (description != null && description.trim().isNotEmpty) {
        payload['description'] = description.trim();
      }

      if (reference != null && reference.trim().isNotEmpty) {
        payload['reference'] = reference.trim();
      }

      if (normalizedMethod == 'MOBILE_WALLET') {
        final normalizedProvider = _normalizeWalletProvider(walletProvider);

        payload['phoneNumber'] = phoneNumber?.trim();
        payload['walletProvider'] = normalizedProvider;
      }

      if (normalizedMethod == 'INSTAPAY') {
        payload['accountDetails'] = accountDetails?.trim();
      }

      final res = await _api.post(
        'admin/platform-wallet/withdraw',
        data: payload,
        options: Options(validateStatus: (s) => s != null && s < 600),
      );

      final raw = res.data;
      if (raw is! Map) {
        throw Exception('Invalid platform withdrawal response');
      }

      final body = Map<String, dynamic>.from(raw);

      if (res.statusCode != null && res.statusCode! >= 400) {
        throw Exception(_extractErrorMessage(body));
      }

      if (body['success'] != true) {
        throw Exception(_extractErrorMessage(body));
      }

      final data = body['data'];
      if (data is! Map) {
        throw Exception('Invalid platform withdrawal data');
      }

      return AdminPlatformWithdrawalResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map) {
        throw Exception(_extractErrorMessage(raw));
      }
      throw Exception(formatDioFailure(e));
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
