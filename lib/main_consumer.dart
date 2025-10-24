import 'package:flutter/material.dart';

void main() => runApp(const ConsumerApp());

class ConsumerApp extends StatelessWidget {
  const ConsumerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Osvan',
      home: _CustomerHome(),
    );
  }
}

class _CustomerHome extends StatelessWidget {
  const _CustomerHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Osvan – Customer App')),
    );
  }
}
