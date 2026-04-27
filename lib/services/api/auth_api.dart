import 'package:dio/dio.dart';
import 'package:osvan_app/services/api/api_paths.dart';
import 'package:osvan_app/services/api/core_client.dart';
import 'package:osvan_app/store/session_store.dart';

/// AuthApi: login/logout + /api/user/me/
/// Uses the shared CoreClient (Dio + refresh) to avoid duplication.
class AuthApi {
  AuthApi._(this._dio, this._store);

  static AuthApi? _instance;

  final Dio _dio;
  final SessionStore _store;

  static Future<AuthApi> ensureInitialized() async {
    await CoreClient.ensure(); // make sure singleton is ready
    final dio = CoreClient.I.dio;
    final store = SessionStore.instance;
    _instance ??= AuthApi._(dio, store);
    return _instance!;
  }

  static AuthApi get I =>
      _instance ??
      (throw StateError('AuthApi not initialized. Call ensureInitialized().'));

  // ---------- auth ----------
  /// Email-first login against /api/token/login/
  Future<void> loginEmail({
    required String email,
    required String password,
  }) async {
    final r = await _dio.post(
      ApiPaths.tokenLogin,
      data: {'email': email.trim(), 'password': password},
      options: Options(headers: {'X-Skip-Auth': '1'}),
    );
    final body = CoreClient.I.mapOrEmpty(r.data);
    final access = (body['access'] as String?) ?? '';
    final refresh = body['refresh'] as String?;
    if (access.isEmpty) {
      throw DioException(
        requestOptions: r.requestOptions,
        response: r,
        message: 'No access token in response',
        type: DioExceptionType.badResponse,
      );
    }
    await _store.saveTokens(access: access, refresh: refresh);
  }

  /// Smart login — prefer email; else username.
  Future<void> loginSmart({
    String? email,
    String? username,
    required String password,
  }) async {
    final payload = <String, dynamic>{'password': password};
    if ((email ?? '').isNotEmpty) {
      payload['email'] = email!.trim();
    } else if ((username ?? '').isNotEmpty) {
      payload['username'] = username;
    } else {
      throw ArgumentError('Provide email or username');
    }

    final r = await _dio.post(
      ApiPaths.tokenLogin,
      data: payload,
      options: Options(headers: {'X-Skip-Auth': '1'}),
    );
    final body = CoreClient.I.mapOrEmpty(r.data);
    final access = (body['access'] as String?) ?? '';
    final refresh = body['refresh'] as String?;
    if (access.isEmpty) {
      throw DioException(
        requestOptions: r.requestOptions,
        response: r,
        message: 'No access token in response',
        type: DioExceptionType.badResponse,
      );
    }
    await _store.saveTokens(access: access, refresh: refresh);
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    await loginSmart(username: username, password: password);
  }

  Future<void> logout() async => _store.clear();

  // ---------- user ----------
  /// returns: {id, username, email, first_name, last_name}
  Future<Map<String, dynamic>> getMe() async {
    final r = await _dio.get(ApiPaths.userMe);
    return Map<String, dynamic>.from(r.data as Map);
  }
}
