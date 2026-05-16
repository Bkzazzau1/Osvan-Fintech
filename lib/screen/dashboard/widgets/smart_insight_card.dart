// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/screen/transaction/controllers/transactions_controller.dart';
import 'package:osvan_app/screen/wallet/controllers/wallets_controller.dart';

class SmartInsightCard extends StatelessWidget {
  const SmartInsightCard({super.key});

  TransactionsController _transactions() {
    if (Get.isRegistered<TransactionsController>()) {
      return Get.find<TransactionsController>();
    }
    return Get.put(TransactionsController());
  }

  @override
  Widget build(BuildContext context) {
    final wc = Get.find<WalletsController>();
    final tc = _transactions();

    return Obx(() {
      final wallets = wc.wallets;
      final txs = tc.items;
      final primary = wc.primaryCurrency.value;
      final primaryWallet = primary.isEmpty ? null : wc.byCode(primary);
      final secondWallet = wallets.firstWhereOrNull(
        (wallet) => wallet.currencyCode.toUpperCase() != primary,
      );

      final recentDebits = txs
          .where((tx) =>
              tx.type.toLowerCase().contains('debit') ||
              tx.type.toLowerCase().contains('send') ||
              tx.type.toLowerCase().contains('withdraw'))
          .take(5)
          .fold<double>(0, (sum, tx) => sum + tx.amount);
      final recentCredits = txs
          .where((tx) =>
              tx.type.toLowerCase().contains('credit') ||
              tx.type.toLowerCase().contains('receive') ||
              tx.type.toLowerCase().contains('deposit'))
          .take(5)
          .fold<double>(0, (sum, tx) => sum + tx.amount);

      final bool hasFlow = txs.isNotEmpty;
      final String title;
      final String body;
      final IconData icon;
      final Color accent;

      if (wallets.length < 2) {
        title = 'Add a backup currency';
        body = 'A second wallet makes transfers, FX and card funding smoother.';
        icon = Icons.add_chart_rounded;
        accent = const Color(0xFF60A5FA);
      } else if (!hasFlow) {
        title = 'Wallet cockpit ready';
        body =
            '${primaryWallet?.currencyCode ?? 'Primary'} and ${secondWallet?.currencyCode ?? 'second'} wallets are ready for movement.';
        icon = Icons.radar_rounded;
        accent = const Color(0xFFA78BFA);
      } else if (recentCredits >= recentDebits) {
        title = 'Positive money flow';
        body = 'Recent incoming movement is ahead of outgoing activity.';
        icon = Icons.trending_up_rounded;
        accent = const Color(0xFF10B981);
      } else {
        title = 'Spending pulse active';
        body =
            'Outgoing movement is higher recently. Review activity if needed.';
        icon = Icons.insights_rounded;
        accent = const Color(0xFFF59E0B);
      }

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F172A).withOpacity(0.96),
              accent.withOpacity(0.16),
              const Color(0xFF08111F).withOpacity(0.98),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: wallets.isEmpty
                        ? 0.18
                        : (wallets.length.clamp(1, 3) / 3),
                    strokeWidth: 4,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                  Icon(icon, color: accent, size: 23),
                ],
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Smart insight',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.56),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.34),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.64),
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
