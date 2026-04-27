// action_grid.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/config/env.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/routes/app_routes.dart'; // ← use named routes
import 'package:osvan_app/screen/conversion/conversion_view.dart';
import 'package:osvan_app/screen/crypto/view/crypto_view.dart';
import 'package:osvan_app/screen/paybills/paybills_view.dart';
import 'package:osvan_app/screen/wallet/view/add_money_view.dart';

class ActionGrid extends StatelessWidget {
  const ActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_ActionItem>[
      _ActionItem('Send', Icons.send,
          () => Get.toNamed(AppRoutes.send)), // ← open flow entry
      _ActionItem('Crypto', Icons.currency_bitcoin,
          () => Get.to(() => CryptoView(baseUrl: Env.apiBaseUrl))),
      _ActionItem(
          'Add', Icons.attach_money, () => Get.to(() => const AddMoneyView())),
      _ActionItem('Convert', Icons.compare_arrows,
          () => Get.to(() => const ConversionView())),
      _ActionItem('Pay Bills', Icons.receipt_long,
          () => Get.to(() => const PayBillsView())),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        // Responsive: 4 cols on wide, 3 on medium, 2 on narrow
        final w = c.maxWidth;
        final cols = w >= 980 ? 4 : (w >= 620 ? 3 : 2);
        final spacing = 16.0;
        final tileWidth = (w - (spacing * (cols - 1))) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map((i) => _ActionTile(
                    label: i.label,
                    icon: i.icon,
                    onTap: i.onTap,
                    width: tileWidth,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _ActionItem(this.label, this.icon, this.onTap);
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double width;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isDark ? Colors.transparent : Colors.grey.shade200;
    final fg = isDark ? osvanGreen : Colors.black87;
    final cardBg = isDark ? osvanGreen.withOpacity(0.10) : Colors.white;

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                          color: Colors.black.withOpacity(0.05),
                        ),
                      ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon inside a subtle circle for consistency
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? osvanGreen.withOpacity(0.12)
                          : Colors.black.withOpacity(0.04),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 26, color: fg),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
