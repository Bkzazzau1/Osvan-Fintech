// lib/screen/crypto/view/crypto_view.dart
// Luxury UI + Option-B rails (USDT/USDC). Network selector per coin.
// Removed Cash out & Convert actions, keeps page fully scrollable.
//
// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/controller/crypto_controller.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/crypto/widgets/receive_sheet.dart';
import 'package:osvan_app/screen/crypto/widgets/send_sheet.dart';
import 'package:osvan_app/services/auth_service.dart';
import 'package:osvan_app/services/crypto_service.dart';

const kCryptoBg = Color(0xFF070B14);
const kCryptoSurface = Color(0xFF0F172A);
const kCryptoSurface2 = Color(0xFF0B1220);
const kIceBlue = Color(0xFF60A5FA);

class CryptoView extends StatefulWidget {
  final String baseUrl; // e.g. https://fintech.osvan.africa/api or /api/v1
  const CryptoView({super.key, required this.baseUrl});

  @override
  State<CryptoView> createState() => _CryptoViewState();
}

class _CryptoViewState extends State<CryptoView> {
  String? _selectedCoin; // USDT/USDC
  String? _selectedNetwork; // TRON/BSC/ETH
  late final CryptoController c;

  static const _allowedCoins = {'USDT', 'USDC'};

  static const Map<String, List<String>> _networksByCoin = {
    'USDT': ['TRON', 'BSC'],
    'USDC': ['TRON', 'ETH'],
  };

  String _normalizeToV1(String url) {
    final trimmed = url.replaceFirst(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/api/v1')) return trimmed;
    if (trimmed.endsWith('/api')) return '$trimmed/v1';
    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<CryptoController>()) {
      Get.delete<CryptoController>(force: true);
    }

    final v1Base = _normalizeToV1(widget.baseUrl);
    c = Get.put(
      CryptoController(
        CryptoService(
          baseUrl: v1Base,
          tokenProvider: () async => await AuthService.getToken(),
        ),
      ),
      permanent: true,
    );

    Future.microtask(() => c.refreshAll());
  }

  @override
  void dispose() {
    if (Get.isRegistered<CryptoController>()) {
      Get.delete<CryptoController>(force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      backgroundColor: kCryptoBg,
      body: Stack(
        children: [
          const _LuxuryBackground(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: 'Crypto',
                  trailing: Obx(
                    () => IconButton(
                      onPressed: c.isLoading.value ? null : c.refreshAll,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                    ),
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    final filtered = c.balances
                        .where((b) => _allowedCoins.contains(b.coin))
                        .toList();

                    final coins = filtered.map((b) => b.coin).toSet().toList()
                      ..sort();

                    // pick default coin
                    if (coins.isNotEmpty &&
                        (_selectedCoin == null ||
                            !coins.contains(_selectedCoin))) {
                      _selectedCoin =
                          coins.contains('USDT') ? 'USDT' : coins.first;
                      _selectedNetwork = null;
                    }

                    final activeCoin = _selectedCoin ??
                        (coins.isNotEmpty ? coins.first : 'USDT');

                    final nets = (_networksByCoin[activeCoin] ?? const ['TRON'])
                        .toList();

                    // networks in balances (if backend returns subset)
                    final netsFromBalances = filtered
                        .where((b) => b.coin == activeCoin)
                        .map((b) => b.network)
                        .toSet()
                        .toList()
                      ..sort();

                    final networksForCoin = netsFromBalances.isNotEmpty
                        ? netsFromBalances
                            .where((n) => nets.contains(n))
                            .toList()
                        : nets;

                    // pick default network
                    if (networksForCoin.isNotEmpty &&
                        (_selectedNetwork == null ||
                            !networksForCoin.contains(_selectedNetwork))) {
                      _selectedNetwork = networksForCoin.contains('TRON')
                          ? 'TRON'
                          : networksForCoin.first;
                    }

                    final totalByCoin = <String, double>{};
                    for (final b in filtered) {
                      totalByCoin[b.coin] =
                          (totalByCoin[b.coin] ?? 0) + b.balance;
                    }

                    final coinTotal = totalByCoin[activeCoin] ?? 0.0;

                    final networkBal = filtered
                        .where((b) =>
                            b.coin == activeCoin &&
                            (_selectedNetwork == null ||
                                b.network == _selectedNetwork))
                        .fold<double>(0.0, (acc, b) => acc + b.balance);

                    if (c.isLoading.value && filtered.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: c.refreshAll,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                        children: [
                          _GlassCard(
                            title: 'Your stablecoins',
                            subtitle: 'Select asset & network',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // coin chips
                                if (coins.isNotEmpty)
                                  _ChipRow(
                                    items: coins,
                                    value: activeCoin,
                                    onChanged: (coin) {
                                      setState(() {
                                        _selectedCoin = coin;
                                        _selectedNetwork = null;
                                      });
                                    },
                                  ),

                                const SizedBox(height: 10),

                                // network chips
                                if (networksForCoin.isNotEmpty)
                                  _ChipRow(
                                    items: networksForCoin,
                                    value: _selectedNetwork ??
                                        networksForCoin.first,
                                    onChanged: (net) =>
                                        setState(() => _selectedNetwork = net),
                                    pillColor: kIceBlue,
                                  ),

                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _BalanceTile(
                                        title: 'Total $activeCoin',
                                        value: _fmtAmt(activeCoin, coinTotal),
                                        foot: 'All networks',
                                        icon: Icons.savings_rounded,
                                        accent: kIceBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _BalanceTile(
                                        title: _selectedNetwork ?? 'Network',
                                        value: _fmtAmt(activeCoin, networkBal),
                                        foot:
                                            '$activeCoin on ${_selectedNetwork ?? '-'}',
                                        icon: Icons.hub_rounded,
                                        accent: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          _GlassCard(
                            title: 'Actions',
                            subtitle: 'Receive or send crypto',
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ActionTile(
                                    label: 'Receive',
                                    icon: Icons.qr_code_2_rounded,
                                    onTap: () => _showCenteredDialog(
                                      context,
                                      child: ReceiveSheet(
                                        controller: c,
                                        ticker: activeCoin,
                                        network: (_selectedNetwork ?? 'TRON'),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ActionTile(
                                    label: 'Send',
                                    icon: Icons.send_rounded,
                                    onTap: () => _showCenteredDialog(
                                      context,
                                      child: SendSheet(
                                        controller: c,
                                        ticker: activeCoin,
                                        network: (_selectedNetwork ?? 'TRON'),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          _GlassCard(
                            title: 'Recent activity',
                            subtitle:
                                '$activeCoin • ${_selectedNetwork ?? 'All networks'}',
                            child: c.txs.isEmpty
                                ? const _EmptyNote(
                                    text:
                                        'No transactions yet. Generate an address or send crypto to get started.',
                                  )
                                : Column(
                                    children: c.txs
                                        .where((t) => t.coin == activeCoin)
                                        .where((t) =>
                                            _selectedNetwork == null ||
                                            t.network == _selectedNetwork)
                                        .map(
                                          (t) => _TxnRow(
                                            type: t.type,
                                            coin: t.coin,
                                            network: t.network,
                                            status: t.status,
                                            amount: t.amount,
                                            createdAt: t.createdAt,
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtAmt(String coin, double v) =>
      coin == 'BTC' ? v.toStringAsFixed(8) : v.toStringAsFixed(2);

  void _showCenteredDialog(BuildContext context, {required Widget child}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: kCryptoSurface.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 22,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Premium UI bits
// ─────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _TopBar({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          if (trailing != null) ...[
            Theme(
              data: Theme.of(context).copyWith(
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final Color? pillColor;

  const _ChipRow({
    required this.items,
    required this.value,
    required this.onChanged,
    this.pillColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = pillColor ?? osvanGreen;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((s) {
          final selected = s == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withOpacity(0.95)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? accent.withOpacity(0.55)
                        : Colors.white.withOpacity(0.10),
                  ),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    color:
                        selected ? Colors.white : Colors.white.withOpacity(.85),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _GlassCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: kCryptoSurface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                ),
              ),
              if ((subtitle ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final String title;
  final String value;
  final String foot;
  final IconData icon;
  final Color accent;

  const _BalanceTile({
    required this.title,
    required this.value,
    required this.foot,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(0.28)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  foot,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.60),
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kIceBlue.withOpacity(0.14),
                shape: BoxShape.circle,
                border: Border.all(color: kIceBlue.withOpacity(0.28)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  final String type;
  final String coin;
  final String network;
  final String status;
  final double amount;
  final DateTime createdAt;

  const _TxnRow({
    required this.type,
    required this.coin,
    required this.network,
    required this.status,
    required this.amount,
    required this.createdAt,
  });

  String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$da $hh:$mm';
  }

  String _fmtAmt(String coin, double v) =>
      coin == 'BTC' ? v.toStringAsFixed(8) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final isDeposit = type.toLowerCase() == 'deposit';
    final color = isDeposit ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(
              isDeposit ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${type.toUpperCase()} • $coin ($network)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$status • ${_fmtDate(createdAt)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            (isDeposit ? '+' : '-') + _fmtAmt(coin, amount),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: color.withOpacity(0.25),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded,
              size: 26, color: Colors.white.withOpacity(0.75)),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(color: Colors.white.withOpacity(0.75)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LuxuryBackground extends StatelessWidget {
  const _LuxuryBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kCryptoBg, kCryptoSurface2, kCryptoBg],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -80,
            child: _GlowBlob(color: kIceBlue, size: 260, opacity: 0.10),
          ),
          Positioned(
            top: 210,
            right: -120,
            child:
                _GlowBlob(color: Color(0xFF10B981), size: 260, opacity: 0.06),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child:
                _GlowBlob(color: Colors.purpleAccent, size: 320, opacity: 0.06),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowBlob({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: size,
            height: size,
            color: color.withOpacity(opacity),
          ),
        ),
      ),
    );
  }
}
