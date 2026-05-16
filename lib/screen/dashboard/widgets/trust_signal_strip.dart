// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/screen/transaction/controllers/transactions_controller.dart';
import 'package:osvan_app/screen/wallet/controllers/wallets_controller.dart';
import 'package:osvan_app/screen/wallet/services/config_service.dart';

class TrustSignalStrip extends StatelessWidget {
  const TrustSignalStrip({super.key});

  TransactionsController _transactions() {
    if (Get.isRegistered<TransactionsController>()) {
      return Get.find<TransactionsController>();
    }
    return Get.put(TransactionsController());
  }

  @override
  Widget build(BuildContext context) {
    final wallets = Get.find<WalletsController>();
    final txs = _transactions();
    final config = Get.find<ConfigService>();

    return Obx(() {
      final walletOk =
          wallets.error.value == null && wallets.wallets.isNotEmpty;
      final activityOk = txs.error.value == null;
      final cardsOk = config.cardsFundEnabled && config.cardsWithdrawEnabled;
      final allOk = walletOk && activityOk && cardsOk;
      final accent = allOk ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.07),
              blurRadius: 18,
              offset: const Offset(0, 9),
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
                    color: accent.withOpacity(0.13),
                    border: Border.all(color: accent.withOpacity(0.22)),
                  ),
                  child: Icon(
                    allOk ? Icons.verified_user_rounded : Icons.radar_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trust signal',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        allOk
                            ? 'Core money rails are healthy'
                            : 'One or more rails need attention',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.58),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                final chips = [
                  _SignalChip(
                    label: 'Wallet',
                    value: wallets.isLoading.value
                        ? 'Syncing'
                        : walletOk
                            ? 'Live'
                            : 'Check',
                    ok: walletOk,
                  ),
                  _SignalChip(
                    label: 'Activity',
                    value: txs.isLoading.value
                        ? 'Loading'
                        : activityOk
                            ? 'Ready'
                            : 'Retry',
                    ok: activityOk,
                  ),
                  _SignalChip(
                    label: 'Cards',
                    value: cardsOk ? 'Active' : 'Limited',
                    ok: cardsOk,
                  ),
                ];

                if (compact) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips,
                  );
                }

                return Row(
                  children: [
                    for (var i = 0; i < chips.length; i++) ...[
                      Expanded(child: chips[i]),
                      if (i != chips.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      );
    });
  }
}

class _SignalChip extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;

  const _SignalChip({
    required this.label,
    required this.value,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.info_rounded,
            color: accent,
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$label: $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
