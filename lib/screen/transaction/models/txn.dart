import 'package:flutter/foundation.dart';

@immutable
class Txn {
  final String id;
  final String type; // e.g., "debit", "credit", "send", "receive"
  final double amount; // major units
  final String currency; // e.g., "NGN", "USD"
  final DateTime createdAt; // ISO 8601 from backend
  final String? narration; // optional

  const Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.createdAt,
    this.narration,
  });

  factory Txn.fromJson(Map<String, dynamic> j) {
    return Txn(
      id: j['id'].toString(),
      type: (j['type'] ?? '').toString(),
      amount: _toDouble(j['amount']),
      currency: (j['currency'] ?? '').toString(),
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
          DateTime.now(),
      narration: j['narration']?.toString(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
