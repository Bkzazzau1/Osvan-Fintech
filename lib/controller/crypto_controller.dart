import 'dart:async';

import 'package:get/get.dart';
import 'package:osvan_app/services/crypto_service.dart';

class CryptoBalanceItem {
  final String coin; // e.g., "USDT"
  final String network; // e.g., "TRON"
  final double balance; // parsed double for UI only

  CryptoBalanceItem(
      {required this.coin, required this.network, required this.balance});

  factory CryptoBalanceItem.fromServer(Map<String, dynamic> j) {
    final balStr = (j['balance'] ?? '0').toString();
    return CryptoBalanceItem(
      coin: j['coin'] ?? 'USDT',
      network: j['chain'] ?? j['network'] ?? 'TRON',
      balance: double.tryParse(balStr) ?? 0.0,
    );
  }
}

class CryptoTxItem {
  final String type; // 'deposit'|'withdraw'
  final String coin;
  final String network;
  final String status; // PENDING|CONFIRMED|FAILED|ON_HOLD
  final double amount;
  final DateTime createdAt;

  CryptoTxItem({
    required this.type,
    required this.coin,
    required this.network,
    required this.status,
    required this.amount,
    required this.createdAt,
  });

  factory CryptoTxItem.fromServer(Map<String, dynamic> j) {
    final dir = (j['direction'] ?? '').toString().toUpperCase() == 'WITHDRAW'
        ? 'withdraw'
        : 'deposit';
    final amtStr = (j['amount'] ?? '0').toString();
    return CryptoTxItem(
      type: dir,
      coin: j['coin'] ?? 'USDT',
      network: j['chain'] ?? j['network'] ?? 'TRON',
      status: j['status'] ?? 'PENDING',
      amount: double.tryParse(amtStr) ?? 0.0,
      createdAt:
          DateTime.tryParse(j['created_at'] ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

class CryptoController extends GetxController {
  final CryptoService api;
  CryptoController(this.api);

  final isLoading = false.obs;
  final isSending = false.obs; // ✅ needed by SendSheet
  final balances = <CryptoBalanceItem>[].obs;
  final txs = <CryptoTxItem>[].obs;
  final coins =
      <Map<String, dynamic>>[].obs; // [{code, chain, decimals, min_deposit}...]

  /// Public: Refresh everything needed by the view
  Future<void> refreshAll() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      // 1) coins
      final coinList = await api.listCoins();
      coins.assignAll(coinList);

      // 2) balances (if backend endpoint exists); otherwise derive from txs later
      try {
        final balList = await api.balances();
        if (balList.isNotEmpty) {
          balances.assignAll(balList.map(CryptoBalanceItem.fromServer));
        }
      } catch (_) {
        // silently ignore if not implemented server-side yet
      }

      // 3) minimal history (fetch for first available coin)
      final coinCode =
          coinList.isNotEmpty ? (coinList.first['code'] ?? 'USDT') : 'USDT';
      final history = await api.history(coin: coinCode);
      txs.assignAll(history.map(CryptoTxItem.fromServer));

      // If no balances endpoint, compute lightweight per-coin estimate from history credits - debits (not authoritative)
      if (balances.isEmpty && history.isNotEmpty) {
        final map = <String, double>{};
        for (final t in txs) {
          final key = '${t.coin}|${t.network}';
          map[key] =
              (map[key] ?? 0) + (t.type == 'deposit' ? t.amount : -t.amount);
        }
        balances.assignAll(map.entries.map((e) {
          final parts = e.key.split('|');
          return CryptoBalanceItem(
              coin: parts[0], network: parts[1], balance: e.value);
        }));
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Helpers used by ReceiveSheet / SendSheet
  Future<Map<String, dynamic>> getAddress(
      {required String coin, required String chain}) {
    return api.getAddress(coin: coin, chain: chain);
  }

  Future<Map<String, dynamic>> quote({
    required String coin,
    required String chain,
    required String amount,
    required String to,
  }) {
    return api.quote(coin: coin, chain: chain, amount: amount, to: to);
  }

  Future<Map<String, dynamic>> send({
    required String quoteId,
    required String pinOrBio,
  }) async {
    final res = await api.send(quoteId: quoteId, pinOrBio: pinOrBio);
    // On success, refresh txs quickly (non-blocking for UX)
    Future.microtask(() => refreshAll());
    return res;
  }

  /// ✅ Single-call flow for UI: quote → confirm
  Future<Map<String, dynamic>> sendFlow({
    required String coin,
    required String chain,
    required String amount, // string decimal
    required String to, // destination address
    required String pinOrBio, // PIN or biometric token
  }) async {
    if (isSending.value) {
      return {'status': 'BUSY'};
    }
    isSending.value = true;
    try {
      // 1) Get server-side quote
      final q = await quote(coin: coin, chain: chain, amount: amount, to: to);
      final quoteId = q['quote_id']?.toString();
      if (quoteId == null || quoteId.isEmpty) {
        throw Exception('Invalid quote (missing quote_id)');
      }

      // 2) Confirm with PIN/biometric (server enforces fees, TTL, limits)
      final res = await send(quoteId: quoteId, pinOrBio: pinOrBio);
      return {
        'status': res['status'],
        'ref': res['ref'],
        'platform_fee': q['platform_fee'],
        'network_fee': q['network_fee'],
        'total_debit': q['total_debit'],
      };
    } finally {
      isSending.value = false;
    }
  }
}
