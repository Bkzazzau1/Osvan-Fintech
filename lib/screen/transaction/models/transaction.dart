import 'package:flutter/foundation.dart';

/// Unified transaction model (Flutter side) — tolerant to both fiat & crypto payloads.
@immutable
class Txn {
  final String id;

  /// Normalized: "debit" | "credit" | "transaction"
  final String type;

  /// Major units (e.g., 1200.50). If backend sends minor units, we convert.
  final double amount;

  /// ISO code or ticker (e.g., "NGN", "USD", "USDT")
  final String currency;

  /// Parsed from ISO8601 (created_at/createdAt/timestamp) or best-effort date+time.
  final DateTime createdAt;

  /// Optional description/memo/narration from backend
  final String? narration;

  const Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.createdAt,
    this.narration,
  });

  /// Tolerant factory that accepts multiple backend shapes (merged fiat+crypto).
  factory Txn.fromJson(Map<String, dynamic> j) {
    // id
    final id = (j['id'] ?? j['pk'] ?? '').toString();

    // type normalization
    final rawType = (j['type'] ??
            j['direction'] ?? // debit|credit
            j['action'] ?? // send|receive
            j['kind'] ?? // sometimes 'wallet'|'crypto'
            'transaction')
        .toString()
        .toLowerCase();

    final type = _normalizeType(rawType);

    // amount (prefer major; fallback to minor/100)
    final amount = _parseAmount(
      major: j['amount'] ?? j['amount_major'],
      minor: j['amount_minor'],
    );

    // currency (fiat code or crypto ticker)
    final currency = (j['currency'] ??
            j['currency_code'] ??
            j['ticker'] ??
            j['fiat_currency'] ??
            '')
        .toString();

    // createdAt (ISO candidates or date+time)
    final createdAt = _parseCreatedAt(
      j['created_at'],
      j['createdAt'],
      j['timestamp'],
      j['created'],
      j['date'],
      j['time'],
    );

    // narration/description
    final narration =
        (j['narration'] ?? j['description'] ?? j['memo'])?.toString().trim();

    return Txn(
      id: id,
      type: type,
      amount: amount,
      currency: currency,
      createdAt: createdAt,
      narration: (narration?.isEmpty ?? true) ? null : narration,
    );
  }

  static String _normalizeType(String t) {
    // Map common variants into debit/credit
    if (t == 'out' || t == 'debit' || t == 'send' || t == 'withdraw') {
      return 'debit';
    }
    if (t == 'in' ||
        t == 'credit' ||
        t == 'receive' ||
        t == 'deposit' ||
        t == 'topup' ||
        t == 'fund') {
      return 'credit';
    }
    return t.isEmpty ? 'transaction' : t;
  }

  static double _parseAmount({dynamic major, dynamic minor}) {
    // Prefer major units
    final m = _toDoubleOrNull(major);
    if (m != null) return m;

    // Fallback to minor units (assume 2dp)
    final mi = _toDoubleOrNull(minor);
    if (mi != null) return mi / 100.0;

    return 0.0;
  }

  static DateTime _parseCreatedAt(
    dynamic createdAt,
    dynamic createdAtAlt,
    dynamic timestamp,
    dynamic created,
    dynamic dateOnly,
    dynamic timeOnly,
  ) {
    // Try ISO-like fields first
    final candidates = [
      createdAt,
      createdAtAlt,
      timestamp,
      created,
    ].where((e) => e != null).map((e) => e.toString());

    for (final s in candidates) {
      final dt = DateTime.tryParse(s);
      if (dt != null) return dt;
    }

    // Try date + time (e.g., '2025-09-30' + '06:15 PM' or '18:15')
    final d = (dateOnly ?? '').toString();
    final t = (timeOnly ?? '').toString();
    if (d.isNotEmpty && t.isNotEmpty) {
      final dt = _tryParseDateTimeCombos(d, t);
      if (dt != null) return dt;
    }

    // Try date only
    if (d.isNotEmpty) {
      final dt = DateTime.tryParse(d);
      if (dt != null) return dt;
    }

    // Fallback
    return DateTime.now();
  }

  static DateTime? _tryParseDateTimeCombos(String d, String t) {
    // "YYYY-MM-DD HH:MM AM/PM"
    final parts = t.trim().split(' ');
    if (parts.length == 2) {
      final hm = parts[0];
      final ampm = parts[1].toUpperCase();
      final tt = hm.split(':');
      if (tt.length == 2) {
        var hour = int.tryParse(tt[0]) ?? 0;
        final minute = int.tryParse(tt[1]) ?? 0;
        if (ampm == 'PM' && hour < 12) hour += 12;
        if (ampm == 'AM' && hour == 12) hour = 0;
        final base = DateTime.tryParse(d);
        if (base != null) {
          return DateTime(base.year, base.month, base.day, hour, minute);
        }
      }
    }
    // "YYYY-MM-DD HH:MM" 24-hour
    final tt = t.split(':');
    if (tt.length >= 2) {
      final hour = int.tryParse(tt[0]) ?? 0;
      final minute = int.tryParse(tt[1]) ?? 0;
      final base = DateTime.tryParse(d);
      if (base != null) {
        return DateTime(base.year, base.month, base.day, hour, minute);
      }
    }
    return null;
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // ignore: unused_element
  static double _toDouble(dynamic v) => _toDoubleOrNull(v) ?? 0.0;

  Txn copyWith({
    String? id,
    String? type,
    double? amount,
    String? currency,
    DateTime? createdAt,
    String? narration,
  }) {
    return Txn(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      narration: narration ?? this.narration,
    );
  }

  @override
  String toString() =>
      'Txn(id: $id, type: $type, amount: $amount $currency, at: $createdAt)';
}
