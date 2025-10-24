class Reliability {
  final int p50Ms;
  final int p95Ms;
  final int p99Ms;
  final int reqCount;
  final double errorRate;

  Reliability({
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.reqCount,
    required this.errorRate,
  });

  factory Reliability.fromJson(Map<String, dynamic> json) {
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

    return Reliability(
      p50Ms: toInt(json['p50_ms']),
      p95Ms: toInt(json['p95_ms']),
      p99Ms: toInt(json['p99_ms']),
      reqCount: toInt(json['req_count']),
      errorRate: toDouble(json['error_rate']),
    );
  }
}
