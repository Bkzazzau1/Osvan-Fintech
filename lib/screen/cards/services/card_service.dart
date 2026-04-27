// lib/screen/cards/services/card_service.dart
// Centralized service for Cards (Dio + CoreClient).
//
// Stable Django endpoints now supported:
//   GET    /api/cards/                                   -> list cards
//   POST   /api/cards/register-user/                      -> register card user (provider prereq, FULL KYC only from CardsView)
//   POST   /api/cards/kyc/upload-photo/                   -> upload selfie and receive URL for register-user
//   POST   /api/cards/request/                            -> create/request new card (**amount is CENTS**)
//   POST   /api/cards/topup/                              -> top-up (body: cardId, amount cents, currency, reference?)
//   POST   /api/cards/<id>/topup/                         -> top-up by path (amount cents, currency, reference?)
//   POST   /api/cards/withdraw/                           -> withdraw (body: cardId, amount cents OR close_card, currency)
//   POST   /api/cards/<id>/withdraw/                      -> withdraw by path (amount cents OR close_card, currency)
//   POST   /api/cards/<id>/provider/topup/                -> provider top-up (amount_cents, currency, reference?)
//   POST   /api/cards/<id>/provider/withdraw/             -> provider withdraw (amount_cents, currency, reference?)
//   POST   /api/cards/<id>/freeze/                        -> freeze
//   POST   /api/cards/<id>/unfreeze/                      -> unfreeze
//   POST   /api/cards/<id>/terminate/                     -> terminate
//   GET    /api/cards/<id>/                               -> fetch single card (masked pan)
//   GET    /api/cards/<id>/transactions/?page=&take=      -> list card txns (paged; tolerant to shapes)
//   GET    /api/cards/<id>/pin/                           -> view PIN (if backend supports; tolerant)
//   GET    /api/cards/<id>/statement.pdf                  -> direct PDF (we only build URL)

// ignore_for_file: constant_identifier_names, unintended_html_in_doc_comment

import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';
import 'package:osvan_app/services/api/api_paths_cards.dart';
import 'package:osvan_app/services/api_client.dart';
import 'package:osvan_app/services/api/core_client.dart';
import 'package:osvan_app/services/provider_error_helper.dart';

class CardService {
  CardService._(this._dio);
  static CardService? _instance;
  final Dio _dio;

  // ─────────────────────────── Init ───────────────────────────
  static Future<CardService> ensureInitialized() async {
    await CoreClient.ensure();
    _instance ??= CardService._(CoreClient.I.dio);
    try {
      await GetStorage.init();
    } catch (_) {}
    return _instance!;
  }

  static CardService get I =>
      _instance ??
      (throw StateError(
          'CardService not initialized. Call ensureInitialized().'));

  // ─────────────────────────── Local flags (KYC) ───────────────────────────
  static const _KYC_KEY = 'card_user_registered';

  static Future<bool> isCardUserRegistered() async {
    await ensureInitialized();
    try {
      final box = GetStorage();
      return box.read(_KYC_KEY) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setCardUserRegistered(bool v) async {
    await ensureInitialized();
    try {
      final box = GetStorage();
      await box.write(_KYC_KEY, v);
    } catch (_) {}
  }

  // ─────────────────────────── Paths ───────────────────────────
  static String _cards() => '/api/cards/';
  static String _registerUser() => ApiPathsCards.registerUser;
  static String _request() => '/api/cards/request/';
  static String _freeze(String id) => '/api/cards/$id/freeze/';
  static String _unfreeze(String id) => '/api/cards/$id/unfreeze/';
  static String _terminate(String id) => '/api/cards/$id/terminate/';
  static String _fetch(String id) => '/api/cards/$id/';
  static String _txns(String id) => '/api/cards/$id/transactions/';
  static String _pin(String id) => '/api/cards/$id/pin/'; // backend optional

  // Cents-first local/provider ops
  static String _topupSimple() => '/api/cards/topup/';
  static String _topupPath(String id) => '/api/cards/$id/topup/';
  static String _withdrawSimple() => '/api/cards/withdraw/';
  static String _withdrawPath(String id) => '/api/cards/$id/withdraw/';
  static String _provTopup(String id) => '/api/cards/$id/provider/topup/';
  static String _provWithdraw(String id) => '/api/cards/$id/provider/withdraw/';

  static String _me() => '/api/user/me/';

  // For statement we only build a fully-qualified URL (no request here).
  static String statementPdfUrl(String id) {
    final base = CoreClient.I.dio.options.baseUrl;
    final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$root/api/cards/$id/statement.pdf';
  }

  static String getStatementUrl(String id) => statementPdfUrl(id);

  // ─────────────────────────── Helpers ───────────────────────────
  static Options _withIdem(String? key) {
    if (key == null || key.trim().isEmpty) return Options();
    return Options(headers: {'Idempotency-Key': key});
  }

  /// Fetches current user (for canonical email, names).
  static Future<Map<String, dynamic>> _getMe() async {
    await ensureInitialized();
    final res = await I._dio.get(_me());
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : <String, dynamic>{};
  }

  /// Public accessor for current user (cards screens).
  static Future<Map<String, dynamic>> getMeForCards() async => _getMe();

  // Small local helpers for registerCardUser()
  static String _s(dynamic v) => (v ?? '').toString().trim();

  static String _cleanPhone(String p) {
    final noSpaces = p.replaceAll(RegExp(r'\s+'), '');
    return noSpaces.startsWith('+') ? noSpaces.substring(1) : noSpaces;
  }

  static String _iso2(String v) {
    final x = _s(v).toUpperCase();
    if (x.isEmpty) return 'NG';
    switch (x) {
      case 'NIGERIA':
      case 'NG':
        return 'NG';
      case 'GHANA':
      case 'GH':
        return 'GH';
      case 'KENYA':
      case 'KE':
        return 'KE';
      case 'UGANDA':
      case 'UG':
        return 'UG';
      case 'UNITED STATES':
      case 'USA':
      case 'US':
        return 'US';
      case 'UNITED KINGDOM':
      case 'UK':
      case 'GB':
        return 'GB';
      case 'UNITED ARAB EMIRATES':
      case 'UAE':
      case 'AE':
        return 'AE';
      case 'SINGAPORE':
      case 'SG':
        return 'SG';
      case 'CHINA':
      case 'CN':
        return 'CN';
      case 'HONG KONG':
      case 'HK':
        return 'HK';
      case 'SOUTH AFRICA':
      case 'ZA':
        return 'ZA';
      default:
        return x.length == 2 ? x : 'NG';
    }
  }

  static String _mapIdType(String t) {
    final x = _s(t).toUpperCase();
    if (x == 'NIN') return 'NIN';
    if (x.contains('PASSPORT')) return 'PASSPORT';
    if (x.contains('DRIVER')) return 'DRIVERS_LICENSE';
    if (x.contains('VOTER')) return 'VOTER_CARD';
    if (x == 'PVC') return 'VOTER_CARD';
    if (x == 'BVN') return 'BVN';
    return x.isEmpty ? 'NIN' : x;
  }

  // ─────────────────────────── Public API ───────────────────────────

  /// Uploads a card KYC photo and returns the HTTPS URL.
  static Future<String> uploadCardKycPhoto(List<int> bytes,
      {String filename = 'photo.jpg'}) async {
    await ensureInitialized();

    final form = FormData.fromMap({
      'photo': MultipartFile.fromBytes(bytes, filename: filename),
    });

    try {
      final res = await I._dio.post(ApiPathsCards.uploadPhoto, data: form);
      final data = res.data;
      if (data is Map && data['url'] != null) {
        final url = data['url'].toString().trim();
        if (url.isNotEmpty) return url;
      }
      throw {
        'message': 'Photo upload failed',
        'detail': 'No URL returned from upload-photo.',
      };
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final d = e.response?.data;
      if (d is Map && d['message'] != null) {
        throw {
          'message': d['message'],
          'status': status,
          'detail': d['detail'] ?? d['error'],
        };
      }
      throw {
        'message': 'Photo upload failed',
        'status': status,
        'error': d,
      };
    }
  }

  /// FULL provider registration (CardsView only).
  /// Keys: customerEmail, idNumber, idType, firstName, lastName, phoneNumber,
  /// city, state, country(ISO2), zipCode, line1, houseName?, idImage?, bvn?,
  /// userPhoto?, dateOfBirth (YYYY-MM-DD)
  static Future<Map<String, dynamic>> registerCardUser(
      Map<String, dynamic> payload) async {
    await ensureInitialized();

    final body = <String, dynamic>{
      'customerEmail': _s(payload['customerEmail']),
      'idNumber': _s(payload['idNumber']),
      'idType': _mapIdType(payload['idType']),
      'firstName': _s(payload['firstName']),
      'lastName': _s(payload['lastName']),
      'phoneNumber': _cleanPhone(_s(payload['phoneNumber'])),
      'city': _s(payload['city']),
      'state': _s(payload['state']),
      'country': _iso2(payload['country']), // REQUIRED (ISO2)
      'zipCode': _s(payload['zipCode']),
      'line1': _s(payload['line1']),
      if (_s(payload['houseName']).isNotEmpty)
        'houseName': _s(payload['houseName']),
      if (_s(payload['idImage']).isNotEmpty) 'idImage': _s(payload['idImage']),
      if (_s(payload['bvn']).isNotEmpty) 'bvn': _s(payload['bvn']),
      if (_s(payload['userPhoto']).isNotEmpty)
        'userPhoto': _s(payload['userPhoto']),
      'dateOfBirth': _s(payload['dateOfBirth']), // YYYY-MM-DD
    };

    final c = _s(body['country']);
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(c)) {
      throw {
        'message': 'Please select a valid country',
        'detail': 'Brails requires ISO2 country (e.g., NG, GH, US).'
      };
    }

    try {
      final res = await I._dio.post(_registerUser(), data: body);
      final data = res.data;

      if (data is Map) {
        final err = (data['error'] ?? '').toString().trim();
        if (err.isNotEmpty) {
          throw {
            'message': err,
            'status': res.statusCode,
            'providerMessage': data['providerMessage'] ?? data['reason'],
            'errors': data['errors'] ?? data['fields'],
          };
        }
        final okField = data['ok'];
        final isOk = okField == true || okField == 'true' || okField == 1;
        if (isOk) {
          await setCardUserRegistered(true);
          return Map<String, dynamic>.from(data);
        }
      }

      final sc = res.statusCode ?? 200;
      if (sc >= 200 && sc < 300) {
        await setCardUserRegistered(true);
        return {'ok': true, 'raw': data};
      }

      throw {
        'message': 'Card user registration failed',
        'status': res.statusCode
      };
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final d = e.response?.data;

      // ✅ If provider/backend says user already exists/indexed → treat as success
      if (status == 400 && looksLikeAlreadyExists(d)) {
        await setCardUserRegistered(true);
        return {
          'ok': true,
          'alreadyIndexed': true,
          'raw':
              (d is Map) ? Map<String, dynamic>.from(d) : {'raw': d.toString()},
        };
      }

      final map = <String, dynamic>{
        'message': 'Card user registration failed',
        'status': status,
      };

      if (d is Map) {
        map['detail'] = d['detail'] ?? d['message'] ?? d['error'];
        map['providerMessage'] = d['providerMessage'] ?? d['reason'];
        map['errors'] = d['errors'] ?? d['fields'];
      } else if (d != null) {
        map['detail'] = d.toString();
      } else if (e.message != null) {
        map['detail'] = e.message!;
      }
      throw map;
    }
  }

  /// List cards – tolerant normalize for UI
  static Future<List<Map<String, dynamic>>> listCards() async {
    await ensureInitialized();
    final res = await I._dio.get(_cards());
    final data = res.data;

    // Accept many possible shapes:
    //  1) bare list: [...]
    //  2) { items: [...] }
    //  3) { results: [...] }
    //  4) { cards: [...] }
    //  5) { data: { cards: [...] } }
    //  6) { data: { list: [...] } }
    //  7) { data: [...] }
    //  8) { card: {...} }  (single)
    List items;
    if (data is List) {
      items = data;
    } else if (data is Map) {
      if (data['items'] is List) {
        items = data['items'] as List;
      } else if (data['results'] is List) {
        items = data['results'] as List;
      } else if (data['cards'] is List) {
        items = data['cards'] as List;
      } else if (data['data'] is Map && (data['data']['cards'] is List)) {
        items = data['data']['cards'] as List;
      } else if (data['data'] is Map && (data['data']['list'] is List)) {
        items = data['data']['list'] as List;
      } else if (data['data'] is List) {
        items = data['data'] as List;
      } else if (data['card'] is Map) {
        items = [data['card']];
      } else {
        items = const <dynamic>[];
      }
    } else {
      items = const <dynamic>[];
    }

    Map<String, dynamic> mapOne(dynamic raw) {
      T s<T>(dynamic v, T d) {
        try {
          return (v == null) ? d : v as T;
        } catch (_) {
          return d;
        }
      }

      String id = '';
      if (raw is Map) {
        id = (raw['id'] ?? raw['cardId'] ?? raw['card_id'] ?? raw['_id'] ?? '')
            .toString();
      }

      final brand = ((raw is Map)
              ? (raw['brand'] ?? raw['cardBrand'] ?? raw['provider'] ?? 'visa')
              : 'visa')
          .toString();

      final currency =
          ((raw is Map) ? (raw['currency'] ?? 'USD') : 'USD').toString();

      String status;
      if (raw is Map) {
        if (raw['status'] != null) {
          status = raw['status'].toString();
        } else if (raw['frozen'] == true) {
          status = 'FROZEN';
        } else if (raw['terminated'] == true) {
          status = 'TERMINATED';
        } else {
          status = 'ACTIVE';
        }
      } else {
        status = 'ACTIVE';
      }

      final label =
          ((raw is Map) ? (raw['label'] ?? raw['name'] ?? 'Card') : 'Card')
              .toString();

      // last4: handle lastFour, last4, maskedPan, number, pan, etc.
      String last4 = '';
      if (raw is Map) {
        last4 = (raw['last4'] ?? raw['lastFour'] ?? raw['last_four'] ?? '')
            .toString();
        if (last4.isEmpty) {
          final masked =
              (raw['maskedPan'] ?? raw['masked_pan'] ?? '').toString();
          if (masked.isNotEmpty) {
            final digits =
                RegExp(r'(\d{4})$').firstMatch(masked)?.group(1) ?? '';
            if (digits.isNotEmpty) last4 = digits;
          }
        }
        if (last4.isEmpty) {
          final number = (raw['number'] ?? raw['pan'] ?? '').toString();
          if (number.length >= 4) last4 = number.substring(number.length - 4);
        }
      }
      if (last4.isEmpty) last4 = '****';

      return {
        'id': id,
        'label': label,
        'status': status,
        'currency': currency,
        'last4': last4,
        'brand': brand,
        'createdAt': s(
            raw is Map
                ? (raw['createdAt'] ?? raw['created'] ?? raw['created_at'])
                : '',
            ''),
        'availableBalance': s(
            raw is Map ? (raw['availableBalance'] ?? raw['balance']) : '', ''),
        'statementUrl': s(raw is Map ? (raw['statementUrl']) : '', ''),
      };
    }

    return items.map<Map<String, dynamic>>(mapOne).toList();
  }

  /// Create/request a card (**amount in MAJOR units**). Never triggers KYC here.
  static Future<Map<String, dynamic>> createCard(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    await ensureInitialized();

    // Pull canonical user
    final me = await _getMe();
    final meEmail = (me['email'] ?? '').toString().trim();

    final reqEmail = meEmail.isNotEmpty
        ? meEmail
        : (payload['email'] ?? '').toString().trim();

    String firstName = (payload['firstName'] ?? '').toString().trim();
    String lastName = (payload['lastName'] ?? '').toString().trim();

    if (firstName.isEmpty &&
        (me['first_name'] ?? '').toString().trim().isNotEmpty) {
      firstName = (me['first_name'] ?? '').toString().trim();
    }
    if (lastName.isEmpty &&
        (me['last_name'] ?? '').toString().trim().isNotEmpty) {
      lastName = (me['last_name'] ?? '').toString().trim();
    }
    if (firstName.isEmpty &&
        lastName.isEmpty &&
        (me['username'] ?? '').toString().trim().isNotEmpty) {
      final u = (me['username'] as String).trim();
      final parts = u.split(RegExp(r'\s+'));
      firstName = parts.isNotEmpty ? parts.first : 'User';
      lastName = parts.length > 1 ? parts.sublist(1).join(' ') : 'Osvan';
    }

    // If caller passed amountCents explicitly, convert back to major.
    if (payload['amountCents'] != null) {
      final ac = payload['amountCents'];
      final cents = (ac is num) ? ac : num.tryParse(ac.toString());
      if (cents != null) {
        final amountMajor = (cents / 100.0);
        final body = <String, dynamic>{
          'customerEmail': reqEmail,
          'cardBrand': (payload['brand'] ?? 'visa').toString().toLowerCase(),
          'cardType': (payload['type'] ?? 'virtual').toString().toLowerCase(),
          'reference': payload['reference'],
          'amount': double.parse(amountMajor.toStringAsFixed(2)), // MAJOR
          'firstName': firstName,
          'lastName': lastName,
        };
        return _postCreate(body, idempotencyKey);
      }
    }

    // Otherwise, accept major units and send as-is
    num? amountMajor;
    if (payload['amount'] != null) {
      final a = payload['amount'];
      amountMajor = (a is num) ? a : num.tryParse(a.toString());
    }
    if (amountMajor == null) {
      throw {
        'message': 'Amount is required',
        'detail': 'Provide amount in major units (e.g., 25.00).'
      };
    }
    final double amountMajor2dp =
        double.parse(amountMajor.toStringAsFixed(2));

    final body = <String, dynamic>{
      'customerEmail': reqEmail,
      'cardBrand': (payload['brand'] ?? 'visa').toString().toLowerCase(),
      'cardType': (payload['type'] ?? 'virtual').toString().toLowerCase(),
      'reference': payload['reference'],
      'amount': amountMajor2dp, // MAJOR units (no cents conversion)
      'firstName': firstName,
      'lastName': lastName,
    };

    return _postCreate(body, idempotencyKey);
  }

  /// Backwards-compatible alias (so older calls keep working).
  static Future<Map<String, dynamic>> requestCard(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) =>
      createCard(payload, idempotencyKey: idempotencyKey);

  /// NEW: Convenience wrapper with the exact named parameters used by CreateCardView.
  static Future<Map<String, dynamic>> requestCardFields({
    required String customerEmail,
    required String cardBrand,
    required String cardType,
    required String currency, // currently not used by backend, kept for future
    required num amountMajor, // will be converted to cents
    required String firstName,
    required String lastName,
    String? reference,
    String? idempotencyKey,
  }) {
    return createCard({
      'email': customerEmail,
      'brand': cardBrand,
      'type': cardType,
      'currency': currency,
      'amount': amountMajor,
      'firstName': firstName,
      'lastName': lastName,
      'reference': reference,
    }, idempotencyKey: idempotencyKey);
  }

  /// Reveal card details using a short-lived ticket.
  static Future<Map<String, dynamic>> revealCard({
    required String cardId,
    required String ticket,
  }) async {
    final api = await ApiClient.ensureInitialized();
    final res = await api.dio.post(
      '/api/cards/$cardId/reveal/',
      data: {'ticket': ticket},
    );
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> _postCreate(
    Map<String, dynamic> body,
    String? idempotencyKey,
  ) async {
    try {
      final res = await I._dio
          .post(_request(), data: body, options: _withIdem(idempotencyKey));
      final data = res.data;

      if (data is Map) {
        final err = (data['error'] ?? '').toString().trim();
        if (err.isNotEmpty) {
          throw {
            'message': err,
            'status': res.statusCode,
            'providerMessage': data['providerMessage'] ?? data['reason'],
            'errors': data['errors'] ?? data['fields'],
          };
        }
        final okField = data['ok'];
        final isOk = okField == true || okField == 'true' || okField == 1;
        if (isOk) return Map<String, dynamic>.from(data);
      }

      final sc = res.statusCode ?? 200;
      if (sc >= 200 && sc < 300) return {'ok': true, 'raw': data};

      throw {'message': 'Card request failed', 'status': res.statusCode};
    } on DioException catch (e) {
      final map = <String, dynamic>{
        'message': 'Card request failed',
        'status': e.response?.statusCode,
      };
      final d = e.response?.data;
      if (d is Map) {
        map['detail'] = d['detail'] ?? d['message'] ?? d['error'];
        map['providerMessage'] = d['providerMessage'] ?? d['reason'];
        map['errors'] = d['errors'] ?? d['fields'];
      } else if (d != null) {
        map['detail'] = d.toString();
      } else if (e.message != null) {
        map['detail'] = e.message!;
      }
      throw map;
    }
  }

  static Future<void> freezeCard(String id) async {
    await ensureInitialized();
    await I._dio.post(_freeze(id));
  }

  static Future<void> unfreezeCard(String id) async {
    await ensureInitialized();
    await I._dio.post(_unfreeze(id));
  }

  static Future<void> terminateCard(String id) async {
    await ensureInitialized();
    await I._dio.post(_terminate(id));
  }

  /// Fetch a single card (masked details)
  static Future<Map<String, dynamic>> fetchCard(String id) async {
    await ensureInitialized();
    final res = await I._dio.get(_fetch(id));
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : {'raw': data};
  }

  /// List card transactions (tolerant to provider/data shapes)
  static Future<List<Map<String, dynamic>>> getCardTransactions(
    String id, {
    int page = 1,
    int take = 50,
  }) async {
    await ensureInitialized();
    final res = await I._dio
        .get(_txns(id), queryParameters: {'page': page, 'take': take});
    final data = res.data;

    List items;
    if (data is Map &&
        data['data'] is Map &&
        (data['data']['cardTransactions'] is List)) {
      items = data['data']['cardTransactions'] as List;
    } else if (data is Map && data['results'] is List) {
      items = data['results'] as List;
    } else if (data is List) {
      items = data;
    } else {
      items = const <dynamic>[];
    }

    return items.map<Map<String, dynamic>>((raw) {
      return Map<String, dynamic>.from(raw is Map ? raw : {'raw': raw});
    }).toList();
  }

  /// View PIN – tolerant to {pin:'1234'} or {data:{pin:'1234'}} etc.
  static Future<String> getCardPin(String id) async {
    await ensureInitialized();
    final res = await I._dio.get(_pin(id));
    final data = res.data;

    if (data is Map) {
      if (data['pin'] != null) return data['pin'].toString();
      if (data['data'] is Map && (data['data']['pin'] != null)) {
        return data['data']['pin'].toString();
      }
      if (data['result'] is Map && (data['result']['pin'] != null)) {
        return data['result']['pin'].toString();
      }
    }
    return data?.toString() ?? '****';
  }

  // ─────────────────────────── Cents-first money ops ───────────────────────────
  static Future<Map<String, dynamic>> topUpSimple({
    required String cardId,
    required int amountCents,
    String currency = 'USD',
    String? reference,
    String? idempotencyKey,
  }) async {
    await ensureInitialized();
    final body = {
      'cardId': cardId,
      'amount': amountCents,
      'currency': currency.toUpperCase(),
      if (reference != null) 'reference': reference,
    };
    final res = await I._dio
        .post(_topupSimple(), data: body, options: _withIdem(idempotencyKey));
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : {'raw': data};
  }

  static Future<Map<String, dynamic>> topUpByPath({
    required String cardId,
    required int amountCents,
    String currency = 'USD',
    String? reference,
    String? idempotencyKey,
  }) async {
    await ensureInitialized();
    final body = {
      'amount': amountCents,
      'currency': currency.toUpperCase(),
      if (reference != null) 'reference': reference,
    };
    final res = await I._dio.post(_topupPath(cardId),
        data: body, options: _withIdem(idempotencyKey));
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : {'raw': data};
  }

  static Future<Map<String, dynamic>> withdrawSimple({
    required String cardId,
    String currency = 'USD',
    int? amountCents,
    bool closeCard = false,
    String? idempotencyKey,
  }) async {
    await ensureInitialized();
    final body = {
      'cardId': cardId,
      'currency': currency.toUpperCase(),
      if (amountCents != null) 'amount': amountCents,
      if (closeCard) 'close_card': true,
    };
    final res = await I._dio.post(_withdrawSimple(),
        data: body, options: _withIdem(idempotencyKey));
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : {'raw': data};
  }

  static Future<Map<String, dynamic>> withdrawByPath({
    required String cardId,
    String currency = 'USD',
    int? amountCents,
    bool closeCard = false,
    String? idempotencyKey,
  }) async {
    await ensureInitialized();
    final body = {
      'currency': currency.toUpperCase(),
      if (amountCents != null) 'amount': amountCents,
      if (closeCard) 'close_card': true,
    };
    final res = await I._dio.post(_withdrawPath(cardId),
        data: body, options: _withIdem(idempotencyKey));
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : {'raw': data};
  }

  static Future<Map<String, dynamic>> providerTopUp({
    required String cardId,
    required int amountCents,
    String currency = 'USD',
    String? reference,
    String? idempotencyKey,
  }) async {
    await ensureInitialized();
    final body = {
      'amount_cents': amountCents,
      'currency': currency.toUpperCase(),
      if (reference != null) 'reference': reference,
    };
    final res = await I._dio.post(_provTopup(cardId),
        data: body, options: _withIdem(idempotencyKey));
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : {'raw': data};
  }

  static Future<Map<String, dynamic>> providerWithdraw({
    required String cardId,
    required int amountCents,
    String currency = 'USD',
    String? reference,
    String? idempotencyKey,
  }) async {
    await ensureInitialized();
    final body = {
      'amount_cents': amountCents,
      'currency': currency.toUpperCase(),
      if (reference != null) 'reference': reference,
    };
    final res = await I._dio.post(_provWithdraw(cardId),
        data: body, options: _withIdem(idempotencyKey));
    final data = res.data;
    return (data is Map<String, dynamic>) ? data : {'raw': data};
  }
}
