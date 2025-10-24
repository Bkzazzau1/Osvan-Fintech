class Wallet {
  final int id;
  final String currencyCode; // e.g. "NGN", "USD"
  final double balance; // backend sends "50000.00" as string

  const Wallet({
    required this.id,
    required this.currencyCode,
    required this.balance,
  });

  factory Wallet.fromJson(Map<String, dynamic> j) {
    return Wallet(
      id: (j['id'] as num).toInt(),
      currencyCode: (j['currency_code'] ?? '') as String,
      balance: double.tryParse(j['balance']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'currency_code': currencyCode,
        'balance': balance.toStringAsFixed(2),
      };
}
