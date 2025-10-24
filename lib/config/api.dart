// lib/config/api.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---- Static constant (back-compat) ----
// NOTE: Keep this pointing to the API root (with /api). We will normalize to
// remove any trailing slash, but preserve the /api suffix.
const String kApiBaseUrl = 'https://fintech.osvan.africa/api';

// ---- Internal helpers: trim + ensure '/api' suffix, no trailing slash ----
String _trimSlashes(String s) {
  var out = s.trim();
  while (out.endsWith('/')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

String _ensureApiSuffix(String root) {
  final t = _trimSlashes(root);
  return t.toLowerCase().endsWith('/api') ? t : '$t/api';
}

// ---- Prefer dotenv if present; else fallback to constant ----
// Returns the API base (ending with '/api' and WITHOUT a trailing slash).
String resolveBaseUrl() {
  final fromEnv = dotenv.env['API_BASE_URL'];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) {
    // If .env provides either https://... or https://.../api, normalize to /api (no trailing slash)
    return _ensureApiSuffix(fromEnv);
  }
  // Fallback constant normalized (no trailing slash)
  return _trimSlashes(kApiBaseUrl);
}

// ---- Riverpod provider ----
final baseUrlProvider = Provider<String>((_) => resolveBaseUrl());

// ---- Helpers: safe URL joining & Uri builder ----
String apiJoin(String base, String path) {
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final p = path.startsWith('/') ? path.substring(1) : path;
  return '$b/$p';
}

Uri apiUri(String baseOrPath,
    [String? maybePath, Map<String, dynamic>? query]) {
  if (maybePath == null) return Uri.parse(baseOrPath);
  final url = apiJoin(baseOrPath, maybePath);
  return Uri.parse(url).replace(
    queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
  );
}
