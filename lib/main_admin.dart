import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:osvan_app/screen/analytics/dashboard_screen.dart'; // your existing screen

void main() => runApp(const ProviderScope(child: AdminApp()));

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Osvan Ops',
      home: DashboardScreen(), // analytics UI
    );
  }
}
