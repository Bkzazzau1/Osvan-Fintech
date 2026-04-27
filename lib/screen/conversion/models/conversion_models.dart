class ConversionQuote {
  final String from;
  final String to;
  final String? network;
  final String amount; // "2.00"
  final String rate; // "1600.00" or "1.00"
  final String feePercent; // "1.00"
  final String fee; // "15.00"
  final String youReceive; // "0.01"
  final String netSourceAmount; // "1485.00"
  final String expiresInSec; // "250"
  final String quoteId;
  final String provider; // hidden in UI
  final String summary; // computed client-side

  ConversionQuote({
    required this.from,
    required this.to,
    required this.amount,
    required this.rate,
    required this.feePercent,
    required this.fee,
    required this.youReceive,
    required this.netSourceAmount,
    required this.expiresInSec,
    required this.quoteId,
    required this.provider,
    required this.summary,
    this.network,
  });

  factory ConversionQuote.fromJson(Map<String, dynamic> j) {
    final from = (j["from"] ?? '').toString();
    final to = (j["to"] ?? '').toString();
    final amount = (j["amount"] ?? '').toString();
    final rate = (j["rate"] ?? '').toString();
    final feePercent =
        (j["fee_percent"] ?? j["commission_percent"] ?? '').toString();
    final fee = (j["fee"] ?? j["commission"] ?? '').toString();
    final youReceive = (j["you_receive"] ?? '').toString();
    final netSourceAmount = (j["net_source_amount"] ?? '').toString();
    final quoteId = (j["quoteId"] ?? j["quote_id"] ?? '').toString();
    final provider = (j["provider"] ?? '').toString();
    final expiresInSec = (j["expiresInSec"] ?? '').toString();
    final network = j["network"]?.toString();

    final summary =
        "$amount $from → $youReceive $to @ $rate  |  Fee: $fee ($feePercent%)";

    return ConversionQuote(
      from: from,
      to: to,
      amount: amount,
      rate: rate,
      feePercent: feePercent,
      fee: fee,
      youReceive: youReceive,
      netSourceAmount: netSourceAmount,
      expiresInSec: expiresInSec,
      quoteId: quoteId,
      provider: provider,
      summary: summary,
      network: network,
    );
  }
}
