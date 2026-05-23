class AdminPlatformWalletModel {
  final String id;
  final double balance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminPlatformWalletModel({
    required this.id,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminPlatformWalletModel.fromJson(Map<String, dynamic> json) {
    return AdminPlatformWalletModel(
      id: (json['id'] ?? '').toString(),
      balance: _toDouble(json['balance']) ?? 0.0,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class AdminPlatformWalletSummaryCountsModel {
  final int deposits;
  final int refunds;
  final int withdrawals;
  final int adjustments;

  const AdminPlatformWalletSummaryCountsModel({
    required this.deposits,
    required this.refunds,
    required this.withdrawals,
    required this.adjustments,
  });

  factory AdminPlatformWalletSummaryCountsModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminPlatformWalletSummaryCountsModel(
      deposits: _toInt(json['deposits']),
      refunds: _toInt(json['refunds']),
      withdrawals: _toInt(json['withdrawals']),
      adjustments: _toInt(json['adjustments']),
    );
  }
}

class AdminPlatformWalletSummaryModel {
  final double currentBalance;
  final double totalCollected;
  final double totalRefunded;
  final double totalWithdrawn;
  final double totalAdjustments;
  final double netFlow;
  final double totalRefundLiability;
  final AdminPlatformWalletSummaryCountsModel counts;

  const AdminPlatformWalletSummaryModel({
    required this.currentBalance,
    required this.totalCollected,
    required this.totalRefunded,
    required this.totalWithdrawn,
    required this.totalAdjustments,
    required this.netFlow,
    required this.totalRefundLiability,
    required this.counts,
  });

  factory AdminPlatformWalletSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['counts'];
    final counts = rawCounts is Map
        ? AdminPlatformWalletSummaryCountsModel.fromJson(
            Map<String, dynamic>.from(rawCounts),
          )
        : const AdminPlatformWalletSummaryCountsModel(
            deposits: 0,
            refunds: 0,
            withdrawals: 0,
            adjustments: 0,
          );

    return AdminPlatformWalletSummaryModel(
      currentBalance: _toDouble(json['currentBalance']) ?? 0.0,
      totalCollected: _toDouble(json['totalCollected']) ?? 0.0,
      totalRefunded: _toDouble(json['totalRefunded']) ?? 0.0,
      totalWithdrawn: _toDouble(json['totalWithdrawn']) ?? 0.0,
      totalAdjustments: _toDouble(json['totalAdjustments']) ?? 0.0,
      netFlow: _toDouble(json['netFlow']) ?? 0.0,
      totalRefundLiability: _toDouble(json['totalRefundLiability']) ?? 0.0,
      counts: counts,
    );
  }
}

class AdminPlatformWalletTransactionModel {
  final String id;
  final String type;
  final double amount;
  final double? balanceBefore;
  final double? balanceAfter;
  final String? bookingId;
  final String? reference;
  final String? description;
  final DateTime createdAt;
  final String? payoutMethod;
  final Map<String, dynamic>? payoutDetails;

  const AdminPlatformWalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.bookingId,
    required this.reference,
    required this.description,
    required this.createdAt,
    required this.payoutMethod,
    required this.payoutDetails,
  });

  bool get isIncoming {
    return type == 'BOOKING_DEPOSIT' || type == 'MANUAL_ADJUSTMENT';
  }

  bool get isOutgoing {
    return type == 'BOOKING_REFUND' || type == 'ADMIN_WITHDRAWAL';
  }

  factory AdminPlatformWalletTransactionModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawPayoutDetails = json['payoutDetails'];
    final parsedPayoutDetails = rawPayoutDetails is Map
        ? Map<String, dynamic>.from(rawPayoutDetails)
        : null;

    return AdminPlatformWalletTransactionModel(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString().trim().toUpperCase(),
      amount: _toDouble(json['amount']) ?? 0.0,
      balanceBefore: _toDouble(json['balanceBefore']),
      balanceAfter: _toDouble(json['balanceAfter']),
      bookingId: json['bookingId']?.toString(),
      reference: json['reference']?.toString(),
      description: json['description']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      payoutMethod: json['payoutMethod']?.toString().trim().toUpperCase(),
      payoutDetails: parsedPayoutDetails,
    );
  }
}

class AdminPlatformWalletPaginationModel {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const AdminPlatformWalletPaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  factory AdminPlatformWalletPaginationModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminPlatformWalletPaginationModel(
      page: _toInt(json['page']),
      limit: _toInt(json['limit']),
      total: _toInt(json['total']),
      totalPages: _toInt(json['totalPages']),
    );
  }
}

class AdminPlatformWalletTransactionsResult {
  final List<AdminPlatformWalletTransactionModel> transactions;
  final AdminPlatformWalletPaginationModel pagination;

  const AdminPlatformWalletTransactionsResult({
    required this.transactions,
    required this.pagination,
  });
}

class AdminPlatformWithdrawalResult {
  final String id;
  final String type;
  final double amount;
  final double? balanceBefore;
  final double? balanceAfter;
  final String? payoutMethod;
  final Map<String, dynamic>? payoutDetails;
  final String? reference;
  final String? description;
  final DateTime? createdAt;

  const AdminPlatformWithdrawalResult({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.payoutMethod,
    required this.payoutDetails,
    required this.reference,
    required this.description,
    required this.createdAt,
  });

  factory AdminPlatformWithdrawalResult.fromJson(Map<String, dynamic> json) {
    final rawPayoutDetails = json['payoutDetails'];
    final parsedPayoutDetails = rawPayoutDetails is Map
        ? Map<String, dynamic>.from(rawPayoutDetails)
        : null;

    return AdminPlatformWithdrawalResult(
      id: (json['id'] ?? json['transactionId'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      amount: _toDouble(json['amount']) ?? 0.0,
      balanceBefore: _toDouble(json['balanceBefore']),
      balanceAfter: _toDouble(json['balanceAfter']),
      payoutMethod: json['payoutMethod']?.toString().trim().toUpperCase(),
      payoutDetails: parsedPayoutDetails,
      reference: json['reference']?.toString(),
      description: json['description']?.toString(),
      createdAt: json['createdAt'] == null
          ? null
          : _parseDate(json['createdAt']),
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}

DateTime _parseDate(dynamic raw) {
  final parsed = DateTime.tryParse((raw ?? '').toString());
  if (parsed == null) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return parsed;
}