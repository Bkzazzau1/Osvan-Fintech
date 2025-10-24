class TimeseriesPoint {
  final double y;
  final DateTime? t; // optional timestamp

  TimeseriesPoint({required this.y, this.t});

  factory TimeseriesPoint.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    DateTime? toDate(dynamic v) {
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {}
      }
      return null;
    }

    return TimeseriesPoint(
      y: toDouble(json['y']),
      t: toDate(json['t']),
    );
  }
}

/// We’ll support either a single series or a grouped map in ONE model.
/// Exactly one of [series] or [grouped] will be non-null.
class TimeseriesResponse {
  final String metric;
  final String interval;
  final List<TimeseriesPoint>? series;
  final Map<String, List<TimeseriesPoint>>? grouped;

  TimeseriesResponse({
    required this.metric,
    required this.interval,
    this.series,
    this.grouped,
  });

  factory TimeseriesResponse.fromJson(Map<String, dynamic> json) {
    final metric = (json['metric'] ?? '').toString();
    final interval = (json['interval'] ?? '').toString();

    if (json['series'] is List) {
      final list = (json['series'] as List)
          .map((e) => TimeseriesPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return TimeseriesResponse(
          metric: metric, interval: interval, series: list);
    }

    if (json['grouped'] is Map) {
      final g = <String, List<TimeseriesPoint>>{};
      (json['grouped'] as Map).forEach((k, v) {
        final points = (v as List)
            .map((e) => TimeseriesPoint.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        g[k.toString()] = points;
      });
      return TimeseriesResponse(metric: metric, interval: interval, grouped: g);
    }

    // fallback to empty single series
    return TimeseriesResponse(
        metric: metric, interval: interval, series: const []);
  }
}
