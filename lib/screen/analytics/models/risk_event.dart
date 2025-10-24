class RiskEvent {
  final String id;
  final String type;
  final String createdAt; // keep as ISO string for now
  final String? userId;
  final String? provider;
  final String? country;
  final Map<String, dynamic>? metadata;

  RiskEvent({
    required this.id,
    required this.type,
    required this.createdAt,
    this.userId,
    this.provider,
    this.country,
    this.metadata,
  });

  factory RiskEvent.fromJson(Map<String, dynamic> json) {
    return RiskEvent(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      userId: (json['user_id'] as String?),
      provider: (json['provider'] as String?),
      country: (json['country'] as String?),
      metadata: (json['metadata'] is Map)
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }
}
