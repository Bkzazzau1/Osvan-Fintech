// Keep this file slim; mirror your PayoutsApi style.
import 'package:dio/dio.dart';
import 'package:osvan_app/services/api/api_paths_cards.dart';
import 'package:osvan_app/services/api/core_client.dart';

class CardsApi {
  CardsApi._(this._dio);
  static CardsApi? _instance;
  final Dio _dio;

  static Future<CardsApi> ensureInitialized() async {
    await CoreClient.ensure();
    _instance ??= CardsApi._(CoreClient.I.dio);
    return _instance!;
  }

  static CardsApi get I =>
      _instance ??
      (throw StateError('CardsApi not initialized. Call ensureInitialized().'));

  // ─────────────── Calls (MVP set; we’ll add more after UI wiring) ───────────────

  Future<Response> listCards({int page = 1, int take = 50}) {
    return _dio.get(
      ApiPathsCards.list,
      queryParameters: {'page': page, 'take': take},
    );
  }

  Future<Response> fetchCard(String cardId) {
    return _dio.get(ApiPathsCards.fetch(cardId));
  }

  Future<Response> requestCard(Map<String, dynamic> body) {
    // e.g. { "currency":"USD", "label":"Main Card" } or what your backend expects
    return _dio.post(ApiPathsCards.request, data: body);
  }

  Future<Response> freezeCard(String cardId, {String? reason}) {
    return _dio.post(ApiPathsCards.freeze(cardId),
        data: reason == null ? {} : {"reason": reason});
  }

  Future<Response> unfreezeCard(String cardId) {
    return _dio.post(ApiPathsCards.unfreeze(cardId), data: {});
  }

  Future<Response> terminateCard(String cardId) {
    return _dio.post(ApiPathsCards.terminate(cardId), data: {});
  }

  Future<Response> listTransactionsOnCard(String cardId,
      {int page = 1, int take = 50}) {
    return _dio.get(ApiPathsCards.transactions(cardId),
        queryParameters: {"page": page, "take": take});
  }
}
