import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';

/// Central store for auth tokens (works on web & mobile).
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static bool _init = false;
  final _box = GetStorage();
  final _secure = const FlutterSecureStorage();

  /// Call once during app bootstrap (e.g., main()).
  static Future<void> init() async {
    if (_init) return;
    await GetStorage.init();
    _init = true;
  }

  Future<void> saveTokens({required String access, String? refresh}) async {
    // Persist in secure storage (mobile) + box (all)
    if (!kIsWeb) {
      try {
        await _secure.write(key: 'access', value: access);
      } catch (_) {}
      if (refresh != null) {
        try {
          await _secure.write(key: 'refresh', value: refresh);
        } catch (_) {}
      }
    }
    await _box.write('access', access);
    if (refresh != null) await _box.write('refresh', refresh);
    // legacy alias (some screens read 'token')
    await _box.write('token', access);
  }

  Future<String?> get access async {
    final s = _box.read<String>('access');
    if (s != null && s.isNotEmpty) return s;
    if (!kIsWeb) return await _secure.read(key: 'access');
    return null;
  }

  Future<String?> get refresh async {
    final s = _box.read<String>('refresh');
    if (s != null && s.isNotEmpty) return s;
    if (!kIsWeb) return await _secure.read(key: 'refresh');
    return null;
  }

  Future<void> clear() async {
    if (!kIsWeb) {
      try {
        await _secure.delete(key: 'access');
      } catch (_) {}
      try {
        await _secure.delete(key: 'refresh');
      } catch (_) {}
    }
    await _box.remove('access');
    await _box.remove('refresh');
    await _box.remove('token');
  }

  Future<bool> get isLoggedIn async => (await access)?.isNotEmpty == true;

  /// Convenience header map for authorized calls.
  Future<Map<String, String>> authHeader() async {
    final a = await access;
    return a == null ? {} : {'Authorization': 'Bearer $a'};
  }
}
