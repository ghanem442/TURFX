class TimeSlotFieldInfo {
  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? averageRating;

  const TimeSlotFieldInfo({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.averageRating,
  });

  factory TimeSlotFieldInfo.fromJson(Map<String, dynamic> json) {
    double? asNullableDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return TimeSlotFieldInfo(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      latitude: asNullableDouble(json['latitude']),
      longitude: asNullableDouble(json['longitude']),
      averageRating: asNullableDouble(json['averageRating']),
    );
  }
}

class TimeSlotModel {
  final String id;
  final String fieldId;
  final DateTime date;
  final DateTime start;
  final DateTime end;
  final String price;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final TimeSlotFieldInfo? field;

  const TimeSlotModel({
    required this.id,
    required this.fieldId,
    required this.date,
    required this.start,
    required this.end,
    required this.price,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.field,
  });

  bool get isAvailable => status.toUpperCase() == 'AVAILABLE';

  double get priceAsDouble => double.tryParse(price) ?? 0.0;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static DateTime? _parseDateTimeOrTime(dynamic value, DateTime baseDate) {
    if (value == null) return null;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final fullDateTime = DateTime.tryParse(text);
    if (fullDateTime != null) {
      return fullDateTime;
    }

    final normalized = text.replaceAll('.', ':');
    final parts = normalized.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final second = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      hour,
      minute,
      second,
    );
  }

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    final parsedDate = _parseDate(json['date']);
    final fallbackBaseDate =
        parsedDate ?? DateTime.now();

    final parsedStartTime =
        _parseDateTimeOrTime(json['startTime'], fallbackBaseDate);

    final parsedEndTime =
        _parseDateTimeOrTime(json['endTime'], fallbackBaseDate);

    final baseDate = parsedDate ??
        parsedStartTime ??
        parsedEndTime ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final normalizedDate = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
    );

    final start = DateTime(
      normalizedDate.year,
      normalizedDate.month,
      normalizedDate.day,
      parsedStartTime?.hour ?? 0,
      parsedStartTime?.minute ?? 0,
      parsedStartTime?.second ?? 0,
    );

    var end = DateTime(
      normalizedDate.year,
      normalizedDate.month,
      normalizedDate.day,
      parsedEndTime?.hour ?? 0,
      parsedEndTime?.minute ?? 0,
      parsedEndTime?.second ?? 0,
    );

    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    return TimeSlotModel(
      id: (json['id'] ?? '').toString(),
      fieldId: (json['fieldId'] ?? '').toString(),
      date: normalizedDate,
      start: start,
      end: end,
      price: (json['price'] ?? '0').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'].toString()),
      field: json['field'] is Map<String, dynamic>
          ? TimeSlotFieldInfo.fromJson(json['field'] as Map<String, dynamic>)
          : (json['field'] is Map
              ? TimeSlotFieldInfo.fromJson(
                  Map<String, dynamic>.from(json['field'] as Map),
                )
              : null),
    );
  }
}