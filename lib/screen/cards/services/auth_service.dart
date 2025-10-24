import 'package:get_storage/get_storage.dart';

class AuthService {
  static final GetStorage _storage = GetStorage();
  static const String _tokenKey = 'token';

  /// Ensure GetStorage.init() is called in main() before using this service.
  /// Example:
  ///   void main() async {
  ///     WidgetsFlutterBinding.ensureInitialized();
  ///     await GetStorage.init();
  ///     runApp(MyApp());
  ///   }

  /// Save token securely
  static Future<void> setToken(String token) async {
    await _storage.write(_tokenKey, token);
  }

  /// Retrieve token
  static Future<String?> getToken() async {
    final token = _storage.read<String>(_tokenKey);
    return token;
  }

  /// Remove token (for logout or reset)
  static Future<void> clearToken() async {
    await _storage.remove(_tokenKey);
  }

  /// Check if token exists
  static bool isLoggedIn() {
    final token = _storage.read<String>(_tokenKey);
    return token != null && token.isNotEmpty;
  }
}
