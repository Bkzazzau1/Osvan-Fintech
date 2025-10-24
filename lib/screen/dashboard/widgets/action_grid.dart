// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/config/env.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/conversion/conversion_view.dart';
import 'package:osvan_app/screen/crypto/view/crypto_view.dart';
import 'package:osvan_app/screen/paybills/paybills_view.dart';
import 'package:osvan_app/screen/transfer/view/send_money_view.dart';
import 'package:osvan_app/screen/wallet/view/add_money_view.dart';

class ActionGrid extends StatelessWidget {
  const ActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _tile(context,
            label: 'Send',
            icon: Icons.send,
            onTap: () => Get.to(() => const SendMoneyView())),
        _tile(context,
            label: 'Crypto',
            icon: Icons.currency_bitcoin,
            onTap: () => Get.to(() => CryptoView(baseUrl: Env.apiBaseUrl))),
        _tile(context,
            label: 'Add',
            icon: Icons.attach_money,
            onTap: () => Get.to(() => const AddMoneyView())),
        _tile(context,
            label: 'Convert',
            icon: Icons.compare_arrows,
            onTap: () => Get.to(() => const ConversionView())),
        _tile(context,
            label: 'Pay Bills',
            icon: Icons.receipt_long,
            onTap: () => Get.to(() => const PayBillsView())),
      ],
    );
  }

  Widget _tile(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? osvanGreen.withOpacity(0.12) : Colors.white;
    final fg = isDark ? osvanGreen : Colors.black87;
    final borderColor = isDark ? Colors.transparent : Colors.grey.shade200;
    final tileWidth = (MediaQuery.of(context).size.width - 64) / 3;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: tileWidth,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                      color: Colors.black.withOpacity(0.04))
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: fg),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14, color: fg)),
          ],
        ),
      ),
    );
  }
}
