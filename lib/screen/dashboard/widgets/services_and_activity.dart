// ignore_for_file: deprecated_member_use

// services_and_activity.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/transaction/controllers/transactions_controller.dart';
import 'package:osvan_app/screen/transaction/models/transaction.dart';

import '/controller/theme_controller.dart';

class ServicesAndActivity extends StatefulWidget {
  const ServicesAndActivity({super.key});

  @override
  State<ServicesAndActivity> createState() => _ServicesAndActivityState();
}

class _ServicesAndActivityState extends State<ServicesAndActivity> {
  final _pageCtrl = PageController(viewportFraction: 0.88);
  int _page = 0;

  TransactionsController _ensureTxController() {
    if (Get.isRegistered<TransactionsController>()) {
      return Get.find<TransactionsController>();
    }
    return Get.put(TransactionsController());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDarkMode;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: isDark ? osvanWhite : osvanBlack,
        );

    _ensureTxController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PromoCarousel(
          controller: _pageCtrl,
          page: _page,
          onPageChanged: (i) => setState(() => _page = i),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Services', style: titleStyle),
            TextButton(
              onPressed: () => Get.toNamed('/services'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _ServicesRow(),

        const SizedBox(height: 24),

        Text('Recent activity', style: titleStyle),
        const SizedBox(height: 8),
        const _RecentActivityPanel(),
      ],
    );
  }
}

class _RecentTxnRow extends StatelessWidget {
  final Txn tx;
  const _RecentTxnRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final isDebit = tx.type.toLowerCase().contains('debit') ||
        tx.type.toLowerCase().contains('send');
    final amountColor = isDebit ? Colors.red : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                (isDebit ? Colors.red : osvanGreen).withOpacity(0.1),
            child: Icon(
              isDebit ? Icons.call_made : Icons.call_received,
              color: isDebit ? Colors.red : osvanGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.type,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tx.createdAt.toLocal().toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${tx.currency} ${tx.amount.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final promos = [
      {
        'title': 'Get your Osvan card',
        'body': 'Request a virtual card and start spending securely.',
        'cta': 'Request now',
      },
      {
        'title': 'Earn with referrals',
        'body': 'Invite friends and earn rewards when they transact.',
        'cta': 'Share link',
      },
      {
        'title': 'Save on FX',
        'body': 'Convert at great rates and pay globally.',
        'cta': 'View rates',
      },
    ];

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: controller,
            itemCount: promos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final p = promos[index];
              return Padding(
                padding:
                    EdgeInsets.only(right: index == promos.length - 1 ? 0 : 12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF0A8F6A), const Color(0xFF0B3954)]
                          : [const Color(0xFF28C76F), const Color(0xFF1B8A6A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title']!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p['body']!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {},
                        child: Text(p['cta']!),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(promos.length, (i) {
            final active = i == page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? (isDark ? osvanGreen : osvanBlack)
                    : Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ServicesRow extends StatelessWidget {
  const _ServicesRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surface = isDark ? const Color(0xFF151B2B) : Colors.white;
    final border = isDark ? Colors.white12 : Colors.black.withOpacity(0.06);
    final title = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white70 : Colors.black54;

    final tc = Get.find<TransactionsController>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Obx(() {
        if (tc.isLoading.value && tc.items.isEmpty) {
          return Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text('Loading recent activity...',
                  style: theme.textTheme.bodySmall),
            ],
          );
        }

        if (tc.error.value != null && tc.items.isEmpty) {
          return Column(
            children: [
              Text(
                'Failed to load recent activity',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: title,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                tc.error.value!,
                style: theme.textTheme.bodySmall?.copyWith(color: sub),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => tc.load(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          );
        }

        if (tc.items.isEmpty) {
          return Column(
            children: [
              Icon(Icons.history, size: 28, color: sub),
              const SizedBox(height: 8),
              Text(
                'No recent transactions yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: title,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Your latest wallet activity will appear here once you start using Osvan.',
                style: theme.textTheme.bodySmall?.copyWith(color: sub),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Get.toNamed('/transaction-history'),
                icon: const Icon(Icons.list_alt),
                label: const Text('View transactions'),
              ),
            ],
          );
        }

        final recent = tc.items.take(3).toList();

        return Column(
          children: [
            ...recent.map((tx) => _RecentTxnRow(tx: tx)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Get.toNamed('/transaction-history'),
                    icon: const Icon(Icons.list_alt),
                    label: const Text('View all'),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
