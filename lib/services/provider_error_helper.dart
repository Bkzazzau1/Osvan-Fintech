// lib/services/provider_error_helper.dart
// Detect "already exists / already indexed" responses.
// Used to make provider calls idempotent on Flutter side.

bool looksLikeAlreadyExists(dynamic data) {
  if (data == null) return false;

  String text = '';

  if (data is String) {
    text = data;
  } else if (data is Map) {
    final parts = <String>[
      '${data['message'] ?? ''}',
      '${data['error'] ?? ''}',
      '${data['detail'] ?? ''}',
      '${data['statusCode'] ?? ''}',
      '${data['errors'] ?? ''}',
    ];
    text = parts.join(' ');
  } else {
    text = data.toString();
  }

  final t = text.toLowerCase();

  return t.contains('already indexed') ||
      t.contains('already exist') ||
      t.contains('already exists') ||
      t.contains('already registered') ||
      t.contains('duplicate');
}
