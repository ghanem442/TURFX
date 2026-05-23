import 'package:football/core/errors/api_exception.dart';
import 'package:football/core/network/api_client.dart';

class WalletRepository {
  final ApiClient api;

  WalletRepository(this.api);

  Future<WalletModel> getWallet() async {
    try {
      final res = await api.get('wallet');

      final root = _asMap(res.data);
      if (root == null) {
        throw ApiException(message: 'Invalid wallet response: expected JSON object');
      }

      if (root['success'] == false) {
        throw ApiException(message: _extractMessage(root));
      }

      final data = _asMap(root['data']) ?? <String, dynamic>{};
      return WalletModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  Future<WalletTransactionsResult> getTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final normalizedType = _normalizeType(type);

      final res = await api.get(
        'wallet/transactions',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (normalizedType != null) 'type': normalizedType,
          if (startDate != null) 'startDate': startDate.toIso8601String(),
          if (endDate != null) 'endDate': endDate.toIso8601String(),
        },
      );

      final root = _asMap(res.data);
      if (root == null) {
        throw ApiException(
          message: 'Invalid transactions response: expected JSON object',
        );
      }

      if (root['success'] == false) {
        throw ApiException(message: _extractMessage(root));
      }

      final data = _asMap(root['data']) ?? <String, dynamic>{};

      final rawTx = (data['transactions'] is List)
          ? data['transactions'] as List
          : const [];

      final rawPagination = (data['pagination'] is Map)
          ? data['pagination'] as Map
          : const <String, dynamic>{};

      final tx = rawTx
          .whereType<Map>()
          .map(
            (e) => WalletTransactionModel.fromJson(
              _asMap(e) ?? <String, dynamic>{},
            ),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final pagination = WalletPaginationModel.fromJson(
        _asMap(rawPagination) ?? <String, dynamic>{},
      );

      return WalletTransactionsResult(
        transactions: tx,
        pagination: pagination,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: e.toString());
    }
  }

  String? _normalizeType(String? type) {
    final value = type?.trim().toUpperCase();
    if (value == null || value.isEmpty || value == 'ALL') {
      return null;
    }
    return value;
  }
}

class WalletModel {
  final String id;
  final double balance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WalletModel({
    required this.id,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  double get balanceAsDouble => balance;

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: (json['id'] ?? '').toString(),
      balance: _asDouble(json['balance']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class WalletTransactionModel {
  final String id;
  final String type;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? reference;
  final String description;
  final DateTime createdAt;
  final String? status;

  /// UI helper
  final bool isPendingLocal;

  const WalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.reference,
    required this.description,
    required this.createdAt,
    required this.status,
    this.isPendingLocal = false,
  });

  double get amountAsDouble => amount;

  bool get isIncoming =>
      type == 'CREDIT' || type == 'DEPOSIT' || type == 'REFUND';

  bool get isOutgoing =>
      type == 'DEBIT' ||
      type == 'WITHDRAWAL' ||
      type == 'BOOKING_PAYMENT' ||
      type == 'PAYOUT' ||
      type == 'COMMISSION_DEDUCTION';

  bool get hasReference => (reference ?? '').trim().isNotEmpty;

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? '').toString().trim().toUpperCase();

    return WalletTransactionModel(
      id: (json['id'] ?? '').toString(),
      type: rawType,
      amount: _asDouble(json['amount']),
      balanceBefore: _asDouble(json['balanceBefore']),
      balanceAfter: _asDouble(json['balanceAfter']),
      reference: json['reference']?.toString(),
      description: (json['description'] ?? '').toString(),
      createdAt: _parseDate(json['createdAt']),
      status: json['status']?.toString(),
    );
  }

  WalletTransactionModel copyWith({bool? isPendingLocal}) {
    return WalletTransactionModel(
      id: id,
      type: type,
      amount: amount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      reference: reference,
      description: description,
      createdAt: createdAt,
      status: status,
      isPendingLocal: isPendingLocal ?? this.isPendingLocal,
    );
  }
}

class WalletPaginationModel {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const WalletPaginationModel({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  factory WalletPaginationModel.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;

    return WalletPaginationModel(
      total: asInt(json['total']),
      page: asInt(json['page']),
      limit: asInt(json['limit']),
      totalPages: asInt(json['totalPages']),
    );
  }
}

class WalletTransactionsResult {
  final List<WalletTransactionModel> transactions;
  final WalletPaginationModel pagination;

  const WalletTransactionsResult({
    required this.transactions,
    required this.pagination,
  });
}

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map) return raw.cast<String, dynamic>();
  return null;
}

double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

DateTime _parseDate(dynamic raw) {
  final parsed = DateTime.tryParse((raw ?? '').toString());
  if (parsed == null) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return parsed;
}

String _extractMessage(Map<String, dynamic> root) {
  final error = root['error'];

  if (error is Map) {
    final msg = error['message'];

    if (msg is Map) {
      final ar = msg['ar']?.toString();
      final en = msg['en']?.toString();
      if (ar != null && ar.trim().isNotEmpty) return ar;
      if (en != null && en.trim().isNotEmpty) return en;
    }

    if (msg is String && msg.trim().isNotEmpty) return msg;

    final code = error['code']?.toString();
    if (code != null && code.trim().isNotEmpty) return code;
  }

  final m = root['message'];
  if (m is String && m.trim().isNotEmpty) return m;

  return 'Request failed';
}