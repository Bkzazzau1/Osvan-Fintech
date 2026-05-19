// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/config/env.dart';
import 'package:osvan_app/config/feature_flags.dart';
import 'package:osvan_app/routes/app_routes.dart';
import 'package:osvan_app/screen/conversion/conversion_view.dart';
import 'package:osvan_app/screen/crypto/view/crypto_view.dart';
import 'package:osvan_app/screen/transaction/controllers/transactions_controller.dart';
import 'package:osvan_app/screen/transaction/models/transaction.dart';

class ServicesAndActivity extends StatefulWidget {
  const ServicesAndActivity({super.key});

  @override
  State<ServicesAndActivity> createState() => _ServicesAndActivityState();
}

class _ServicesAndActivityState extends State<ServicesAndActivity> {
  final _pageCtrl = PageController(viewportFraction: 0.92);
  int _page = 0;

  TransactionsController _ensureTxController() {
    if (Get.isRegistered<TransactionsController>()) {
      return Get.find<TransactionsController>();
    }
    return Get.put(TransactionsController());
  }

  @override
  void initState() {
    super.initState();
    _ensureTxController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'Discover',
          subtitle: FeatureFlags.cryptoUiEnabled
              ? 'Fast routes to cards, crypto and FX'
              : 'Fast routes to cards, wallets and FX',
          actionLabel: FeatureFlags.cryptoUiEnabled ? 'Explore' : 'Cards',
          onAction: FeatureFlags.cryptoUiEnabled
              ? () => Get.to(() => CryptoView(baseUrl: Env.apiBaseUrl))
              : () => Get.toNamed(AppRoutes.createCard),
        ),
        const SizedBox(height: 10),
        _PromoCarousel(
          controller: _pageCtrl,
          page: _page,
          onPageChanged: (i) => setState(() => _page = i),
        ),
        const SizedBox(height: 16),
        _SectionHeading(
          title: 'Recent activity',
          subtitle: 'Latest wallet movement',
          actionLabel: 'View all',
          onAction: () => Get.toNamed('/transaction-history'),
        ),
        const SizedBox(height: 10),
        const _RecentActivityPanel(),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF60A5FA),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _PromoCarousel extends StatelessWidget {
  final PageController controller;
  final int page;
  final ValueChanged<int> onPageChanged;

  const _PromoCarousel({
    required this.controller,
    required this.page,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final promos = [
      _Promo(
        title: 'Virtual cards',
        body: 'Create secure cards for online payments.',
        cta: 'Request',
        icon: Icons.credit_card_rounded,
        accent: const Color(0xFF60A5FA),
        onTap: () => Get.toNamed(AppRoutes.createCard),
      ),
      if (FeatureFlags.cryptoUiEnabled)
        _Promo(
          title: 'Crypto rails',
          body: 'Receive and send stablecoins with network controls.',
          cta: 'Open',
          icon: Icons.currency_bitcoin_rounded,
          accent: const Color(0xFFF59E0B),
          onTap: () => Get.to(() => CryptoView(baseUrl: Env.apiBaseUrl)),
        ),
      _Promo(
        title: 'FX conversion',
        body: 'Swap wallet balances with live quotes.',
        cta: 'Convert',
        icon: Icons.sync_alt_rounded,
        accent: const Color(0xFFA78BFA),
        onTap: () => Get.to(() => const ConversionView()),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 142,
          child: PageView.builder(
            controller: controller,
            itemCount: promos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final p = promos[index];
              return Padding(
                padding:
                    EdgeInsets.only(right: index == promos.length - 1 ? 0 : 10),
                child: _PromoCard(promo: p),
              );
            },
          ),
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(promos.length, (i) {
            final active = i == page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 22 : 8,
              height: 7,
              decoration: BoxDecoration(
                color:
                    active ? promos[i].accent : Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  final _Promo promo;

  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: promo.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0F172A).withOpacity(0.98),
                promo.accent.withOpacity(0.24),
                const Color(0xFF08111F).withOpacity(0.98),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: promo.accent.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: promo.accent.withOpacity(0.10),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -28,
                top: -32,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: promo.accent.withOpacity(0.10),
                    border: Border.all(color: promo.accent.withOpacity(0.08)),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: promo.accent.withOpacity(0.16),
                          border:
                              Border.all(color: promo.accent.withOpacity(0.24)),
                        ),
                        child: Icon(promo.icon, color: promo.accent, size: 22),
                      ),
                      const Spacer(),
                      _MiniButton(label: promo.cta, accent: promo.accent),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    promo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    promo.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.68),
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel();

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<TransactionsController>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A).withOpacity(0.96),
            const Color(0xFF111C33).withOpacity(0.92),
            const Color(0xFF08111F).withOpacity(0.98),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
      child: Obx(() {
        if (tc.isLoading.value && tc.items.isEmpty) {
          return const _ActivityState(
            icon: Icons.sync_rounded,
            title: 'Loading activity',
            subtitle: 'Fetching latest wallet movement...',
            loading: true,
          );
        }

        if (tc.error.value != null && tc.items.isEmpty) {
          return _ActivityState(
            icon: Icons.warning_amber_rounded,
            title: 'Activity unavailable',
            subtitle: tc.error.value!,
            actionLabel: 'Retry',
            onAction: () => tc.load(reset: true),
          );
        }

        if (tc.items.isEmpty) {
          return _ActivityState(
            icon: Icons.history_rounded,
            title: 'No activity yet',
            subtitle: 'Your latest wallet movement will appear here.',
            actionLabel: 'View history',
            onAction: () => Get.toNamed('/transaction-history'),
          );
        }

        final recent = tc.items.take(3).toList();

        return Column(
          children: [
            for (var i = 0; i < recent.length; i++) ...[
              _RecentTxnRow(tx: recent[i]),
              if (i != recent.length - 1) _ActivityDivider(),
            ],
          ],
        );
      }),
    );
  }
}

class _RecentTxnRow extends StatelessWidget {
  final Txn tx;

  const _RecentTxnRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final lower = tx.type.toLowerCase();
    final isDebit = lower.contains('debit') ||
        lower.contains('send') ||
        lower.contains('withdraw');
    final accent = isDebit ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final sign = isDebit ? '-' : '+';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Get.toNamed('/transaction-detail', arguments: tx),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.14),
                border: Border.all(color: accent.withOpacity(0.22)),
              ),
              child: Icon(
                isDebit ? Icons.north_east_rounded : Icons.south_west_rounded,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleCase(tx.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(tx.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.54),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign${tx.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tx.currency,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.54),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final d = value.toLocal();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/${d.year} $hour:$minute';
  }

  static String _titleCase(String value) {
    final cleaned = value.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return 'Transaction';
    return cleaned
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class _ActivityState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  const _ActivityState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF60A5FA).withOpacity(0.12),
              border: Border.all(
                color: const Color(0xFF60A5FA).withOpacity(0.20),
              ),
            ),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: const Color(0xFF60A5FA), size: 23),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final Color accent;

  const _MiniButton({
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.94),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ActivityDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Colors.white.withOpacity(0.07),
    );
  }
}

class _Promo {
  final String title;
  final String body;
  final String cta;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _Promo({
    required this.title,
    required this.body,
    required this.cta,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
}
