import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/cards/services/card_service.dart';

class CreateCardView extends StatefulWidget {
  const CreateCardView({super.key});

  @override
  State<CreateCardView> createState() => _CreateCardViewState();
}

class _CreateCardViewState extends State<CreateCardView> {
  final _formKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _amount = TextEditingController();
  String _brand = 'visa';
  String _type = 'virtual';

  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _amount.dispose();
    super.dispose();
  }

  String _uuidV4() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant
    String p(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${p(0)}${p(1)}${p(2)}${p(3)}-'
        '${p(4)}${p(5)}-'
        '${p(6)}${p(7)}-'
        '${p(8)}${p(9)}-'
        '${p(10)}${p(11)}${p(12)}${p(13)}${p(14)}${p(15)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final body = {
      // Brails create expects these fields (our backend will proxy):
      // customerEmail, cardBrand, cardType, amount, reference (+ first/last name in sandbox)
      'customerEmail': _email.text.trim(),
      'cardBrand': _brand,
      'cardType': _type, // e.g., "virtual" or "giftcard"
      'amount': double.tryParse(_amount.text.trim()) ?? 0,
      'reference': _uuidV4(),
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
    };

    try {
      await CardService.requestNewCard(body: body);
      if (mounted) {
        Get.snackbar('Success', 'Card request submitted',
            snackPosition: SnackPosition.BOTTOM);
        Navigator.pop(context, true);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brands = const ['visa', 'mastercard'];
    final types = const ['virtual', 'giftcard'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Card'),
        backgroundColor: osvanGreen,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Customer Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Email is required';
                  final ok = RegExp(r'^\S+@\S+\.\S+$').hasMatch(value);
                  if (!ok) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _brand,
                      items: brands
                          .map((b) => DropdownMenuItem(
                              value: b, child: Text(b.toUpperCase())))
                          .toList(),
                      onChanged: (v) => setState(() => _brand = v ?? 'visa'),
                      decoration:
                          const InputDecoration(labelText: 'Card Brand'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _type,
                      items: types
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t.toUpperCase())))
                          .toList(),
                      onChanged: (v) => setState(() => _type = v ?? 'virtual'),
                      decoration: const InputDecoration(labelText: 'Card Type'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(labelText: 'Load Amount'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstName,
                decoration: const InputDecoration(
                    labelText: 'First Name (sandbox required)'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Required in sandbox' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastName,
                decoration: const InputDecoration(
                    labelText: 'Last Name (sandbox required)'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Required in sandbox' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_card),
                  label: Text(_submitting ? 'Submitting...' : 'Create Card'),
                  style: ElevatedButton.styleFrom(backgroundColor: osvanGreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
