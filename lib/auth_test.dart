// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:http/http.dart' as http;

Future<void> testEmailLogin() async {
  final uri = Uri.parse('https://fintech.osvan.africa/api/token/');
  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': 'admin2@osvan.africa',
      'password': 'Bk61796612#',
    }),
  );

  print('status: ${res.statusCode}');
  print('body: ${res.body}');
}
