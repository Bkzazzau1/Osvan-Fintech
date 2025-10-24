class CryptoBalance {
  final String coin; // e.g. USDT, BTC
  final String network; // e.g. TRON, ERC20, BTC
  final double balance;

  CryptoBalance({
    required this.coin,
    required this.network,
    required this.balance,
  });

  factory CryptoBalance.fromJson(Map<String, dynamic> j) => CryptoBalance(
    coin: (j['coin'] ?? '').toString().toUpperCase(),
    network: (j['network'] ?? '').toString().toUpperCase(),
    balance: (j['balance'] is num)
        ? (j['balance'] as num).toDouble()
        : double.tryParse('${j['balance']}') ?? 0.0,
  );
}

class DepositAddress {
  final String coin;
  final String network;
  final String address;
  final String? memo;

  DepositAddress({
    required this.coin,
    required this.network,
    required this.address,
    this.memo,
  });

  factory DepositAddress.fromJson(Map<String, dynamic> j) => DepositAddress(
    coin: (j['coin'] ?? '').toString().toUpperCase(),
    network: (j['network'] ?? '').toString().toUpperCase(),
    address: (j['address'] ?? '').toString(),
    memo: j['memo']?.toString(),
  );
}

class CryptoTx {
  final String id;
  final String type; // deposit | send | payout
  final String coin; // USDT, BTC
  final String network; // TRON, ERC20, BTC
  final double amount;
  final String status; // pending|processing|confirmed|failed
  final DateTime createdAt;

  CryptoTx({
    required this.id,
    required this.type,
    required this.coin,
    required this.network,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory CryptoTx.fromJson(Map<String, dynamic> j) => CryptoTx(
    id: (j['id'] ?? j['reference'] ?? '').toString(),
    type: (j['type'] ?? '').toString(),
    coin: (j['coin'] ?? '').toString().toUpperCase(),
    network: (j['network'] ?? '').toString().toUpperCase(),
    amount: (j['amount'] is num)
        ? (j['amount'] as num).toDouble()
        : double.tryParse('${j['amount']}') ?? 0.0,
    status: (j['status'] ?? '').toString(),
    createdAt:
        DateTime.tryParse('${j['created_at'] ?? j['createdAt'] ?? ''}') ??
        DateTime.now(),
  );
}
