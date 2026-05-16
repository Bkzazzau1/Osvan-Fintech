// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/dashboard/widgets/action_grid.dart';
import 'package:osvan_app/screen/dashboard/widgets/financial_pulse_strip.dart';
import 'package:osvan_app/screen/dashboard/widgets/services_and_activity.dart';
import 'package:osvan_app/screen/dashboard/widgets/smart_insight_card.dart';
import 'package:osvan_app/screen/dashboard/widgets/trust_signal_strip.dart';
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
    final scrollBottomPadding = kBottomNavigationBarHeight + 44 + bottomSafe;

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
                  const SliverToBoxAdapter(child: SizedBox(height: 0)),
                  SliverPadding(
                    padding:
                        EdgeInsets.fromLTRB(14, 0, 14, scrollBottomPadding),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        const WalletBalanceSection(),

                        const SizedBox(height: 12),
                        const FinancialPulseStrip(),
                        const SizedBox(height: 12),
                        const SmartInsightCard(),
                        const SizedBox(height: 12),
                        const TrustSignalStrip(),

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

                        const SizedBox(height: 16),

                        // Quick actions
                        const SectionCard(
                          title: 'Quick actions',
                          subtitle: 'Transfers, crypto, funding & conversion',
                          child: ActionGrid(),
                        ),

                        const SizedBox(height: 14),

                        const ServicesAndActivity(),

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
            top: -150,
            left: -120,
            child: _GlowBlob(color: osvanGreen, size: 320, opacity: 0.12),
          ),
          Positioned(
            top: 210,
            right: -130,
            child: _GlowBlob(
                color: const Color(0xFF60A5FA), size: 300, opacity: 0.12),
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
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(opacity),
              blurRadius: 80,
              spreadRadius: 24,
            ),
          ],
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
              fontWeight: FontWeight.w900,
              letterSpacing: 0.1,
              fontSize: 18,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: t.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.62),
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
        RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.90),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
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
