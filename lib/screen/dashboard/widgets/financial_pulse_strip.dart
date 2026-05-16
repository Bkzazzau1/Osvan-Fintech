// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/screen/transaction/controllers/transactions_controller.dart';
import 'package:osvan_app/screen/wallet/controllers/wallets_controller.dart';

class FinancialPulseStrip extends StatelessWidget {
  const FinancialPulseStrip({super.key});

  WalletsController _wallets() => Get.find<WalletsController>();

  TransactionsController _transactions() {
    if (Get.isRegistered<TransactionsController>()) {
      return Get.find<TransactionsController>();
    }
    return Get.put(TransactionsController());
  }

  @override
  Widget build(BuildContext context) {
    final wc = _wallets();
    final tc = _transactions();

    return Obx(() {
      final walletCount = wc.wallets.length;
      final primary = wc.primaryCurrency.value.isEmpty
          ? 'Wallet'
          : wc.primaryCurrency.value;
      final secondaryWallet = wc.wallets.firstWhereOrNull(
            (wallet) => wallet.currencyCode.toUpperCase() != primary,
          ) ??
          (wc.wallets.length > 1 ? wc.wallets[1] : null);
      final secondaryValue = secondaryWallet == null
          ? 'Add wallet'
          : '${secondaryWallet.currencyCode} ${secondaryWallet.formatBalance()}';
      final txCount = tc.items.length;
      final loading = wc.isLoading.value || tc.isLoading.value;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF08111F).withOpacity(0.96),
              const Color(0xFF10213A).withOpacity(0.96),
              const Color(0xFF07131D).withOpacity(0.98),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF60A5FA).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -36,
              child: IgnorePointer(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF60A5FA).withOpacity(0.06),
                    border: Border.all(
                      color: const Color(0xFF60A5FA).withOpacity(0.06),
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: loading
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                        boxShadow: [
                          BoxShadow(
                            color: (loading
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF10B981))
                                .withOpacity(0.32),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      loading ? 'Syncing money pulse' : 'Money pulse live',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 360;
                    final tiles = [
                      _PulseTile(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Second wallet',
                        value: secondaryValue,
                        accent: const Color(0xFF60A5FA),
                      ),
                      _PulseTile(
                        icon: Icons.hub_rounded,
                        label: 'Wallets',
                        value: walletCount == 1
                            ? '1 currency'
                            : '$walletCount currencies',
                        accent: const Color(0xFF10B981),
                      ),
                      _PulseTile(
                        icon: Icons.monitor_heart_rounded,
                        label: 'Flow',
                        value: txCount == 0 ? 'Ready' : '$txCount moves',
                        accent: const Color(0xFFA78BFA),
                      ),
                    ];

                    if (narrow) {
                      return Column(
                        children: [
                          for (var i = 0; i < tiles.length; i++) ...[
                            tiles[i],
                            if (i != tiles.length - 1)
                              const SizedBox(height: 8),
                          ],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        for (var i = 0; i < tiles.length; i++) ...[
                          Expanded(child: tiles[i]),
                          if (i != tiles.length - 1) const SizedBox(width: 8),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _PulseTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _PulseTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.14),
              border: Border.all(color: accent.withOpacity(0.22)),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.52),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
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
