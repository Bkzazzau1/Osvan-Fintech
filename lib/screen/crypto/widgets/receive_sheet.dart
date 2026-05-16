// lib/screen/crypto/widgets/receive_sheet.dart
// Luxury glass receive sheet (Option-B rails) + QR + checksum warnings
// - QR preview (requires qr_flutter)
// - Address "sanity" checks + network mismatch warnings
// - Copy + Share actions
//
// IMPORTANT:
// Add this to pubspec.yaml:
//
// dependencies:
//   qr_flutter: ^4.1.0
//
// Then run: flutter pub get
//
// ignore_for_file: deprecated_member_use, unused_element

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/controller/crypto_controller.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/widgets/luxury_background.dart';
import 'package:qr_flutter/qr_flutter.dart';

const kCryptoSurface = Color(0xFF0F172A);
const kIceBlue = Color(0xFF60A5FA);

class ReceiveSheet extends StatefulWidget {
  final CryptoController controller;
  final String ticker;
  final String network;

  const ReceiveSheet({
    super.key,
    required this.controller,
    required this.ticker,
    required this.network,
  });

  @override
  State<ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<ReceiveSheet> {
  // Option-B:
  // USDT: TRON, BSC
  // USDC: TRON, ETH
  final _coin = ValueNotifier<String>('USDT');
  final _chain = ValueNotifier<String>('TRON');

  String? _address;
  String? _tag;
  bool _loading = false;

  // Temporary in-memory cache (coin::chain -> {address, tag})
  static final Map<String, Map<String, String?>> _cache = {};

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
      if (!nets.contains(_chain.value)) {
        _chain.value = nets.first;
      }
      if (!mounted) return;
      setState(() {
        _address = null;
        _tag = null;
      });
    });

    // Auto-fetch on open
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAddress());
  }

  @override
  void dispose() {
    _coin.dispose();
    _chain.dispose();
    super.dispose();
  }

  String _key(String coin, String chain) =>
      '${coin.toUpperCase()}::${chain.toUpperCase()}';

  Future<void> _loadAddress({bool force = false}) async {
    if (_loading) return;

    setState(() => _loading = true);
    try {
      final k = _key(_coin.value, _chain.value);

      // 1) Reuse cache unless force refresh
      if (!force && _cache.containsKey(k)) {
        final cached = _cache[k]!;
        setState(() {
          _address = (cached['address'] ?? '').toString();
          _tag = cached['tag']?.toString();
        });
        return;
      }

      // 2) Fetch from backend
      final res = await widget.controller.getAddress(
        coin: _coin.value,
        chain: _chain.value,
      );

      final addr = (res['address'] ?? '').toString();
      final tag = res['tag']?.toString();

      // 3) Save to cache
      _cache[k] = {'address': addr, 'tag': tag};

      setState(() {
        _address = addr;
        _tag = tag;
      });

      if ((_address ?? '').isEmpty) {
        Get.snackbar(
          'No address returned',
          'Please try again in a moment.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Failed to load address',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String? text, String label) async {
    final v = (text ?? '').trim();
    if (v.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: v));
    Get.snackbar(
      'Copied',
      '$label copied',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _shareDepositDetails() async {
    final addr = (_address ?? '').trim();
    if (addr.isEmpty) return;

    final coin = _coin.value;
    final chain = _chain.value;
    final tag = (_tag ?? '').trim();

    final payload = StringBuffer()
      ..writeln('Osvan Crypto Deposit')
      ..writeln('Coin: $coin')
      ..writeln('Network: $chain')
      ..writeln('Address: $addr');
    if (tag.isNotEmpty) payload.writeln('Tag/Memo: $tag');
    payload.writeln('Note: Send only $coin on $chain.');

    // Share via platform share sheet if available; fallback to copy.
    // Without extra packages, we copy the formatted text.
    await _copy(payload.toString(), 'Deposit details');
  }

  // ─────────────────────────
  // Checksum / network sanity
  // ─────────────────────────
  bool _isTronAddress(String a) {
    final s = a.trim();
    if (s.isEmpty) return false;
    // Quick heuristic: starts with T and length in a safe range
    return s.startsWith('T') && s.length >= 30 && s.length <= 45;
  }

  bool _isEvmAddress(String a) {
    final s = a.trim();
    final rx = RegExp(r'^0x[a-fA-F0-9]{40}$');
    return rx.hasMatch(s);
  }

  String? _addressWarning(String coin, String chain, String addr) {
    final a = addr.trim();
    if (a.isEmpty) return null;

    final net = chain.toUpperCase();

    // If user selected TRON, address must look TRON-ish
    if (net == 'TRON') {
      if (!_isTronAddress(a)) {
        return 'This address does not look like a TRON address. Make sure you selected the correct network.';
      }
      return null;
    }

    // If user selected EVM network (BSC/ETH), address must be 0x...
    if (net == 'BSC' || net == 'ETH') {
      if (!_isEvmAddress(a)) {
        return 'This address does not look like an $net (EVM) address. Make sure you selected the correct network.';
      }
      return null;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withOpacity(0.7);

    final addr = (_address ?? '').trim();
    final warn =
        addr.isEmpty ? null : _addressWarning(_coin.value, _chain.value, addr);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          const Positioned.fill(child: LuxuryBackground()),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kCryptoSurface.withOpacity(0.92),
                    const Color(0xFF08111F).withOpacity(0.86),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Padding(
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
                          'Receive stablecoin',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _Pill(text: 'ADDRESS', color: kIceBlue),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                        child: ValueListenableBuilder<String>(
                          valueListenable: _coin,
                          builder: (_, __, ___) {
                            final nets = _networks;
                            return _Dropdown(
                              label: 'Network',
                              valueListenable: _chain,
                              items: nets,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : () => _loadAddress(),
                      icon: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.qr_code_2_rounded),
                      label: Text(
                          _loading ? 'Generating.' : 'Get deposit address'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: osvanGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if ((_address ?? '').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Deposit details',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // QR preview (high-touch)
                    _QrCard(
                      data: _buildQrPayload(),
                      headerLeft: '${_coin.value} • ${_chain.value}',
                      headerRight: _tagText(),
                    ),
                    const SizedBox(height: 10),

                    if (warn != null) ...[
                      _WarningBox(text: warn),
                      const SizedBox(height: 10),
                    ],

                    _CopyBox(
                      label: 'Address',
                      value: _address!,
                      onCopy: () => _copy(_address, 'Address'),
                    ),

                    if ((_tag ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _CopyBox(
                        label: 'Tag / Memo',
                        value: _tag!,
                        onCopy: () => _copy(_tag, 'Tag/Memo'),
                      ),
                    ],

                    const SizedBox(height: 8),
                    Text(
                      'Send only ${_coin.value} on ${_chain.value}. Deposits are credited after confirmations.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _tagText() {
    final t = (_tag ?? '').trim();
    if (t.isEmpty) return 'No memo';
    return 'Memo: $t';
  }

  // QR payload: keep simple and wallet-friendly.
  // Many wallets accept raw address; we include tag/memo in a readable payload too.
  String _buildQrPayload() {
    final a = (_address ?? '').trim();
    if (a.isEmpty) return '';
    final coin = _coin.value;
    final chain = _chain.value;
    final t = (_tag ?? '').trim();

    // If tag exists, include it in payload (wallets may ignore; still useful for scanning apps)
    if (t.isNotEmpty) {
      return '$coin/$chain|$a|memo=$t';
    }
    return a;
  }

  String _buildShareText() {
    final addr = (_address ?? '').trim();
    final coin = _coin.value;
    final chain = _chain.value;
    final tag = (_tag ?? '').trim();

    final payload = StringBuffer()
      ..writeln('Osvan Crypto Deposit')
      ..writeln('Coin: $coin')
      ..writeln('Network: $chain')
      ..writeln('Address: $addr');
    if (tag.isNotEmpty) payload.writeln('Tag/Memo: $tag');
    payload.writeln('Note: Send only $coin on $chain.');

    return payload.toString();
  }
}

// ─────────────────────────────────────────────────────────────
// UI components
// ─────────────────────────────────────────────────────────────

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

class _Dropdown extends StatelessWidget {
  final String label;
  final ValueListenable<String> valueListenable;
  final List<String> items;

  const _Dropdown({
    required this.label,
    required this.valueListenable,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      borderRadius: BorderRadius.circular(12),
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
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        items: items
            .map(
              (e) => DropdownMenuItem<String>(
                value: e,
                child: Text(e),
              ),
            )
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

class _WarningBox extends StatelessWidget {
  final String text;

  const _WarningBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.90),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final String data;
  final String headerLeft;
  final String headerRight;

  const _QrCard({
    required this.data,
    required this.headerLeft,
    required this.headerRight,
  });

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  headerLeft,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                headerRight,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: QrImageView(
              data: data,
              size: 180,
              gapless: true,
              errorStateBuilder: (ctx, err) => SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    'QR error',
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Scan to copy address',
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _CopyBox({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.78),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onCopy,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: kIceBlue.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kIceBlue.withOpacity(0.25)),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
