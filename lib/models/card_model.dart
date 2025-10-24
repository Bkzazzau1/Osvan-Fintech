class CardModel {
  final int id;
  final String type;
  final String provider;
  final String balance;
  final String number;
  final String expiry;
  final bool frozen;

  CardModel({
    required this.id,
    required this.type,
    required this.provider,
    required this.balance,
    required this.number,
    required this.expiry,
    required this.frozen,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      provider: json['provider'] ?? '',
      balance: json['balance'] ?? '₦0.00',
      number: json['number'] ?? '**** **** **** ****',
      expiry: json['expiry'] ?? '00/00',
      frozen: json['frozen'] ?? false,
    );
  }
}
