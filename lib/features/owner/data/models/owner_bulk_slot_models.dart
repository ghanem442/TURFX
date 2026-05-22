class BulkTimeRangeItem {
  final String startTime;
  final String endTime;
  final double price;

  const BulkTimeRangeItem({
    required this.startTime,
    required this.endTime,
    required this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'price': price,
    };
  }
}

class BulkCreateTimeSlotsResult {
  final bool success;
  final String? message;
  final int count;
  final int dates;
  final int timeRanges;
  final int skipped; // Number of slots that were skipped (already existed)

  const BulkCreateTimeSlotsResult({
    required this.success,
    required this.message,
    required this.count,
    required this.dates,
    required this.timeRanges,
    this.skipped = 0,
  });

  factory BulkCreateTimeSlotsResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};

    String? resolvedMessage;
    final rawMessage = json['message'];

    if (rawMessage is Map) {
      final ar = rawMessage['ar']?.toString().trim();
      final en = rawMessage['en']?.toString().trim();

      if (ar != null && ar.isNotEmpty) {
        resolvedMessage = ar;
      } else if (en != null && en.isNotEmpty) {
        resolvedMessage = en;
      }
    } else {
      final text = rawMessage?.toString().trim();
      if (text != null && text.isNotEmpty) {
        resolvedMessage = text;
      }
    }

    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return BulkCreateTimeSlotsResult(
      success: json['success'] == true,
      message: resolvedMessage,
      count: asInt(data['count']),
      dates: asInt(data['dates']),
      timeRanges: asInt(data['timeRanges']),
      skipped: asInt(data['skipped']),
    );
  }
}