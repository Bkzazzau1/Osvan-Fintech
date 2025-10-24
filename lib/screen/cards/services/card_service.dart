import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:osvan_app/config/env.dart';

import '../models/card_model.dart';
import 'auth_service.dart';

/// Build `https://host/api/v1` from Env.autoBaseUrl (no trailing slash).
String get _apiRoot {
  final root = Env.autoBaseUrl.replaceAll(RegExp(r'/+$'), '');
  return '$root/api/v1';
}

Map<String, String> _headers(String token, {bool json = true}) => {
      'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };

Uri _u(String path) =>
    Uri.parse('$_apiRoot/${path.replaceFirst(RegExp(r"^/+"), "")}');

class CardService {
  // -----------------------------
  // Cards (list / freeze / PIN / delete / request)
  // -----------------------------

  /// 🔐 Get all user cards
  /// Backend: GET /api/v1/cards/
  static Future<List<CardModel>> getCards() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Authentication token not found");
    }

    final resp = await http.get(_u('cards/'), headers: _headers(token));
    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      final list = (decoded is List)
          ? decoded
          : (decoded is Map && decoded['data'] is List
              ? decoded['data']
              : <dynamic>[]);
      return list
          .map<CardModel>(
              (e) => CardModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception('Failed to load cards: ${resp.statusCode} ${resp.body}');
  }

  /// ❄️ Freeze / Unfreeze a card
  /// Backend: POST /api/v1/cards/{id}/freeze/ or /unfreeze/
  static Future<void> toggleFreeze(dynamic id, bool freeze) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Authentication token not found");
    }

    final cardId = id.toString();
    final path = 'cards/$cardId/${freeze ? "freeze" : "unfreeze"}/';
    final resp = await http.post(_u(path), headers: _headers(token));
    if (resp.statusCode != 200) {
      throw Exception(
          'Failed to toggle freeze: ${resp.statusCode} ${resp.body}');
    }
  }

  /// 👁️ View Card PIN (proxied by backend)
  /// Backend: GET /api/v1/cards/{id}/pin/
  static Future<String> getCardPin(dynamic id) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Authentication token not found");
    }

    final cardId = id.toString();
    final resp = await http.get(
      _u('cards/$cardId/pin/'),
      headers: _headers(token, json: false),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final pin = data['pin']?.toString();
      if (pin == null || pin.isEmpty) throw Exception('PIN not available');
      return pin;
    }
    throw Exception('Failed to retrieve PIN: ${resp.statusCode} ${resp.body}');
  }

  /// 🗑️ Delete a card (204 or 200)
  /// Backend: DELETE /api/v1/cards/{id}/
  static Future<void> deleteCard(dynamic id) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Authentication token not found");
    }

    final cardId = id.toString();
    final resp = await http.delete(
      _u('cards/$cardId/'),
      headers: _headers(token, json: false),
    );
    if (resp.statusCode != 204 && resp.statusCode != 200) {
      throw Exception('Failed to delete card: ${resp.statusCode} ${resp.body}');
    }
  }

  /// ➕ Request new card
  /// Backend: POST /api/v1/cards/request/
  /// If your backend expects a body (brand/type/amount), pass it in [body].
  static Future<void> requestNewCard({Map<String, dynamic>? body}) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Authentication token not found");
    }

    final resp = await http.post(
      _u('cards/request/'),
      headers: _headers(token),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception(
          'Failed to request new card: ${resp.statusCode} ${resp.body}');
    }
  }

  // -----------------------------
  // Wallet ↔ Card money movement
  // -----------------------------

  /// 💰 Fund card from a wallet (server will convert/fee)
  /// Backend: POST /api/v1/wallets/fund-via-card/
  // ignore: unintended_html_in_doc_comment
  /// Body: {"amount":"...", "currency":"USD|...", "card_id":"<id>"}
  static Future<void> fundWalletViaCard({
    required String cardId,
    required String currency, // e.g. "USD"
    required String amount,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Authentication token not found");
    }

    final resp = await http.post(
      _u('wallets/fund-via-card/'),
      headers: _headers(token),
      body: jsonEncode({
        'amount': amount,
        'currency': currency,
        'card_id': cardId,
      }),
    );

    if (resp.statusCode != 200) {
      String msg;
      try {
        msg = jsonDecode(resp.body)['error']?.toString() ?? resp.body;
      } catch (_) {
        msg = resp.body;
      }
      throw Exception('Failed to fund card: $msg');
    }
  }

  /// 💳 Withdraw from card into a wallet
  /// Backend: POST /api/v1/cards/{pk}/withdraw/
  /// Body: {"amount":"...", "currency":"USD", "close_card": false}
  static Future<void> withdrawFromCard({
    required String cardId,
    required String currency, // must match card currency (usually "USD")
    required String amount,
    bool closeCard = false,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Authentication token not found");
    }

    final resp = await http.post(
      _u('cards/$cardId/withdraw/'),
      headers: _headers(token),
      body: jsonEncode({
        'amount': amount,
        'currency': currency,
        'close_card': closeCard,
      }),
    );

    if (resp.statusCode != 200) {
      String msg;
      try {
        msg = jsonDecode(resp.body)['error']?.toString() ?? resp.body;
      } catch (_) {
        msg = resp.body;
      }
      throw Exception('Failed to withdraw: $msg');
    }
  }
}
