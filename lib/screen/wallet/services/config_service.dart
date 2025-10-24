import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:osvan_app/config/env.dart';

/// App-wide config fetched from the backend Control API.
///
/// Base rules:
/// - [baseUrl] is the canonical API root and ALWAYS ends with `/api`
///   (without a trailing slash after it).
/// - Use [apiUri('/v1/...')] to build endpoint URLs safely.
///
/// Remote config endpoint:
///   GET  ${baseUrl}/meta/app-config/
///
/// Expected JSON shape (example):
/// {
///   "features": {
///     "card_fund_enabled": true,
///     "card_withdraw_enabled": true,
///     "usd_card_only": true
///   },
///   "defaults": {
///     "default_card_currency": "USD",
///     "min_close_balance_usd": "1.00"
///   },
///   "conversion": {
///     "fee_percentage": 2.0,
///     "rates": {"USD":"1","NGN":"1600","KES":"128"}
///   }
/// }
class ConfigService extends GetxService {
  static const _boxName = 'app_config_box';
  static const _cacheKey = 'app_config_cache';
  static const _cacheTsKey = 'app_config_cache_ts';

  static const Duration cacheTtl = Duration(hours: 6);

  final GetStorage _box = GetStorage(_boxName);

  // Raw payload
  Map<String, dynamic> _data = const {};

  // Parsed fields (reactive if you want to observe)
  final _features = <String, bool>{}.obs;
  final _defaults = <String, String>{}.obs;
  final _rates = <String, String>{}.obs;
  final _feePct = 2.0.obs;

  // ===== API root =====
  /// Canonical API base URL used across the app.
  /// - Ensures no trailing slash
  /// - Ensures it ends with `/api`
  static String get baseUrl {
    final raw = Env.autoBaseUrl.trim();
    final root = raw.replaceAll(RegExp(r'/+$'), ''); // strip trailing slashes
    if (root.endsWith('/api')) return root; // already ok (no trailing slash)
    return '$root/api';
  }

  /// Build a full API Uri from a path (with or without a leading slash).
  /// Example: `apiUri('/v1/profile/limits/')`
  static Uri apiUri(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$baseUrl/$p');
  }

  // -------- Public getters (read-only) --------
  bool get cardsFundEnabled => _features['card_fund_enabled'] ?? true;
  bool get cardsWithdrawEnabled => _features['card_withdraw_enabled'] ?? true;
  bool get usdCardOnly => _features['usd_card_only'] ?? true;

  String get defaultCardCurrency => _defaults['default_card_currency'] ?? 'USD';
  String get minCloseBalanceUsd => _defaults['min_close_balance_usd'] ?? '1.00';

  double get conversionFeePct => _feePct.value;

  /// 1 USD = X <code> (as String to avoid locale issues)
  Map<String, String> get fxRates => Map.unmodifiable(_rates);

  /// Safe lookup: returns a stringified number. Defaults to "1" for USD.
  String rateFor(String currencyCode) {
    final key = (currencyCode).toUpperCase().trim();
    return _rates[key] ?? (key == 'USD' ? '1' : '1');
  }

  /// Entire raw JSON (if ever needed)
  Map<String, dynamic> get raw => Map.unmodifiable(_data);

  // -------- Lifecycle --------
  static Future<ConfigService> init() async {
    await GetStorage.init(_boxName);
    final svc = Get.put(ConfigService(), permanent: true);
    await svc.load(); // load from cache / network
    return svc;
  }

  /// Load from cache (if fresh) then refresh from network in the background.
  /// If no cache or cache expired, tries network immediately.
  Future<void> load() async {
    final now = DateTime.now();
    try {
      final tsStr = _box.read<String>(_cacheTsKey);
      final cached = _box.read<String>(_cacheKey);

      if (tsStr != null && cached != null) {
        final ts = DateTime.tryParse(tsStr);
        if (ts != null && now.difference(ts) < cacheTtl) {
          _apply(jsonDecode(cached) as Map<String, dynamic>, source: 'cache');
        }
      }
    } catch (_) {
      // ignore cache parse errors
    }

    // Always try to refresh (so admin toggles reflect quickly)
    try {
      final fresh = await _fetchFromNetwork();
      if (fresh != null) {
        _apply(fresh, source: 'network');
        _box.write(_cacheKey, jsonEncode(fresh));
        _box.write(_cacheTsKey, now.toIso8601String());
      } else if (_data.isEmpty) {
        // Network returned non-200 and we have no data at all
        _apply(_fallback(), source: 'fallback');
      }
    } catch (_) {
      // If network fails and we have no data yet, ensure minimal sane defaults
      if (_data.isEmpty) {
        _apply(_fallback(), source: 'fallback');
      }
    }
  }

  /// Force re-fetch ignoring cache (useful after login/tenant switch/etc).
  Future<void> refreshNow() async {
    try {
      final fresh = await _fetchFromNetwork();
      if (fresh != null) {
        _apply(fresh, source: 'refresh');
        _box.write(_cacheKey, jsonEncode(fresh));
        _box.write(_cacheTsKey, DateTime.now().toIso8601String());
      }
    } catch (_) {
      // swallow; keep existing data
    }
  }

  Future<Map<String, dynamic>?> _fetchFromNetwork() async {
    // baseUrl already ends with /api, so we only append relative path
    final url = apiUri('/meta/app-config/');
    // Public endpoint (AllowAny), no token required
    final resp = await http.get(url, headers: {'Accept': 'application/json'});
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    return null;
    // (Optional) You can add logging here for non-200 codes.
  }

  void _apply(Map<String, dynamic> data, {required String source}) {
    _data = data;

    final f = (data['features'] as Map?) ?? const {};
    final d = (data['defaults'] as Map?) ?? const {};
    final c = (data['conversion'] as Map?) ?? const {};
    final rates = (c['rates'] as Map?) ?? const {};

    _features.assignAll(f.map((k, v) => MapEntry(k.toString(), v == true)));
    _defaults.assignAll(
      d.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
    );
    _feePct.value = _parseDouble(c['fee_percentage'], 2.0);

    // Normalize rate values to strings
    final normalizedRates = <String, String>{};
    for (final entry in rates.entries) {
      final code = entry.key.toString().toUpperCase();
      final val = entry.value;
      normalizedRates[code] = (val is String) ? val : val?.toString() ?? '';
    }
    if (!normalizedRates.containsKey('USD')) normalizedRates['USD'] = '1';
    _rates.assignAll(normalizedRates);
  }

  double _parseDouble(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  Map<String, dynamic> _fallback() => {
        'features': {
          'card_fund_enabled': true,
          'card_withdraw_enabled': true,
          'usd_card_only': true,
        },
        'defaults': {
          'default_card_currency': 'USD',
          'min_close_balance_usd': '1.00',
        },
        'conversion': {
          'fee_percentage': 2.0,
          'rates': {'USD': '1'},
        },
      };
}
