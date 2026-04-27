// lib/screen/transaction/views/transaction_detail_view.dart
// Premium Receipt — modern, unique, high class (glass receipt + copy rows + share fix)
// ✅ Fixes SharePlus misuse: use Share.share(text)
// ✅ Replaces withValues(alpha: ...) with withOpacity(...) for compatibility
//
// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/transaction/controllers/transactions_controller.dart';
import 'package:osvan_app/screen/transaction/models/transaction.dart';
import 'package:share_plus/share_plus.dart';

class TransactionDetailView extends StatelessWidget {
  const TransactionDetailView({super.key});

  Txn? _resolveTxn() {
    final arg = Get.arguments;
    if (arg is Txn) return arg;

    if (arg is Map<String, dynamic>) {
      try {
        return Txn.fromJson(arg);
      } catch (_) {}
    }

    if (arg is String) {
      if (Get.isRegistered<TransactionsController>()) {
        final tc = Get.find<TransactionsController>();
        for (final t in tc.items) {
          if (t.id == arg) return t;
        }
      }
    }
    return null;
  }

  bool _isDebit(Txn tx) {
    final t = tx.type.toLowerCase();
    return t.contains('debit') || t.contains('send');
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final tx = _resolveTxn();

    if (tx == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 48),
                const SizedBox(height: 12),
                const Text('Transaction data unavailable'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final argMap = Get.arguments is Map<String, dynamic>
        ? Get.arguments as Map<String, dynamic>
        : <String, dynamic>{};

    final isDebit = _isDebit(tx);
    final accent = isDebit ? Colors.red : osvanGreen;

    final provider = _providerOrBank(argMap);
    final reference =
        (argMap['reference'] ?? argMap['ref'] ?? tx.id).toString();

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
          title: const Text('Transaction Receipt'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : Colors.black,
          actions: [
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Share',
              onPressed: () => _shareText(tx, reference, provider),
            ),
          ],
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
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                                isDebit ? 'Money Sent' : 'Money Received',
                                style: th.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dateFmt(tx.createdAt),
                                style: th.textTheme.bodySmall?.copyWith(
                                  color: th.textTheme.bodySmall?.color
                                      ?.withOpacity(0.70),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF60A5FA)
                                .withOpacity(isDark ? .14 : .12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF60A5FA)
                                  .withOpacity(isDark ? .28 : .22),
                            ),
                          ),
                          child: Text(
                            'RECEIPT',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(isDark ? 0.16 : 0.10),
                            shape: BoxShape.circle,
                            border: Border.all(color: accent.withOpacity(0.22)),
                          ),
                          child: Icon(Icons.attach_money, color: accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Amount',
                                style: th.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: th.textTheme.bodySmall?.color
                                      ?.withOpacity(0.75),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${_symbol(tx.currency)}${tx.amount.toStringAsFixed(2)}',
                                    style: th.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      tx.currency,
                                      style: th.textTheme.bodySmall?.copyWith(
                                        color: th.textTheme.bodySmall?.color
                                            ?.withOpacity(0.65),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _CopyKV(label: 'Type', value: tx.type),
                        _CopyKV(label: 'Transaction ID', value: tx.id),
                        _CopyKV(label: 'Reference', value: reference),
                        _CopyKV(label: 'Currency', value: tx.currency),
                        _CopyKV(label: 'Bank/Provider', value: provider),
                        if ((tx.narration ?? '').trim().isNotEmpty)
                          _CopyKV(
                              label: 'Narration', value: tx.narration!.trim()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FootNote(
                  isDark: isDark,
                  text:
                      'Tip: You can copy any field. Use Share to send this receipt to a customer or vendor.',
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _shareText(Txn tx, String reference, String provider) {
    final details = '''
OSVAN TRANSACTION RECEIPT

Type: ${tx.type}
Amount: ${_symbol(tx.currency)}${tx.amount.toStringAsFixed(2)} (${tx.currency})
Date: ${_dateFmt(tx.createdAt)}
Transaction ID: ${tx.id}
Reference: $reference
Bank/Provider: $provider
Narration: ${tx.narration ?? '-'}
''';
    Share.share(details);
  }

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
    return '${d.day} ${months[d.month - 1]}, ${d.year} at ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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

  String _providerOrBank(Map<String, dynamic> arg) {
    final candidates = [
      arg['bankName'],
      arg['providerName'],
      arg['bank'],
      arg['provider'],
      arg['providerOrBank'],
    ];
    final v = candidates
        .map((e) => (e ?? '').toString().trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    return v.isEmpty ? '-' : v;
  }
}

// ─────────────────────────────────────────────────────────────
// UI helpers (local)
// ─────────────────────────────────────────────────────────────

class _CopyKV extends StatelessWidget {
  final String label;
  final String value;

  const _CopyKV({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (Get.isSnackbarOpen) return;
        Get.snackbar(
          'Copied',
          '$label copied',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: th.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: th.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    const Color(0xFF60A5FA).withOpacity(isDark ? 0.14 : 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      const Color(0xFF60A5FA).withOpacity(isDark ? 0.28 : 0.22),
                ),
              ),
              child: Icon(
                Icons.copy_rounded,
                size: 18,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
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

class _FootNote extends StatelessWidget {
  final String text;
  final bool isDark;

  const _FootNote({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined,
              size: 18, color: osvanGreen.withOpacity(0.95)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.72),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
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
