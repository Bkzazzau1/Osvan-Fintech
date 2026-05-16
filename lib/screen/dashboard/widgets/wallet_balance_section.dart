// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/wallet/controllers/wallets_controller.dart';
import 'package:osvan_app/screen/wallet/models/wallet.dart';

class WalletBalanceSection extends StatefulWidget {
  const WalletBalanceSection({super.key});

  @override
  State<WalletBalanceSection> createState() => _WalletBalanceSectionState();
}

class _WalletBalanceSectionState extends State<WalletBalanceSection> {
  String? _selectedCode; // currency_code like "NGN", "USD"
  bool _obscured = false;

  static const _iceBlue = Color(0xFF60A5FA); // luxury ice-blue accent
  static const _card = Color(0xFF0F172A); // your rule: big card color
  static const _deepBlue = Color(0xFF172554);
  static const _green = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final wc = Get.find<WalletsController>();

    return Obx(() {
      final err = wc.error.value;

      if (err != null && wc.wallets.isEmpty) {
        return _ErrorBox(
          text: err,
          onRetry: () => wc.load(),
        );
      }

      if (wc.isLoading.value && wc.wallets.isEmpty) {
        return const _LoadingBox();
      }

      final List<Wallet> wallets = wc.wallets;
      if (wallets.isEmpty) {
        return _ErrorBox(
          text: 'Wallets are being prepared. Pull down to refresh.',
          onRetry: () => wc.load(),
        );
      }

      final codes = wallets.map((w) => w.currencyCode).toList();
      final primaryFromController = wc.primaryCurrency.value;

      final initialCode = (primaryFromController.isNotEmpty &&
              codes.contains(primaryFromController))
          ? primaryFromController
          : wallets.first.currencyCode;

      _selectedCode = (_selectedCode != null && codes.contains(_selectedCode))
          ? _selectedCode
          : initialCode;

      final selectedWallet =
          wallets.firstWhere((w) => w.currencyCode == _selectedCode);

      return RepaintBoundary(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _card.withOpacity(0.98),
                _deepBlue.withOpacity(0.74),
                const Color(0xFF08111F).withOpacity(0.98),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _iceBlue.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: _iceBlue.withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green.withOpacity(0.12),
                      border: Border.all(color: _green.withOpacity(0.18)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: _green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wallet Balance',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white.withOpacity(0.94),
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Live balance overview',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withOpacity(0.56),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  _Pill(
                    text: 'Primary',
                    icon: Icons.star_rounded,
                    fg: _iceBlue,
                    bg: _iceBlue.withOpacity(0.12),
                    border: _iceBlue.withOpacity(0.20),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Balance row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Obx(() {
                      final code = wc.primaryCurrency.value;
                      final symbol = _symbolFor(code);
                      final bal = wc.primaryBalance.value;
                      final text = _obscured
                          ? '••••••'
                          : '$symbol${bal.toStringAsFixed(2)}';

                      return FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  _IconPillButton(
                    icon: _obscured
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    onTap: () => setState(() => _obscured = !_obscured),
                    fg: Colors.white.withOpacity(0.92),
                    bg: Colors.white.withOpacity(0.06),
                    border: Colors.white.withOpacity(0.10),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openCurrencyPicker(
                  context,
                  wallets: wallets,
                  selected: _selectedCode!,
                  onPick: (code) {
                    setState(() => _selectedCode = code);
                    wc.setPrimaryByCode(code);
                  },
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withOpacity(0.055),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      _MiniCurrencyBadge(
                        symbol: _symbolFor(selectedWallet.currencyCode),
                        code: selectedWallet.currencyCode,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Switch currency',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.90),
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.white.withOpacity(0.70)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _openCurrencyPicker(
    BuildContext context, {
    required List<Wallet> wallets,
    required String selected,
    required ValueChanged<String> onPick,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Select wallet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded,
                          color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: wallets.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.06),
                    ),
                    itemBuilder: (_, i) {
                      final w = wallets[i];
                      final code = w.currencyCode;
                      final active = code == selected;

                      return ListTile(
                        onTap: () {
                          Navigator.pop(context);
                          onPick(code);
                        },
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (active ? _iceBlue : Colors.white)
                                .withOpacity(active ? 0.16 : 0.06),
                            border: Border.all(
                              color: (active ? _iceBlue : Colors.white)
                                  .withOpacity(active ? 0.22 : 0.10),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _symbolFor(code).isEmpty
                                ? code.substring(0, 1)
                                : _symbolFor(code),
                            style: TextStyle(
                              color: active
                                  ? _iceBlue
                                  : Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        title: Text(
                          code,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Tap to set as primary',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                        trailing: active
                            ? Icon(Icons.check_circle_rounded, color: _iceBlue)
                            : Icon(Icons.circle_outlined,
                                color: Colors.white.withOpacity(0.25)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _symbolFor(String code) {
    const map = {
      'NGN': '₦',
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'XOF': 'CFA',
      'AED': 'د.إ',
      'KES': 'KSh',
      'GHS': '₵',
      'UGX': 'USh',
      'ZMW': 'ZK',
      'MWK': 'MK',
      'GNF': 'FG',
      'CNY': '¥',
      'CDF': 'FC',
      'SGD': 'S\$',
      'AUD': 'A\$',
    };
    return map[code] ?? '';
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color fg;
  final Color bg;
  final Color border;

  const _Pill({
    required this.text,
    required this.icon,
    required this.fg,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color fg;
  final Color bg;
  final Color border;

  const _IconPillButton({
    required this.icon,
    required this.onTap,
    required this.fg,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: border),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: fg, size: 22),
        ),
      ),
    );
  }
}

class _MiniCurrencyBadge extends StatelessWidget {
  final String symbol;
  final String code;

  const _MiniCurrencyBadge({
    required this.symbol,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final display = symbol.isEmpty ? code.substring(0, 1) : symbol;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.07),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_rounded,
              color: Colors.white.withOpacity(0.82), size: 16),
          const SizedBox(width: 7),
          Text(
            '$display $code',
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;

  const _ErrorBox({
    required this.text,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: osvanGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: osvanGreen.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.92)),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: osvanGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: osvanGreen.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading wallets...',
            style: TextStyle(color: Colors.white.withOpacity(0.92)),
          ),
        ],
      ),
    );
  }
}
