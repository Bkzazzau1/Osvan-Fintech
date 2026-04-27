// lib/screen/crypto/widgets/send_sheet.dart
// Luxury glass send sheet (Option-B rails) + PIN confirm.
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/controller/crypto_controller.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/widgets/luxury_background.dart';

const kCryptoSurface = Color(0xFF0F172A);
const kIceBlue = Color(0xFF60A5FA);

class SendSheet extends StatefulWidget {
  final CryptoController controller;
  final String ticker;
  final String network;
  const SendSheet({
    super.key,
    required this.controller,
    required this.ticker,
    required this.network,
  });

  @override
  State<SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<SendSheet> {
  final _formKey = GlobalKey<FormState>();

  // Option B rails:
  // USDT: TRON, BSC
  // USDC: TRON, ETH
  final _coin = ValueNotifier<String>('USDT');
  final _chain = ValueNotifier<String>('TRON');

  final _toCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();

  bool _localSubmitting = false;

  static const Map<String, List<String>> _networksByCoin = {
    'USDT': ['TRON', 'BSC'],
    'USDC': ['TRON', 'ETH'],
  };

  List<String> get _networks => _networksByCoin[_coin.value] ?? const ['TRON'];

  @override
  void initState() {
    super.initState();
    _coin.value = widget.ticker.toUpperCase();
    _chain.value = widget.network.toUpperCase();

    _coin.addListener(() {
      final nets = _networks;
      if (!nets.contains(_chain.value)) _chain.value = nets.first;
    });
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _amtCtrl.dispose();
    _coin.dispose();
    _chain.dispose();
    super.dispose();
  }

  String? _validateAddress(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter recipient address';

    final net = _chain.value.toUpperCase();
    if (net == 'TRON') {
      if (!s.startsWith('T') || s.length < 30 || s.length > 45) {
        return 'Invalid TRON address format';
      }
    } else if (net == 'BSC' || net == 'ETH') {
      final rx = RegExp(r'^0x[a-fA-F0-9]{40}$');
      if (!rx.hasMatch(s)) return 'Invalid $net address format';
    }
    return null;
  }

  String? _validateAmount(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter amount';
    final n = num.tryParse(s);
    if (n == null || n <= 0) return 'Enter a valid amount';
    return null;
  }

  Future<String?> _askForPin(BuildContext context) async {
    final pinCtrl = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          String? error;

          return StatefulBuilder(
            builder: (ctx2, setState) {
              return AlertDialog(
                backgroundColor: kCryptoSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: const Text(
                  'Confirm with PIN',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: pinCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: '4-digit PIN',
                        labelStyle:
                            TextStyle(color: Colors.white.withOpacity(0.75)),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.12)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: osvanGreen, width: 1.2),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        error!,
                        style: const TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx2).pop(null),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: osvanGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final v = pinCtrl.text.trim();
                      if (v.length != 4) {
                        setState(() => error = 'PIN must be 4 digits');
                        return;
                      }
                      Navigator.of(ctx2).pop(v);
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      pinCtrl.dispose();
    }
  }

  Future<void> _submit() async {
    if (_localSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final coin = _coin.value;
    final chain = _chain.value;
    final to = _toCtrl.text.trim();
    final amount = _amtCtrl.text.trim();

    final allowed = _networksByCoin[coin] ?? const [];
    if (!allowed.contains(chain)) {
      Get.snackbar(
        'Unsupported network',
        '$coin on $chain is not supported.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final pin = await _askForPin(context);
    if (pin == null) return;

    setState(() => _localSubmitting = true);
    try {
      final res = await widget.controller.sendFlow(
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

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: kCryptoSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Send $status',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$coin • $chain',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (ref.isNotEmpty)
                Text('Ref: $ref',
                    style: TextStyle(color: Colors.white.withOpacity(0.75))),
              if (ref.isNotEmpty) const SizedBox(height: 10),
              Text('Platform fee: $platformFee',
                  style: TextStyle(color: Colors.white.withOpacity(0.75))),
              Text('Network fee:  $networkFee',
                  style: TextStyle(color: Colors.white.withOpacity(0.75))),
              Text('Total debit:  $totalDebit',
                  style: TextStyle(color: Colors.white.withOpacity(0.75))),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (status == 'PENDING' || status == 'CONFIRMED' || status == 'ON_HOLD') {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Send failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) setState(() => _localSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withOpacity(0.7);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          const Positioned.fill(child: LuxuryBackground()),
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
          ),
          Obx(() {
            final sending = widget.controller.isSending.value;
            final disabled = sending || _localSubmitting;

            final border = OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            );

            InputDecoration dec(String label) => InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.72)),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide:
                        const BorderSide(color: osvanGreen, width: 1.2),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                );

            return Padding(
              padding: const EdgeInsets.all(6),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Handle(),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Send stablecoin',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _Pill(text: 'SECURE', color: const Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _DropdownRow(
                                  label: 'Coin',
                                  valueListenable: _coin,
                                  items: const ['USDT', 'USDC'],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ValueListenableBuilder<String>(
                                  valueListenable: _coin,
                                  builder: (_, __, ___) {
                                    final nets = _networks;
                                    if (!nets.contains(_chain.value)) {
                                      _chain.value = nets.first;
                                    }
                                    return _DropdownRow(
                                      label: 'Network',
                                      valueListenable: _chain,
                                      items: nets,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ValueListenableBuilder<String>(
                            valueListenable: _chain,
                            builder: (_, net, __) => TextFormField(
                              controller: _toCtrl,
                              decoration: dec('Recipient address ()'),
                              validator: _validateAddress,
                              enabled: !disabled,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _amtCtrl,
                            decoration: dec('Amount'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: _validateAmount,
                            enabled: !disabled,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: disabled ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: osvanGreen,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: (sending || _localSubmitting)
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Send',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fees are calculated server-side. Quote TTL 90s.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: muted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 4,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final ValueListenable<String> valueListenable;
  final List<String> items;
  const _DropdownRow({
    required this.label,
    required this.valueListenable,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
    );

    return ValueListenableBuilder<String>(
      valueListenable: valueListenable,
      builder: (_, value, __) => DropdownButtonFormField<String>(
        key: ValueKey('$label-${items.join(",")}'),
        value: items.contains(value) ? value : items.first,
        dropdownColor: kCryptoSurface,
        iconEnabledColor: Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.72)),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: osvanGreen, width: 1.2),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        items: items
            .map((e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(e),
                ))
            .toList(),
        onChanged: (v) {
          if (valueListenable is ValueNotifier<String> && v != null) {
            (valueListenable as ValueNotifier<String>).value = v;
          }
        },
      ),
    );
  }
}
