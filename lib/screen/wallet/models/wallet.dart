// lib/screen/wallet/models/wallet.dart
import 'package:flutter/foundation.dart';

@immutable
class Wallet {
  final int id;
  /// e.g. "NGN", "USD"
  final String currencyCode;

  /// Display-safe balance in major units (double for UI).
  /// Parsed from any of: balance | available_balance | ledger_balance.
  final double balance;

  /// Optional friendly label from backend (if any).
  final String? label;

  const Wallet({
    required this.id,
    required this.currencyCode,
    required this.balance,
    this.label,
  });

  /// Robust JSON parser. Accepts:
  /// - id: int | num | String
  /// - currency_code | currency | code
  /// - balance | available_balance | ledger_balance (String/num)
  factory Wallet.fromJson(Map<String, dynamic> j) {
    int parseId(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    String parseCurrency(Map<String, dynamic> m) {
      final c = (m['currency_code'] ?? m['currency'] ?? m['code'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      return c;
    }

    double parseBalance(Map<String, dynamic> m) {
      final raw = m['balance'] ??
          m['available_balance'] ??
          m['available'] ??
          m['ledger_balance'] ??
          m['amount']; // last-resort if API returns {amount: "..."}
      return double.tryParse(raw?.toString() ?? '0') ?? 0.0;
    }

    return Wallet(
      id: parseId(j['id']),
      currencyCode: parseCurrency(j),
      balance: parseBalance(j),
      label: (j['label'] ?? j['name'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'currency_code': currencyCode,
        'balance': balance.toStringAsFixed(2),
        if (label != null) 'label': label,
      };

  Wallet copyWith({
    int? id,
    String? currencyCode,
    double? balance,
    String? label,
  }) =>
      Wallet(
        id: id ?? this.id,
        currencyCode: currencyCode ?? this.currencyCode,
        balance: balance ?? this.balance,
        label: label ?? this.label,
      );

  @override
  String toString() =>
      'Wallet(id: $id, currency: $currencyCode, balance: $balance, label: $label)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wallet &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          currencyCode == other.currencyCode &&
          balance == other.balance &&
          label == other.label;

  @override
  int get hashCode =>
      id.hashCode ^ currencyCode.hashCode ^ balance.hashCode ^ label.hashCode;

  /// Optional: quick currency symbol for UI
  String get symbol {
    switch (currencyCode) {
      case 'NGN':
        return '₦';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'KES':
        return 'KSh';
      case 'UGX':
        return 'USh';
      default:
        return currencyCode; // fallback to code
    }
  }

  /// Optional: formatted “₦12,345.67” for display
  String formatBalance() {
    // lightweight formatting without intl dependency
    final s = balance.toStringAsFixed(2);
    final parts = s.split('.');
    final whole = parts[0];
    final frac = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      final rIndex = whole.length - i;
      buf.write(whole[i]);
      if (rIndex > 1 && rIndex % 3 == 1) buf.write(',');
    }
    return '$symbol${buf.toString()}.$frac';
  }
}
