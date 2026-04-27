// lib/screen/transaction/views/transaction_history_view.dart
// Premium Transaction History — modern, unique, high-class (glass + filters + search + better states)
// ✅ Fixes your current build error (misplaced braces inside Obx)
// ✅ Keeps your paging logic (load next page near bottom)
// ✅ Adds premium UI without changing your controller contract
//
// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/transaction/controllers/transactions_controller.dart';
import 'package:osvan_app/screen/transaction/models/transaction.dart';

class TransactionHistoryView extends StatefulWidget {
  const TransactionHistoryView({super.key});

  @override
  State<TransactionHistoryView> createState() => _TransactionHistoryViewState();
}

class _TransactionHistoryViewState extends State<TransactionHistoryView> {
  late final TransactionsController tc;
  final _scroll = ScrollController();

  // UI state (local)
  final _query = ''.obs;
  final _filter = _TxnFilter.all.obs;

  @override
  void initState() {
    super.initState();
    tc = Get.put(TransactionsController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (tc.items.isEmpty && !tc.isLoading.value) {
        tc.load(reset: true);
      }
    });

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 220) {
        if (!tc.isLoadingMore.value && !tc.isLoading.value) {
          tc.load(); // next page
        }
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _isDebit(Txn tx) {
    final t = tx.type.toLowerCase();
    return t.contains('debit') || t.contains('send');
  }

  List<Txn> _applyFilters(List<Txn> input) {
    final q = _query.value.trim().toLowerCase();
    final f = _filter.value;

    return input.where((tx) {
      final matchesQuery = q.isEmpty ||
          tx.type.toLowerCase().contains(q) ||
          (tx.narration ?? '').toLowerCase().contains(q) ||
          tx.currency.toLowerCase().contains(q) ||
          tx.id.toLowerCase().contains(q);

      final matchesFilter = switch (f) {
        _TxnFilter.all => true,
        _TxnFilter.inflow => !_isDebit(tx),
        _TxnFilter.outflow => _isDebit(tx),
      };

      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF0B1220), Color(0xFF111827)]
              : const [Color(0xFFF6FAFF), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Transaction History"),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: isDark ? Colors.white : Colors.black,
        ),
        body: Stack(
          children: [
            Positioned(
              top: -90,
              left: -80,
              child: _GlowBlob(
                color: osvanGreen.withOpacity(isDark ? .18 : .10),
                size: 240,
              ),
            ),
            Positioned(
              bottom: -110,
              right: -90,
              child: _GlowBlob(
                color: const Color(0xFF60A5FA).withOpacity(isDark ? .15 : .09),
                size: 280,
              ),
            ),
            Obx(() {
              // loading first page
              if (tc.isLoading.value && tc.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              // hard error (no data)
              if (tc.error.value != null && tc.items.isEmpty) {
                return _ErrorState(
                  msg: tc.error.value!,
                  onRetry: () => tc.load(reset: true),
                );
              }

              final filtered = _applyFilters(tc.items);

              // empty state (after load)
              if (!tc.isLoading.value && filtered.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => tc.refreshNow(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HeaderRow(
                                title: "Your activity",
                                subtitle:
                                    "Search, filter, and pull down to refresh.",
                                isDark: isDark,
                              ),
                              const SizedBox(height: 14),
                              _SearchBar(
                                hint: "Search type, narration, currency, ID…",
                                onChanged: (v) => _query.value = v,
                              ),
                              const SizedBox(height: 12),
                              _FilterChips(
                                value: _filter.value,
                                onChanged: (v) => _filter.value = v,
                              ),
                              const SizedBox(height: 18),
                              const SizedBox(height: 40),
                              Icon(Icons.receipt_long,
                                  size: 54,
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withOpacity(0.35)),
                              const SizedBox(height: 12),
                              Text(
                                'No transactions yet',
                                style: th.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'When you send/receive or fund your wallet, it will appear here.',
                                style: th.textTheme.bodySmall?.copyWith(
                                  color: th.textTheme.bodySmall?.color
                                      ?.withOpacity(0.70),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: OutlinedButton.icon(
                                  onPressed: () => tc.load(reset: true),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reload'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // normal list
              return RefreshIndicator(
                onRefresh: () => tc.refreshNow(),
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _HeaderRow(
                                  title: "Your activity",
                                  subtitle:
                                      "${filtered.length} transaction(s) shown",
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 14),
                                _SearchBar(
                                  hint: "Search type, narration, currency, ID…",
                                  onChanged: (v) => _query.value = v,
                                ),
                                const SizedBox(height: 12),
                                _FilterChips(
                                  value: _filter.value,
                                  onChanged: (v) => _filter.value = v,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList.separated(
                        itemBuilder: (context, index) {
                          final tx = filtered[index];
                          return _TxnCard(tx: tx);
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: filtered.length,
                      ),
                    ),
                    if (tc.isLoadingMore.value)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

enum _TxnFilter { all, inflow, outflow }

class _TxnCard extends StatelessWidget {
  final Txn tx;
  const _TxnCard({required this.tx});

  bool _isDebit() {
    final t = tx.type.toLowerCase();
    return t.contains('debit') || t.contains('send');
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final isDebit = _isDebit();
    final accent = isDebit ? Colors.red : osvanGreen;

    return _GlassCard(
      child: InkWell(
        onTap: () => Get.toNamed('/transaction-detail', arguments: tx),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withOpacity(0.22)),
                ),
                child: Icon(
                  isDebit ? Icons.call_made : Icons.call_received,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleFor(tx),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: th.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dateFmt(tx.createdAt),
                      style: th.textTheme.bodySmall?.copyWith(
                        color: th.textTheme.bodySmall?.color?.withOpacity(0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((tx.narration ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        tx.narration!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: th.textTheme.bodySmall?.copyWith(
                          color:
                              th.textTheme.bodySmall?.color?.withOpacity(0.70),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _amountFmt(tx.amount, tx.currency),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx.currency,
                    style: th.textTheme.bodySmall?.copyWith(
                      color: th.textTheme.bodySmall?.color?.withOpacity(0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded,
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(Txn t) {
    final tpe = t.type.toLowerCase();
    if (tpe.contains('debit') || tpe.contains('send')) return 'Money sent';
    if (tpe.contains('credit') || tpe.contains('receive')) {
      return 'Money received';
    }
    return 'Transaction';
  }

  String _amountFmt(double a, String ccy) =>
      '${_symbol(ccy)}${a.toStringAsFixed(2)}';

  String _dateFmt(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}, ${d.year}';
  }

  String _symbol(String code) {
    const map = {
      'NGN': '₦',
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'XOF': 'CFA',
      'AED': 'د.إ',
      'KES': 'KSh',
      'GHS': '₵',
      'UGX': 'USh',
      'ZMW': 'ZK',
      'MWK': 'MK',
      'GNF': 'FG',
      'CNY': '¥',
      'CDF': 'FC',
      'SGD': 'S\$',
      'AUD': 'A\$',
      'BTC': '₿',
      'ETH': 'Ξ',
    };
    return map[code] ?? '';
  }
}

class _HeaderRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;

  const _HeaderRow({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: th.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: th.textTheme.bodySmall?.copyWith(
                  color: th.textTheme.bodySmall?.color?.withOpacity(0.70),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF60A5FA).withOpacity(isDark ? 0.14 : 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF60A5FA).withOpacity(isDark ? 0.28 : 0.22),
            ),
          ),
          child: Text(
            'LIVE',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.10),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: osvanGreen, width: 1.3),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final _TxnFilter value;
  final ValueChanged<_TxnFilter> onChanged;

  const _FilterChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String t, _TxnFilter v) {
      final selected = value == v;
      return ChoiceChip(
        label: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
        selected: selected,
        onSelected: (_) => onChanged(v),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        chip('All', _TxnFilter.all),
        chip('Inflow', _TxnFilter.inflow),
        chip('Outflow', _TxnFilter.outflow),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0F172A) : Colors.white)
                .withOpacity(isDark ? 0.72 : 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.10),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                color: Colors.black.withOpacity(isDark ? 0.30 : 0.08),
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 60,
              spreadRadius: 10,
              color: color.withOpacity(0.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorState({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded,
                    size: 42,
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.55)),
                const SizedBox(height: 10),
                Text(
                  'Failed to load transactions',
                  style: th.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  msg,
                  style: th.textTheme.bodySmall?.copyWith(
                    color: th.textTheme.bodySmall?.color?.withOpacity(0.70),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(backgroundColor: osvanGreen),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
