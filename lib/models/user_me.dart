// lib/models/user_me.dart
class UserMe {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String avatarUrl;

  UserMe({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
  });

  factory UserMe.fromMap(Map<String, dynamic> m) => UserMe(
        id: m['id'] as int,
        username: (m['username'] ?? '').toString(),
        email: (m['email'] ?? '').toString(),
        firstName: (m['first_name'] ?? '').toString(),
        lastName: (m['last_name'] ?? '').toString(),
        avatarUrl: _pickString(m, [
          'avatar',
          'photo',
          'image',
          'profile_image',
          'profileImage',
          'profilePhoto',
          'picture',
        ]),
      );

  String get displayName => firstName.isNotEmpty
      ? firstName
      : (username.isNotEmpty ? username : email);

  static String _pickString(Map<String, dynamic> m, List<String> keys) {
    for (final key in keys) {
      final value = m[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }
}
