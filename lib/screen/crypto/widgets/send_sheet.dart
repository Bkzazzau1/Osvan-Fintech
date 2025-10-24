import 'package:flutter/foundation.dart'; // for ValueListenable / ValueNotifier
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/controller/crypto_controller.dart';


class SendSheet extends StatefulWidget {
  final CryptoController controller;
  const SendSheet({super.key, required this.controller});

  @override
  State<SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<SendSheet> {
  final _formKey = GlobalKey<FormState>();
  final _coin = ValueNotifier<String>('USDT');
  final _chain = ValueNotifier<String>('TRON');
  final _toCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  @override
  void dispose() {
    _toCtrl.dispose();
    _amtCtrl.dispose();
    _pinCtrl.dispose();
    _coin.dispose();
    _chain.dispose();
    super.dispose();
  }

  String? _validateAddress(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter recipient address';
    // Light TRON check: starts with 'T' and plausible length; server does real validation
    if (!_chain.value.toUpperCase().contains('TRON')) return null;
    if (!s.startsWith('T') || s.length < 30 || s.length > 45) {
      return 'Invalid TRON address format';
    }
    return null;
  }

  String? _validateAmount(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter amount';
    final num? n = num.tryParse(s);
    if (n == null || n <= 0) return 'Enter a valid amount';
    return null;
  }

  String? _validatePin(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter your PIN';
    if (s.length < 4) return 'PIN must be at least 4 digits';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final c = widget.controller;
    final coin = _coin.value;
    final chain = _chain.value;
    final to = _toCtrl.text.trim();
    final amount = _amtCtrl.text.trim();
    final pin = _pinCtrl.text.trim();

    try {
      final res = await c.sendFlow(
        coin: coin,
        chain: chain,
        amount: amount,
        to: to,
        pinOrBio: pin,
      );

      if (!mounted) return;
      final status = (res['status'] ?? '').toString();
      final ref = (res['ref'] ?? '').toString();
      final platformFee = (res['platform_fee'] ?? '').toString();
      final networkFee = (res['network_fee'] ?? '').toString();
      final totalDebit = (res['total_debit'] ?? '').toString();

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Send $status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ref.isNotEmpty) Text('Ref: $ref'),
              const SizedBox(height: 8),
              Text('Platform fee: $platformFee'),
              Text('Network fee:  $networkFee'),
              Text('Total debit:  $totalDebit'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );

      // Close sheet on success-like statuses
      if (status == 'PENDING' || status == 'CONFIRMED' || status == 'ON_HOLD') {
        Navigator.of(context).maybePop();
      }
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      Get.snackbar('Send failed', msg,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Obx(() {
      final sending = c.isSending.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Send Stablecoin',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                // Coin
                _DropdownRow(
                  label: 'Coin',
                  valueListenable: _coin,
                  items: const [
                    'USDT',
                    'USDC'
                  ], // UI can show both; server enforces enabled list
                ),
                const SizedBox(height: 8),
                // Chain
                _DropdownRow(
                  label: 'Chain',
                  valueListenable: _chain,
                  items: const ['TRON'],
                ),
                const SizedBox(height: 8),
                // To Address
                TextFormField(
                  controller: _toCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Recipient address (TRON)'),
                  validator: _validateAddress,
                  enabled: !sending,
                ),
                const SizedBox(height: 8),
                // Amount
                TextFormField(
                  controller: _amtCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Amount'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: _validateAmount,
                  enabled: !sending,
                ),
                const SizedBox(height: 8),
                // PIN
                TextFormField(
                  controller: _pinCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('PIN (4+ digits)'),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  validator: _validatePin,
                  enabled: !sending,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: sending ? null : _submit,
                    child: sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send'),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fees are calculated server-side. Quote TTL 90s.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final ValueListenable<String> valueListenable;
  final List<String> items;
  const _DropdownRow(
      {required this.label,
      required this.valueListenable,
      required this.items});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: valueListenable,
      builder: (_, value, __) => Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: value,
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              if (valueListenable is ValueNotifier<String> && v != null) {
                (valueListenable as ValueNotifier<String>).value = v;
              }
            },
          ),
        ],
      ),
    );
  }
}
