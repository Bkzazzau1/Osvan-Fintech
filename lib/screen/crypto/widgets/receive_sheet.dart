import 'package:flutter/foundation.dart'; // for ValueListenable / ValueNotifier
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/controller/crypto_controller.dart';


class ReceiveSheet extends StatefulWidget {
  final CryptoController controller;
  const ReceiveSheet({super.key, required this.controller});

  @override
  State<ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<ReceiveSheet> {
  final _coin = ValueNotifier<String>('USDT');
  final _chain = ValueNotifier<String>('TRON');
  String? _address;
  String? _tag;
  String? _provider;
  bool _loading = false;

  @override
  void dispose() {
    _coin.dispose();
    _chain.dispose();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    setState(() => _loading = true);
    try {
      final res = await widget.controller.getAddress(
        coin: _coin.value,
        chain: _chain.value,
      );
      setState(() {
        _address = (res['address'] ?? '').toString();
        _tag = res['tag']?.toString();
        _provider = (res['provider'] ?? 'Brails').toString();
      });
    } catch (e) {
      Get.snackbar('Failed to load address', e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String? text, String label) async {
    if (text == null || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    Get.snackbar('Copied', '$label copied to clipboard',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Receive Stablecoin',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Coin + Chain selectors
        Row(
          children: [
            Expanded(
              child: _Dropdown(
                label: 'Coin',
                valueListenable: _coin,
                items: const ['USDT', 'USDC'],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Dropdown(
                label: 'Chain',
                valueListenable: _chain,
                items: const ['TRON'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Get address button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _loadAddress,
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Get Deposit Address'),
          ),
        ),
        const SizedBox(height: 12),

        if (_address != null && _address!.isNotEmpty) ...[
          _Line(label: 'Provider', value: _provider ?? 'Brails'),
          const SizedBox(height: 8),
          _CopyBox(
            label: 'Address',
            value: _address!,
            onCopy: () => _copy(_address, 'Address'),
          ),
          if (_tag != null && _tag!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CopyBox(
              label: 'Tag/Memo',
              value: _tag!,
              onCopy: () => _copy(_tag, 'Tag/Memo'),
            ),
          ],

          const SizedBox(height: 12),
          const Text(
            'Send only the selected coin on the selected chain. '
            'Deposits are credited after network confirmations.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),

          // Optional QR: if you already use qr_flutter, you can add it here.
          // Padding(
          //   padding: const EdgeInsets.only(top: 12),
          //   child: QrImageView(data: _address!, size: 160, backgroundColor: Colors.white),
          // ),
        ],
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final ValueListenable<String> valueListenable;
  final List<String> items;
  const _Dropdown(
      {required this.label,
      required this.valueListenable,
      required this.items});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: valueListenable,
      builder: (_, value, __) => InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
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
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(color: Colors.white70)),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _CopyBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;
  const _CopyBox(
      {required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy, color: Colors.white70),
                tooltip: 'Copy',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
