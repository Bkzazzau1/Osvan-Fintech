// lib/screen/wallet/views/conversion_view.dart
// High-grade, unique, high-class Conversion screen (Luxury glass + premium sections)
// - Keeps your existing ConversionController API calls untouched (getQuote/confirm)
// - Preserves WalletsController + CryptoController optional hints
// - Fixes UI consistency: card surface, glow, spacing, premium typography
//
// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:osvan_app/controller/crypto_controller.dart';
import 'package:osvan_app/screen/conversion/controller/conversion_controller.dart';
import 'package:osvan_app/screen/wallet/controllers/wallets_controller.dart';
import 'package:osvan_app/widgets/luxury_background.dart';

import '../../../core/colors.dart';

class ConversionView extends StatelessWidget {
  const ConversionView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ConversionController(), permanent: false);

    // Try to attach shared controllers if they exist in the app shell.
    WalletsController? wc;
    CryptoController? cc;
    try {
      wc = Get.find<WalletsController>();
    } catch (_) {}
    try {
      cc = Get.find<CryptoController>();
    } catch (_) {}

    Theme.of(context);
    const isDark = true;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: const Text('Currency Conversion'),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const _LuxuryBackground(),
          Obx(() {
              final needsNet = c.needsNetwork;

              final amountOk = c.amount.value.trim().isNotEmpty;
              final networkOk = !needsNet || c.network.value.trim().isNotEmpty;

              final canQuote = !c.loading.value && amountOk && networkOk;
              final canConfirm = canQuote && (c.lastQuote.value != null);

              return SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _HeroHeader(
                      title: "Convert instantly",
                      subtitle:
                          "Swap between fiat and stablecoin with transparent rates.",
                      pill: "OPTION B",
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // FROM
                            _SectionTitle(
                              icon: Icons.call_made_rounded,
                              title: "From",
                              subtitle: "Choose source currency",
                            ),
                            const SizedBox(height: 10),
                            _dropdown(
                              context,
                              label: "From Currency",
                              value: c.from.value,
                              items: const ["USD", "NGN", "USDT"],
                              onChanged: (v) {
                                final nv = (v ?? c.from.value);
                                c.from.value = nv;
                                // Clear network when coin isn't USDT to prevent stale value
                                if (nv.toUpperCase() != 'USDT') {
                                  c.network.value = '';
                                }
                              },
                              trailingHint: _balanceHint(
                                context: context,
                                wc: wc,
                                cc: cc,
                                coin: c.from.value,
                                network: c.network.value,
                              ),
                            ),

                            const SizedBox(height: 14),

                            // TO
                            _SectionTitle(
                              icon: Icons.call_received_rounded,
                              title: "To",
                              subtitle: "Choose destination currency",
                            ),
                            const SizedBox(height: 10),
                            _dropdown(
                              context,
                              label: "To Currency",
                              value: c.to.value,
                              items: const ["USD", "NGN", "USDT"],
                              onChanged: (v) {
                                final nv = (v ?? c.to.value);
                                c.to.value = nv;
                                if (nv.toUpperCase() != 'USDT') {
                                  c.network.value = '';
                                }
                              },
                              trailingHint: _balanceHint(
                                context: context,
                                wc: wc,
                                cc: cc,
                                coin: c.to.value,
                                network: c.network.value,
                              ),
                            ),

                            // NETWORK (only when USDT involved)
                            if (needsNet) ...[
                              const SizedBox(height: 14),
                              _SectionTitle(
                                icon: Icons.hub_outlined,
                                title: "Network",
                                subtitle: "Select chain for stablecoin",
                              ),
                              const SizedBox(height: 10),
                              _dropdown(
                                context,
                                label: "Network",
                                value: c.network.value.trim().isEmpty
                                    ? null
                                    : c.network.value,
                                // Keep all supported; you can trim to ['TRON','BSC'] if desired
                                items: const ["TRON", "BSC", "ETH"],
                                onChanged: (v) => c.network.value = v ?? '',
                                trailingHint: _usdtBalanceByNetworkHint(
                                  context: context,
                                  cc: cc,
                                  network: c.network.value,
                                ),
                              ),
                              if (!networkOk)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _InlineWarn(
                                    text: 'Select a network for USDT',
                                  ),
                                ),
                            ],

                            const SizedBox(height: 14),

                            // AMOUNT
                            _SectionTitle(
                              icon: Icons.numbers_outlined,
                              title: "Amount",
                              subtitle: "Enter how much you want to convert",
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              enabled: !c.loading.value,
                              decoration: _dec(
                                context,
                                label: "Amount",
                                icon: Icons.numbers_outlined,
                                hint: "0.00",
                                suffix: const Icon(Icons.edit_outlined),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,8}$'),
                                ),
                              ],
                              onChanged: (v) => c.amount.value = v,
                            ),

                            const SizedBox(height: 16),

                            // Actions row
                            Row(
                              children: [
                                Expanded(
                                  child: _PrimaryButton(
                                    text: c.loading.value
                                        ? "Generating…"
                                        : "Get Quote",
                                    loading: c.loading.value,
                                    onPressed: canQuote ? c.getQuote : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _IconAction(
                                  tooltip: "Swap currencies",
                                  icon: Icons.swap_vert_rounded,
                                  onTap: c.loading.value
                                      ? null
                                      : () {
                                          final tmp = c.from.value;
                                          c.from.value = c.to.value;
                                          c.to.value = tmp;

                                          // Network rules
                                          final involvesUsdt =
                                              c.from.value.toUpperCase() ==
                                                      'USDT' ||
                                                  c.to.value.toUpperCase() ==
                                                      'USDT';
                                          if (!involvesUsdt) {
                                            c.network.value = '';
                                          }
                                        },
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            if (c.lastQuote.value != null) const _QuoteCard(),

                            if (c.lastQuote.value != null) ...[
                              const SizedBox(height: 6),
                              _PrimaryButton(
                                text: "Confirm Conversion",
                                loading: false,
                                onPressed: canConfirm ? c.confirm : null,
                              ),
                            ],

                            if (c.lastConfirm.value != null) ...[
                              const SizedBox(height: 10),
                              const _ConfirmCard(),
                            ],

                            if (c.error.value != null) ...[
                              const SizedBox(height: 10),
                              _InlineError(text: c.error.value!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FootNote(
                      text:
                          "Tip: Always confirm you selected the correct network when converting stablecoins.",
                      isDark: isDark,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // Dropdown with optional trailing hint (e.g., balance)
  Widget _dropdown(
    BuildContext context, {
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    Widget? trailingHint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          // IMPORTANT: if value is '' pass null to avoid assertion
          initialValue: (value != null && value.trim().isEmpty) ? null : value,
          items: items
              .map(
                (x) => DropdownMenuItem<String>(
                  value: x,
                  child: Text(
                    x,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          dropdownColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0F172A)
              : Colors.white,
          decoration: _dec(
            context,
            label: label,
            icon: Icons.payments_outlined,
          ),
        ),
        if (trailingHint != null) ...[
          const SizedBox(height: 6),
          trailingHint,
        ]
      ],
    );
  }

  // Shows "Available: <balance>" for fiat/crypto based on selection
  Widget _balanceHint({
    required BuildContext context,
    required WalletsController? wc,
    required CryptoController? cc,
    required String coin,
    required String network,
  }) {
    final upper = coin.toUpperCase();

    // Fiat: read from WalletsController (if present)
    if (upper == 'USD' || upper == 'NGN') {
      if (wc == null) return const SizedBox.shrink();
      final w = wc.byCode(upper);
      final bal = (w?.balance ?? 0).toStringAsFixed(2);
      return _hintText(context, 'Available: $bal $upper');
    }

    // Crypto (USDT): read from CryptoController balances if present
    if (upper == 'USDT') {
      if (cc == null) return _hintText(context, 'Available: — USDT');

      String net = network.trim().toUpperCase();
      if (net.isEmpty) {
        final tron = cc.balances
            .firstWhereOrNull((b) => b.coin == 'USDT' && b.network == 'TRON');
        if (tron != null) {
          net = 'TRON';
        } else {
          final any = cc.balances.firstWhereOrNull((b) => b.coin == 'USDT');
          net = any?.network ?? 'TRON';
        }
      }

      final b = cc.balances
          .firstWhereOrNull((e) => e.coin == 'USDT' && e.network == net);
      final bal = (b?.balance ?? 0).toStringAsFixed(8);
      return _hintText(context, 'Available: $bal USDT on $net');
    }

    return const SizedBox.shrink();
  }

  // For the Network field specifically (USDT)
  Widget _usdtBalanceByNetworkHint({
    required BuildContext context,
    required CryptoController? cc,
    required String network,
  }) {
    if (cc == null) return const SizedBox.shrink();
    final net = network.trim().isEmpty ? 'TRON' : network.trim().toUpperCase();
    final b = cc.balances
        .firstWhereOrNull((e) => e.coin == 'USDT' && e.network == net);
    final bal = (b?.balance ?? 0).toStringAsFixed(8);
    return _hintText(context, 'Available on $net: $bal USDT');
  }

  Widget _hintText(BuildContext context, String text) => Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: osvanGreen.withOpacity(0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    color: osvanGreen.withOpacity(0.25),
                  )
                ],
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _HeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String pill;
  final bool isDark;

  const _HeroHeader({
    required this.title,
    required this.subtitle,
    required this.pill,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : Colors.black,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.70),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _Pill(text: pill),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF60A5FA).withOpacity(isDark ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF60A5FA).withOpacity(isDark ? 0.28 : 0.22),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: osvanGreen.withOpacity(isDark ? 0.16 : 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: osvanGreen.withOpacity(isDark ? 0.22 : 0.16),
            ),
          ),
          child: Icon(icon, color: osvanGreen, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: th.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: th.textTheme.bodySmall?.copyWith(
                  color: th.textTheme.bodySmall?.color?.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: osvanGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.10),
            ),
          ),
          child: Icon(
            icon,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

class _InlineWarn extends StatelessWidget {
  final String text;
  const _InlineWarn({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.85),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String text;
  const _InlineError({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.85),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FootNote extends StatelessWidget {
  final String text;
  final bool isDark;

  const _FootNote({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined,
              size: 18, color: osvanGreen.withOpacity(0.95)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.72),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: size,
            height: size,
            color: color.withOpacity(0.12),
          ),
        ),
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
          colors: [
            Color(0xFF070B14),
            Color(0xFF0B1220),
            Color(0xFF070B14),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -80,
            child: _GlowBlob(color: osvanGreen, size: 220),
          ),
          Positioned(
            top: 190,
            right: -120,
            child: _GlowBlob(color: Colors.blueAccent, size: 260),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _GlowBlob(color: Colors.purpleAccent, size: 320),
          ),
        ],
      ),
    );
  }
}

InputDecoration _dec(
  BuildContext context, {
  required String label,
  required IconData icon,
  String? hint,
  Widget? suffix,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color: (isDark ? Colors.white : Colors.black).withOpacity(0.10),
    ),
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: osvanGreen, width: 1.3),
    ),
    filled: true,
    fillColor: isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

class _QuoteCard extends GetView<ConversionController> {
  const _QuoteCard();

  @override
  Widget build(BuildContext context) {
    final q = controller.lastQuote.value!;
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(child: LuxuryBackground()),
        _GlassSubCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        size: 18, color: osvanGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q.summary,
                        style: th.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _kv(context, "You receive", "${q.youReceive} ${q.to}"),
                _kv(context, "Rate", q.rate, muted: true),
                _kv(context, "Fee", "${q.fee} (${q.feePercent}%)",
                    muted: true),
                if (q.netSourceAmount.isNotEmpty)
                  _kv(context, "Net debit", "${q.netSourceAmount} ${q.from}",
                      muted: true),
                if (q.expiresInSec.isNotEmpty)
                  _kv(context, "Expires in", "${q.expiresInSec}s", muted: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v, {bool muted = false}) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    final kStyle = th.textTheme.bodySmall?.copyWith(
      color: (isDark ? Colors.white : Colors.black)
          .withOpacity(muted ? 0.65 : 0.80),
      fontWeight: FontWeight.w700,
    );
    final vStyle = th.textTheme.bodyMedium?.copyWith(
      color: isDark ? Colors.white : Colors.black,
      fontWeight: muted ? FontWeight.w700 : FontWeight.w900,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: Text(k, style: kStyle)),
          const SizedBox(width: 10),
          Text(v, style: vStyle),
        ],
      ),
    );
  }
}

class _ConfirmCard extends GetView<ConversionController> {
  const _ConfirmCard();

  @override
  Widget build(BuildContext context) {
    final m = controller.lastConfirm.value!;
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    String orDash(dynamic v) {
      final s = (v ?? '').toString();
      return s.isEmpty || s.toLowerCase() == 'null' ? '-' : s;
    }

    return _GlassSubCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_rounded,
                    size: 18, color: osvanGreen.withOpacity(0.95)),
                const SizedBox(width: 8),
                Text(
                  "Conversion Successful",
                  style: th.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _row(th, "From", "${orDash(m["from"])} → ${orDash(m["to"])}"),
            if (m["network"] != null && orDash(m["network"]) != '-')
              _row(th, "Network", orDash(m["network"]), muted: true),
            _row(
              th,
              "Amount",
              "${orDash(m["amount"])}   Credited: ${orDash(m["credited"])}",
            ),
            _row(
              th,
              "Rate / Fee",
              "Rate: ${orDash(m["rate"])}   Fee: ${orDash(m["fee"])}",
              muted: true,
            ),
            _row(th, "Time", orDash(m["timestamp"]), muted: true),
            if (m["quoteId"] != null && orDash(m["quoteId"]) != '-')
              _row(th, "Quote ID", orDash(m["quoteId"]), muted: true),
            if (m["expectedReceive"] != null &&
                orDash(m["expectedReceive"]) != '-')
              _row(th, "Expected receive", orDash(m["expectedReceive"]),
                  muted: true),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData th, String k, String v, {bool muted = false}) {
    final isDark = th.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: th.textTheme.bodySmall?.copyWith(
                color: (isDark ? Colors.white : Colors.black)
                    .withOpacity(muted ? 0.65 : 0.80),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: th.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: muted ? FontWeight.w700 : FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSubCard extends StatelessWidget {
  final Widget child;
  const _GlassSubCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.10),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
