// lib/models/user_me.dart
class UserMe {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;

  UserMe({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
  });

  factory UserMe.fromMap(Map<String, dynamic> m) => UserMe(
        id: m['id'] as int,
        username: (m['username'] ?? '').toString(),
        email: (m['email'] ?? '').toString(),
        firstName: (m['first_name'] ?? '').toString(),
        lastName: (m['last_name'] ?? '').toString(),
      );

  String get displayName => firstName.isNotEmpty
      ? firstName
      : (username.isNotEmpty ? username : email);
}
