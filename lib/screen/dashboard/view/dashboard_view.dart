// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/screen/dashboard/widgets/action_grid.dart';
import 'package:osvan_app/screen/dashboard/widgets/services_and_activity.dart';
import 'package:osvan_app/screen/dashboard/widgets/wallet_balance_section.dart';
import 'package:osvan_app/screen/wallet/controllers/wallets_controller.dart';
import 'package:osvan_app/screen/wallet/services/config_service.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  Future<void> _handleRefresh() async {
    final wc = Get.find<WalletsController>();
    try {
      await wc.load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wallets refreshed'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = Get.find<ConfigService>();

    final usdOnly = cfg.usdCardOnly;
    final canFund = cfg.cardsFundEnabled;
    final canWithdraw = cfg.cardsWithdrawEnabled;

    final List<Widget> notices = [];
    if (usdOnly) {
      notices.add(const _NoticeChip(
        text: 'Cards are USD-only for now.',
        icon: Icons.info_outline,
      ));
    }
    if (!canFund || !canWithdraw) {
      final parts = [
        if (!canFund) 'funding',
        if (!canWithdraw) 'withdrawal',
      ].join(' & ');
      notices.add(_NoticeChip(
        text: 'Card $parts temporarily disabled.',
        icon: Icons.warning_amber_outlined,
      ));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  const WalletBalanceSection(), // reactive inside
                  if (notices.isNotEmpty) const SizedBox(height: 12),
                  if (notices.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: notices,
                    ),
                  const SizedBox(height: 24),
                  const ActionGrid(),
                  const SizedBox(height: 24),
                  const ServicesAndActivity(),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeChip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _NoticeChip({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? Colors.white10 : Colors.black.withOpacity(0.05);
    final fg = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg.withOpacity(0.8)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
