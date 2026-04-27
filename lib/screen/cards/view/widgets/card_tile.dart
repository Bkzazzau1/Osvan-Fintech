// lib/screen/cards/widgets/card_tile.dart
// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:osvan_app/core/colors.dart';

import '../cards_view.dart'; // CardVM

class CardTile extends StatelessWidget {
  final CardVM card;
  final bool freezeBusy;
  final bool termBusy;
  final void Function(CardVM) onOpenActions;

  const CardTile({
    super.key,
    required this.card,
    required this.freezeBusy,
    required this.termBusy,
    required this.onOpenActions,
  });

  static bool _isVisa(String brand) => brand.toUpperCase().contains('VISA');
  static bool _isMc(String brand) => brand.toUpperCase().contains('MASTER');

  static Color _brandColor(String brand) {
    final b = brand.toUpperCase();
    if (_isVisa(b)) return const Color(0xFF1A1F71);
    if (_isMc(b)) return const Color(0xFFEB001B);
    return const Color(0xFF0B1220);
  }

  static Widget _brandBadge(String brand) {
    final b = brand.toUpperCase();
    final text = _isVisa(b) ? 'VISA' : (_isMc(b) ? 'MASTERCARD' : b);
    final bg = _brandColor(b);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: bg.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
          fontSize: 12,
        ),
      ),
    );
  }

  static Widget _statusPill(CardVM card) {
    final isFrozen = card.isFrozen;
    final tint = isFrozen ? Colors.amber : osvanGreen;
    final label = isFrozen ? "Frozen" : "Active";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────── Premium Action Sheet (same callbacks) ─────────────────────
  static Future<void> openActions(
    BuildContext context, {
    required CardVM card,
    required bool freezeBusy,
    required bool termBusy,
    required VoidCallback onViewTx,
    required VoidCallback onReveal,
    required VoidCallback onStatement,
    required VoidCallback onTopUp,
    required VoidCallback onWithdraw,
    required VoidCallback onToggleFreeze,
    required VoidCallback onTerminate,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget actionRow({
      required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback? onTap,
      Color? iconColor,
      bool showChevron = true,
      Widget? trailing,
    }) {
      final enabled = onTap != null;

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (iconColor ?? Colors.white).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? (iconColor ?? Colors.white)
                      : (iconColor ?? Colors.white).withOpacity(0.35),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: enabled
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.45),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(enabled ? 0.65 : 0.35),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (showChevron)
                Icon(Icons.chevron_right_rounded,
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(enabled ? 0.55 : 0.25)),
            ],
          ),
        ),
      );
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1524) : theme.cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.10)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),

                // header
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.white)
                                .withOpacity(isDark ? 0.55 : 0.95),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.10)),
                          ),
                          child: Row(
                            children: [
                              _brandBadge(card.brand),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      card.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${card.brand.toUpperCase()} •••• ${card.last4} · ${card.currency}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: (isDark
                                                ? Colors.white
                                                : Colors.black)
                                            .withOpacity(0.65),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: osvanGreen,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      '${card.balanceFormatted()} ${card.currency}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _statusPill(card),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: -60,
                        top: -60,
                        child: IgnorePointer(
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              color: osvanGreen.withOpacity(0.10),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 70,
                                  spreadRadius: 14,
                                  color: osvanGreen.withOpacity(0.18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // actions
                if (card.isTerminated) ...[
                  actionRow(
                    icon: Icons.info_outline_rounded,
                    title: "Card terminated",
                    subtitle: "Actions are disabled for terminated cards.",
                    iconColor: Colors.redAccent,
                    onTap: null,
                    showChevron: false,
                  ),
                  const SizedBox(height: 10),
                ],

                actionRow(
                  icon: Icons.receipt_long_rounded,
                  title: "View transactions",
                  subtitle: "See card activity history",
                  iconColor: const Color(0xFF60A5FA),
                  onTap: card.isTerminated
                      ? null
                      : () {
                          Navigator.pop(context);
                          onViewTx();
                        },
                ),
                const SizedBox(height: 10),
                actionRow(
                  icon: Icons.visibility_rounded,
                  title: "View details",
                  subtitle: "Securely reveal card number/CVV",
                  iconColor: const Color(0xFF60A5FA),
                  onTap: card.isTerminated
                      ? null
                      : () {
                          Navigator.pop(context);
                          onReveal();
                        },
                ),
                const SizedBox(height: 10),
                actionRow(
                  icon: Icons.picture_as_pdf_rounded,
                  title: "Open statement",
                  subtitle: "PDF statement in external viewer",
                  iconColor: const Color(0xFFA78BFA),
                  onTap: card.isTerminated
                      ? null
                      : () {
                          Navigator.pop(context);
                          onStatement();
                        },
                ),

                const SizedBox(height: 10),

                actionRow(
                  icon: Icons.account_balance_wallet_rounded,
                  title: "Top up",
                  subtitle: "Fund this virtual card",
                  iconColor: osvanGreen,
                  onTap: card.isTerminated
                      ? null
                      : () {
                          Navigator.pop(context);
                          onTopUp();
                        },
                ),
                const SizedBox(height: 10),
                actionRow(
                  icon: Icons.payments_rounded,
                  title: "Withdraw",
                  subtitle: "Move funds back to wallet",
                  iconColor: Colors.amber,
                  onTap: card.isTerminated
                      ? null
                      : () {
                          Navigator.pop(context);
                          onWithdraw();
                        },
                ),

                const SizedBox(height: 10),

                actionRow(
                  icon: card.isFrozen
                      ? Icons.lock_open_rounded
                      : Icons.lock_rounded,
                  title: card.isFrozen ? "Unfreeze card" : "Freeze card",
                  subtitle: card.isFrozen
                      ? "Enable usage again"
                      : "Temporarily disable usage",
                  iconColor: card.isFrozen ? osvanGreen : Colors.orangeAccent,
                  onTap: (!freezeBusy && !card.isTerminated)
                      ? () {
                          Navigator.pop(context);
                          onToggleFreeze();
                        }
                      : null,
                  trailing: freezeBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),

                const SizedBox(height: 10),

                actionRow(
                  icon: Icons.delete_forever_rounded,
                  title: "Terminate card",
                  subtitle: "Permanent. Cannot be undone.",
                  iconColor: Colors.redAccent,
                  onTap: (!termBusy && !card.isTerminated)
                      ? () {
                          Navigator.pop(context);
                          onTerminate();
                        }
                      : null,
                  trailing: termBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),

                const SizedBox(height: 10),

                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text("Close"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    final base = isDark ? const Color(0xFF0F1524) : const Color(0xFF0F172A);
    final edge = _brandColor(card.brand);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onOpenActions(card),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // card body
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    base,
                    base.withOpacity(0.92),
                    const Color(0xFF111827),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _brandBadge(card.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '•••• ${card.last4}  ·  ${card.currency}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _statusPill(card),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  (freezeBusy || termBusy)
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: osvanGreen,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '${card.balanceFormatted()} ${card.currency}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Icon(Icons.more_horiz_rounded,
                                color: Colors.white.withOpacity(0.65)),
                          ],
                        ),
                ],
              ),
            ),

            // brand edge glow
            Positioned(
              left: -40,
              top: -40,
              child: IgnorePointer(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: edge.withOpacity(0.10),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: edge.withOpacity(0.20),
                        blurRadius: 70,
                        spreadRadius: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
