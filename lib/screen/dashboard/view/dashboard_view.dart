// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Get.find<WalletsController>().startAutoRefresh();
      } catch (_) {
        // ignore
      }
    });
  }

  Future<void> _handleRefresh() async {
    final wc = Get.find<WalletsController>();
    try {
      await wc.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallets refreshed'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refresh failed: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = Get.find<ConfigService>();
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final scrollBottomPadding = kBottomNavigationBarHeight + 40 + bottomSafe;

    // actionable notices only
    final canFund = cfg.cardsFundEnabled;
    final canWithdraw = cfg.cardsWithdrawEnabled;

    final List<Widget> notices = [];
    if (!canFund || !canWithdraw) {
      final parts = [
        if (!canFund) 'funding',
        if (!canWithdraw) 'withdrawal',
      ].join(' & ');
      notices.add(_NoticeChip(
        text: 'Card $parts temporarily disabled.',
        icon: Icons.warning_amber_rounded,
      ));
    }

    // ✅ Single-mode: Premium Dark Theme wrapper (Dashboard only)
    final dark = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF070B14),
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: osvanGreen,
        secondary: osvanGreen,
      ),
    );

    return Theme(
      data: dark,
      child: Scaffold(
        backgroundColor: const Color(0xFF070B14),
        body: Stack(
          children: [
            // Background: deep luxury gradient + soft glow
            const _LuxuryBackground(),

            RefreshIndicator(
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        16, 0, 16, scrollBottomPadding),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        // Header (small, classy)
                        const _DashboardHeader(),
                        const SizedBox(height: 14),

                        // Wallets
                        const SectionCard(
                          title: 'Wallets',
                          subtitle: 'Balances & quick overview',
                          child: WalletBalanceSection(),
                        ),

                        if (notices.isNotEmpty) const SizedBox(height: 12),
                        if (notices.isNotEmpty)
                          SectionCard(
                            noPadding: true,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: notices,
                              ),
                            ),
                          ),

                        const SizedBox(height: 14),

                        // Quick actions
                        const SectionCard(
                          title: 'Quick actions',
                          subtitle: 'Send, receive, pay bills & more',
                          child: ActionGrid(),
                        ),

                        const SizedBox(height: 14),

                        // Services & Activity
                        const SectionCard(
                          title: 'Services & activity',
                          subtitle: 'Cards, transactions, utilities',
                          child: ServicesAndActivity(),
                        ),

                        const SizedBox(height: 28),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Small “brand pill”
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: const Color(0xFF0F172A), // rule: big card color
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: osvanGreen,
                  boxShadow: [
                    BoxShadow(
                      color: osvanGreen.withOpacity(0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Osvan',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
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
        children: [
          // glow blobs
          Positioned(
            top: -120,
            left: -80,
            child: _GlowBlob(color: osvanGreen, size: 260, opacity: 0.12),
          ),
          Positioned(
            top: 140,
            right: -120,
            child:
                _GlowBlob(color: Colors.blueAccent, size: 260, opacity: 0.10),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child:
                _GlowBlob(color: Colors.purpleAccent, size: 300, opacity: 0.08),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowBlob({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: size,
            height: size,
            color: color.withOpacity(opacity),
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final bool noPadding;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.noPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || subtitle != null) ...[
          Text(
            title ?? '',
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: t.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.70),
                height: 1.2,
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],

        // Premium glass card
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.92), // rule
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: noPadding
                  ? child
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: child,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticeChip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _NoticeChip({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white.withOpacity(0.92)),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.90),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
