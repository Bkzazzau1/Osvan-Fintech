class Breakdown {
  final List<BreakdownItem> items;
  final String? groupBy;
  final String? metric;
  final int? total;

  Breakdown({
    required this.items,
    this.groupBy,
    this.metric,
    this.total,
  });

  factory Breakdown.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List? ?? [])
        .map((e) => BreakdownItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return Breakdown(
      items: list,
      groupBy: json['group_by'] as String?,
      metric: json['metric'] as String?,
      total: (json['total'] is num) ? (json['total'] as num).toInt() : null,
    );
  }
}

class BreakdownItem {
  final String key;
  final double value;
  final int count;
  final Map<String, dynamic>? extra;

  BreakdownItem({
    required this.key,
    required this.value,
    required this.count,
    this.extra,
  });

  factory BreakdownItem.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int toInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return BreakdownItem(
      key: (json['key'] ?? '').toString(),
      value: toDouble(json['value']),
      count: toInt(json['count']),
      extra: (json['extra'] is Map)
          ? Map<String, dynamic>.from(json['extra'] as Map)
          : null,
    );
  }
}
