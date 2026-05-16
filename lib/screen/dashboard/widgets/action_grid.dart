// action_grid.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/config/env.dart';
import 'package:osvan_app/routes/app_routes.dart'; // ← use named routes
import 'package:osvan_app/screen/conversion/conversion_view.dart';
import 'package:osvan_app/screen/crypto/view/crypto_view.dart';
import 'package:osvan_app/screen/wallet/view/add_money_view.dart';

class ActionGrid extends StatelessWidget {
  const ActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_ActionItem>[
      _ActionItem('Send', Icons.near_me_rounded, const Color(0xFF10B981),
          () => Get.toNamed(AppRoutes.send)), // ← open flow entry
      _ActionItem('Crypto', Icons.currency_bitcoin, const Color(0xFFF59E0B),
          () => Get.to(() => CryptoView(baseUrl: Env.apiBaseUrl))),
      _ActionItem('Add', Icons.add_card_rounded, const Color(0xFF60A5FA),
          () => Get.to(() => const AddMoneyView())),
      _ActionItem('Convert', Icons.sync_alt_rounded, const Color(0xFFA78BFA),
          () => Get.to(() => const ConversionView())),
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
                    accent: i.accent,
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
  final Color accent;
  final VoidCallback onTap;
  _ActionItem(this.label, this.icon, this.accent, this.onTap);
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final double width;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor =
        isDark ? accent.withOpacity(0.18) : Colors.grey.shade200;
    final fg = isDark ? Colors.white.withOpacity(0.94) : Colors.black87;

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
              height: 106,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                gradient: isDark
                    ? LinearGradient(
                        colors: [
                          const Color(0xFF101827).withOpacity(0.96),
                          accent.withOpacity(0.16),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isDark ? null : Colors.white,
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? accent.withOpacity(0.16)
                          : Colors.black.withOpacity(0.04),
                      border: Border.all(
                        color: isDark
                            ? accent.withOpacity(0.20)
                            : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 24, color: isDark ? accent : fg),
                  ),
                  const Spacer(),
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
