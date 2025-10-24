class CardModel {
  /// Use String so we’re safe for UUID/provider ids.
  final String id;
  final String type; // e.g., "virtual" | "giftcard"
  final String provider; // e.g., "visa" | "mastercard"
  final String balance; // human-friendly (e.g., "USD 12.00" or "₦10,000")
  final String number; // masked or last4-based "**** **** **** 1234"
  final String expiry; // "MM/YY"
  final bool frozen; // true if card is frozen

  CardModel({
    required this.id,
    required this.type,
    required this.provider,
    required this.balance,
    required this.number,
    required this.expiry,
    required this.frozen,
  });

  /// Flexible JSON adapter:
  /// - id: "id" | "provider_id" | numeric id -> string
  /// - type: "type" | "cardType"
  /// - provider: "provider" | "brand" | "cardBrand"
  /// - balance: "balance" (string or number) + "currency" fallback
  /// - number: "number" | "pan" | "last4" (masked)
  /// - expiry: "expiry" | "expiryDate" | "exp"
  /// - frozen: bool or status == "frozen"
  factory CardModel.fromJson(Map<String, dynamic> json) {
    String str(dynamic v) => (v ?? '').toString();

    // ---- id ----
    final rawId = json['id'] ?? json['provider_id'];
    final id = str(rawId).isEmpty ? str(json['pk']) : str(rawId);

    // ---- provider / brand ----
    final provider = str(json['provider'].toString().isNotEmpty
            ? json['provider']
            : (json['brand'] ?? json['cardBrand'] ?? ''))
        .toLowerCase();

    // ---- type ----
    final type = str(json['type'].toString().isNotEmpty
            ? json['type']
            : (json['cardType'] ?? ''))
        .toLowerCase();

    // ---- number/last4 (masked) ----
    final numberRaw = str(json['number'].toString().isNotEmpty
        ? json['number']
        : (json['pan'] ?? json['cardNumber'] ?? ''));
    final last4 = str(json['last4']);
    String number;
    if (numberRaw.isNotEmpty && numberRaw.contains('****')) {
      number = numberRaw;
    } else if (last4.isNotEmpty) {
      number = '**** **** **** $last4';
    } else if (numberRaw.length >= 4) {
      number = '**** **** **** ${numberRaw.substring(numberRaw.length - 4)}';
    } else {
      number = '**** **** **** ****';
    }

    // ---- expiry ----
    final expiry = str(json['expiry'].toString().isNotEmpty
        ? json['expiry']
        : (json['expiryDate'] ?? json['exp'] ?? '00/00'));

    // ---- balance (stringify) ----
    String balance;
    final bal = json['balance'];
    final currency = str(json['currency']).toUpperCase();
    if (bal == null || str(bal).isEmpty) {
      balance = currency.isNotEmpty ? '$currency 0.00' : '0.00';
    } else if (bal is num) {
      balance = currency.isNotEmpty
          ? '$currency ${bal.toStringAsFixed(2)}'
          : bal.toString();
    } else {
      // already string from backend
      balance = str(bal);
    }

    // ---- frozen ----
    bool frozen;
    if (json['frozen'] is bool) {
      frozen = json['frozen'] as bool;
    } else {
      final status = str(json['status']).toLowerCase();
      frozen = status == 'frozen';
    }

    return CardModel(
      id: id.isEmpty ? 'unknown' : id,
      type: type.isEmpty ? 'virtual' : type,
      provider: provider.isEmpty ? 'visa' : provider,
      balance: balance,
      number: number,
      expiry: expiry,
      frozen: frozen,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'provider': provider,
        'balance': balance,
        'number': number,
        'expiry': expiry,
        'frozen': frozen,
      };
}
