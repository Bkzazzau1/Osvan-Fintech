// lib/screen/debug/health_test_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:osvan_app/config/api.dart'; // baseUrlProvider + helpers

Future<String> pingHealthRaw(String base) async {
  // try /api/v1/health/ then fallback to /api/health/
  final urlV1 = apiUri(base, '/health/');
  final resV1 = await http.get(urlV1, headers: {'Accept': 'application/json'});

  if (resV1.statusCode == 200) {
    final body = json.decode(resV1.body);
    return body['status']?.toString() ?? 'ok';
  }

  final urlLegacy = apiUri(base, '/health/');
  final resLegacy =
      await http.get(urlLegacy, headers: {'Accept': 'application/json'});
  if (resLegacy.statusCode == 200) {
    final body = json.decode(resLegacy.body);
    return body['status']?.toString() ?? 'ok';
  }

  return 'err ${resV1.statusCode}';
}

class HealthTestPage extends ConsumerStatefulWidget {
  const HealthTestPage({super.key});
  @override
  ConsumerState<HealthTestPage> createState() => _HealthTestPageState();
}

class _HealthTestPageState extends ConsumerState<HealthTestPage> {
  String _result = 'tap to ping';

  Future<void> _doPing() async {
    setState(() => _result = 'pinging...');
    try {
      final base = ref.read(baseUrlProvider);
      final status = await pingHealthRaw(base);
      setState(() => _result = status); // expect "ok"
    } catch (e) {
      setState(() => _result = 'err $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Test')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _doPing,
              child: const Text('Ping /health'),
            ),
            const SizedBox(height: 12),
            Text(_result, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
