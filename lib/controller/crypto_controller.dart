// lib/controller/crypto_controller.dart
// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:osvan_app/services/crypto_service.dart';

/// ─────────────────────────────────────────────────────────────
/// Option-B rails (server also enforces these)
/// USDT: TRON, BSC
/// USDC: TRON, ETH
/// ─────────────────────────────────────────────────────────────
const _ALLOWED_COINS = {'USDT', 'USDC'};
const _ALLOWED_BY_COIN = <String, Set<String>>{
  'USDT': {'TRON', 'BSC'},
  'USDC': {'TRON', 'ETH'},
};

const _ADDR_STORE_KEY = 'crypto_addr_cache_v1'; // GetStorage key

String _uc(Object? s, {String fallback = ''}) =>
    (s?.toString() ?? fallback).trim().toUpperCase();

double _toDouble(Object? v, {double fallback = 0}) {
  final s = (v ?? '').toString().trim();
  final d = double.tryParse(s);
  return d ?? fallback;
}

DateTime _toDate(Object? v) {
  final s = (v ?? '').toString();
  final dt = DateTime.tryParse(s);
  return (dt ?? DateTime.now()).toLocal();
}

/// ✅ Clean error strings so UI shows backend messages clearly
String _prettyErr(Object e) {
  final s = e.toString().trim();
  return s.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
}

class CryptoBalanceItem {
  final String coin; // e.g., "USDT"
  final String network; // e.g., "TRON"
  final double balance; // parsed double for UI only

  CryptoBalanceItem({
    required this.coin,
    required this.network,
    required this.balance,
  });

  factory CryptoBalanceItem.fromServer(Map<String, dynamic> j) {
    final coin = _uc(j['ticker'] ?? j['coin'], fallback: 'USDT');
    final net = _uc(j['network'] ?? j['chain'], fallback: 'TRON');
    return CryptoBalanceItem(
      coin: coin,
      network: net,
      balance: _toDouble(j['balance']),
    );
  }
}

class CryptoTxItem {
  final String type; // 'receive' | 'send'
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
    final type = _uc(j['type'], fallback: 'receive').toLowerCase();

    return CryptoTxItem(
      type: type,
      coin: _uc(j['ticker'] ?? j['coin'], fallback: 'USDT'),
      network: _uc(j['network'] ?? j['chain'], fallback: 'TRON'),
      status: _uc(j['status'], fallback: 'PENDING'),
      amount: _toDouble(j['amount']),
      createdAt: _toDate(j['created_at']),
    );
  }
}

class CryptoController extends GetxController {
  final CryptoService api;
  CryptoController(this.api);

  final isLoading = false.obs;
  final isSending = false.obs; // used by SendSheet
  final balances = <CryptoBalanceItem>[].obs;
  final txs = <CryptoTxItem>[].obs;

  /// Coins config from server (kept for future use)
  /// [{code, chain, decimals, min_deposit}...]
  final coins = <Map<String, dynamic>>[].obs;

  /// Persistent address cache (COIN::NETWORK -> {address, tag})
  final _addrCache = <String, Map<String, String?>>{}.obs;
  late final GetStorage _box;

  // ─────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _box = GetStorage();
    _loadAddrCache();
  }

  // Load cache from storage into reactive map
  void _loadAddrCache() {
    final raw = _box.read(_ADDR_STORE_KEY);
    if (raw is Map) {
      // normalize types
      final casted = raw.map((k, v) {
        final key = k.toString();
        if (v is Map) {
          return MapEntry<String, Map<String, String?>>(
            key,
            {
              'address': v['address']?.toString(),
              'tag': v['tag']?.toString(),
            },
          );
        }
        return MapEntry<String, Map<String, String?>>(key, {});
      });
      _addrCache.assignAll(casted);
    }
  }

  // Save reactive map back to storage
  Future<void> _saveAddrCache() async {
    await _box.write(_ADDR_STORE_KEY, _addrCache);
  }

  String _key(String coin, String network) =>
      '${coin.toUpperCase()}::${network.toUpperCase()}';

  // ─────────────────────────────────────────────────────────────
  // Public: Refresh everything needed by the view
  // ─────────────────────────────────────────────────────────────
  Future<void> refreshAll() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      // Ensure wallets exist before querying balances/txs
      await _safe(() => api.ensureWallets(), fallback: null);

      // 1) Load supported coins (ignore server coins not in Option-B)
      final coinList = await _safe<List<Map<String, dynamic>>>(() async {
        final raw = await api.listCoins();
        return raw
            .map((m) => Map<String, dynamic>.from(m))
            .where((m) => _ALLOWED_COINS.contains(_uc(m['code'])))
            .toList();
      }, fallback: const []);
      coins.assignAll(coinList);

      // 2) Load balances (optional endpoint)
      final balList = await _safe<List<dynamic>>(
        () => api.balances(),
        fallback: const [],
      );

      balances.clear();
      if (balList.isNotEmpty) {
        final parsed = balList
            .map((e) => CryptoBalanceItem.fromServer(
                  Map<String, dynamic>.from(e as Map),
                ))
            .where((b) =>
                _ALLOWED_COINS.contains(b.coin) &&
                _ALLOWED_BY_COIN[b.coin]!.contains(b.network))
            .toList();
        balances.assignAll(parsed);
      }

      // 3) History (pick first available coin; prefer USDT)
      final firstCoin = coins.isNotEmpty
          ? _uc(coins.first['code'])
          : (balances.isNotEmpty ? balances.first.coin : 'USDT');

      final allowed = _ALLOWED_BY_COIN[firstCoin] ?? const <String>{};
      final preferredNetwork = allowed.contains('TRON')
          ? 'TRON'
          : (allowed.isNotEmpty ? allowed.first : 'TRON');

      final history = await _safe<List<dynamic>>(
        () => api.history(
          coin: firstCoin,
          network: preferredNetwork,
          pageSize: 25,
          page: 1,
        ),
        fallback: const [],
      );

      final parsedTx = history
          .map((e) =>
              CryptoTxItem.fromServer(Map<String, dynamic>.from(e as Map)))
          .where((t) =>
              _ALLOWED_COINS.contains(t.coin) &&
              _ALLOWED_BY_COIN[t.coin]!.contains(t.network))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      txs.assignAll(parsedTx);

      // 4) If balances endpoint is absent/empty, derive rough balances from txs
      if (balances.isEmpty && txs.isNotEmpty) {
        final agg = <String, double>{}; // key: coin|network
        for (final t in txs) {
          final key = '${t.coin}|${t.network}';
          agg[key] =
              (agg[key] ?? 0) + (t.type == 'receive' ? t.amount : -t.amount);
        }
        final derived = agg.entries.map((e) {
          final parts = e.key.split('|');
          return CryptoBalanceItem(
            coin: parts[0],
            network: parts[1],
            balance: e.value,
          );
        }).toList();
        balances.assignAll(derived);
      }
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Receive / Send helpers
  // ─────────────────────────────────────────────────────────────

  /// Get (or refresh) a deposit address for a coin+network.
  /// Uses persistent cache unless [force] = true.
  Future<Map<String, dynamic>> getAddress({
    required String coin,
    required String chain,
    bool force = false,
  }) async {
    final c = _uc(coin, fallback: 'USDT');
    final n = _uc(chain, fallback: 'TRON');

    // Enforce Option-B early (still validated server-side)
    if (!_ALLOWED_COINS.contains(c) || !_ALLOWED_BY_COIN[c]!.contains(n)) {
      throw Exception('Unsupported pair: $c on $n');
    }

    final k = _key(c, n);

    // Serve from cache if available and not forcing
    if (!force && _addrCache.containsKey(k)) {
      final cached = _addrCache[k]!;
      final addr = (cached['address'] ?? '').toString();
      final tag = cached['tag']?.toString();
      if (addr.isNotEmpty) {
        return {'address': addr, 'tag': tag};
      }
    }

    // Fetch and persist
    final res = await api.getAddress(coin: c, chain: n);
    final addr = (res['address'] ?? '').toString();
    final tag = res['tag']?.toString();

    _addrCache[k] = {'address': addr, 'tag': tag};
    await _saveAddrCache();

    return {'address': addr, 'tag': tag};
  }

  Future<Map<String, dynamic>> quote({
    required String coin,
    required String chain,
    required String amount,
    required String to,
  }) async {
    final c = _uc(coin, fallback: 'USDT');
    final n = _uc(chain, fallback: 'TRON');

    if (!_ALLOWED_COINS.contains(c) || !_ALLOWED_BY_COIN[c]!.contains(n)) {
      throw Exception('Unsupported pair: $c on $n');
    }
    return await api.quote(coin: c, chain: n, amount: amount, to: to);
  }

  Future<Map<String, dynamic>> send({
    required String quoteId,
    required String pinOrBio,
  }) async {
    final res = await api.send(quoteId: quoteId, pinOrBio: pinOrBio);
    // Non-blocking refresh
    Future.microtask(() => refreshAll());
    return res;
  }

  /// Single-call flow for UI: quote → confirm
  Future<Map<String, dynamic>> sendFlow({
    required String coin,
    required String chain,
    required String amount, // string decimal
    required String to, // destination address
    required String pinOrBio, // PIN or biometric token
  }) async {
    if (isSending.value) return {'status': 'BUSY'};
    isSending.value = true;
    try {
      final q = await quote(coin: coin, chain: chain, amount: amount, to: to);
      final quoteId = (q['quote_id'] ?? '').toString();
      if (quoteId.isEmpty) {
        throw Exception('Invalid quote (missing quote_id)');
      }
      final res = await send(quoteId: quoteId, pinOrBio: pinOrBio);
      return {
        'status': (res['status'] ?? '').toString(),
        'ref': (res['ref'] ?? '').toString(),
        'platform_fee': q['platform_fee'],
        'network_fee': q['network_fee'],
        'total_debit': q['total_debit'],
      };
    } catch (e) {
      // ✅ surface clean backend error to UI
      throw Exception(_prettyErr(e));
    } finally {
      isSending.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Internal: safe call wrapper
  // ─────────────────────────────────────────────────────────────
  Future<T> _safe<T>(Future<T> Function() fn, {required T fallback}) async {
    try {
      return await fn();
    } catch (_) {
      return fallback;
    }
  }
}
