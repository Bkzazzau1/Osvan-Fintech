class Money {
  final double amount;
  final String currency;
  Money({required this.amount, required this.currency});

  factory Money.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return Money(
      amount: toDouble(json['amount']),
      currency: (json['currency'] ?? '').toString(),
    );
  }
}

class SummaryKpis {
  final int newVerifiedUsers;
  final int activeWallets;
  final Money totalVolume;
  final String netRevenue;
  final double kycPassRate;
  final int walletConnectP95Ms;
  final double errors5xxRate;

  SummaryKpis({
    required this.newVerifiedUsers,
    required this.activeWallets,
    required this.totalVolume,
    required this.netRevenue,
    required this.kycPassRate,
    required this.walletConnectP95Ms,
    required this.errors5xxRate,
  });

  factory SummaryKpis.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return SummaryKpis(
      newVerifiedUsers: toInt(json['new_verified_users']),
      activeWallets: toInt(json['active_wallets']),
      totalVolume:
          Money.fromJson(Map<String, dynamic>.from(json['total_volume'] ?? {})),
      netRevenue: (json['net_revenue'] ?? '-').toString(),
      kycPassRate: toDouble(json['kyc_pass_rate']),
      walletConnectP95Ms: toInt(json['wallet_connect_p95_ms']),
      errors5xxRate: toDouble(json['errors_5xx_rate']),
    );
  }
}
