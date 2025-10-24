// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/wallet/controllers/wallets_controller.dart';
import 'package:osvan_app/screen/wallet/models/wallet.dart';
import 'package:osvan_app/screen/wallet/services/wallets_service.dart';

class WalletBalanceSection extends StatefulWidget {
  const WalletBalanceSection({super.key});

  @override
  State<WalletBalanceSection> createState() => _WalletBalanceSectionState();
}

class _WalletBalanceSectionState extends State<WalletBalanceSection> {
  String? _selectedCode; // currency_code like "NGN", "USD"
  bool _busy = false;

  // Recent transactions (simple maps): [{amount, currency, type, created_at, status, narration}]
  List<Map<String, dynamic>> _recentTx = const [];
  bool _txLoading = false;
  String? _txError;

  @override
  Widget build(BuildContext context) {
    final wc = Get.find<WalletsController>();

    return Obx(() {
      if (wc.isLoading.value) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: osvanGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      }

      if (wc.error.value != null) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: osvanGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Failed to load wallets: ${wc.error.value}',
            style: const TextStyle(color: Colors.white),
          ),
        );
      }

      final List<Wallet> wallets = wc.wallets;
      if (wallets.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: osvanGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'No wallets yet',
            style: TextStyle(color: Colors.white),
          ),
        );
      }

      // Default selection: controller primary or first wallet
      final codes = wallets.map((w) => w.currencyCode).toList();
      final primaryFromController = wc.primaryCurrency.value;
      final initialCode = (primaryFromController.isNotEmpty &&
              codes.contains(primaryFromController))
          ? primaryFromController
          : wallets.first.currencyCode;

      final prevSelected = _selectedCode;
      _selectedCode = (_selectedCode != null && codes.contains(_selectedCode))
          ? _selectedCode
          : initialCode;

      final selected =
          wallets.firstWhere((w) => w.currencyCode == _selectedCode);

      // If the currency selection changed, load its recent transactions
      if (prevSelected != _selectedCode) {
        _loadRecentTransactionsFor(_selectedCode!);
      }

      Future<void> openAddMoneyDialog() async {
        final amountCtl = TextEditingController();
        final narrationCtl = TextEditingController();
        String? errorText;
        bool submitting = false;

        await showDialog(
          context: context,
          barrierDismissible: !submitting,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setLocal) {
                Future<void> submit() async {
                  if (submitting) return;
                  final raw = amountCtl.text.trim();
                  final val = double.tryParse(raw);
                  if (raw.isEmpty || val == null || val <= 0) {
                    setLocal(() => errorText = 'Enter a valid amount');
                    return;
                  }

                  setLocal(() {
                    errorText = null;
                    submitting = true;
                  });

                  try {
                    await WalletsService.instance.creditWallet(
                      currency: selected.currencyCode,
                      amount: val.toStringAsFixed(2),
                      narration: narrationCtl.text.trim().isEmpty
                          ? null
                          : narrationCtl.text.trim(),
                    );
                    await wc.load(); // refresh observable balance
                    await _loadRecentTransactionsFor(
                        selected.currencyCode); // refresh tx list
                    if (mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Added ${_symbolFor(selected.currencyCode)}${val.toStringAsFixed(2)} to ${selected.currencyCode}',
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  } catch (e) {
                    setLocal(() {
                      errorText = 'Add Money failed: $e';
                      submitting = false;
                    });
                  }
                }

                return AlertDialog(
                  title: Text('Add Money (${selected.currencyCode})'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: amountCtl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: _symbolFor(selected.currencyCode),
                          errorText: errorText,
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: narrationCtl,
                        decoration: const InputDecoration(
                          labelText: 'Narration (optional)',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          submitting ? null : () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: submitting ? null : submit,
                      child: submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Add'),
                    ),
                  ],
                );
              },
            );
          },
        );
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: osvanGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SemiBold(
                text: 'Wallet Balance', color: Colors.white, size: 16),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Bold(
                  text:
                      '${_symbolFor(selected.currencyCode)}${selected.balance.toStringAsFixed(2)}',
                  color: Colors.white,
                  size: 28,
                ),
                Flexible(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: osvanGreen,
                    value: _selectedCode,
                    icon:
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                    underline: const SizedBox(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedCode = value);
                      Get.find<WalletsController>().setPrimaryByCode(value);
                      _loadRecentTransactionsFor(
                          value); // reload tx when switching currency
                    },
                    items: wallets.map((w) {
                      final code = w.currencyCode;
                      final symbol = _symbolFor(code);
                      return DropdownMenuItem(
                        value: code,
                        child: Text(
                          '$symbol ($code)',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: wc.load,
                  child: const Text('Refresh'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await openAddMoneyDialog();
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  icon: _busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('Add Money'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // --- Recent activity ---
            _RecentActivity(
              loading: _txLoading,
              error: _txError,
              items: _recentTx,
              symbolFor: _symbolFor,
            ),
          ],
        ),
      );
    });
  }

  Future<void> _loadRecentTransactionsFor(String currency) async {
    setState(() {
      _txLoading = true;
      _txError = null;
    });
    try {
      final items = await WalletsService.instance
          .fetchRecentTransactions(currency: currency, limit: 3);
      setState(() {
        _recentTx = items;
      });
    } catch (e) {
      setState(() {
        _txError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _txLoading = false);
      }
    }
  }

  // quick symbol map; extend as needed
  String _symbolFor(String code) {
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
    };
    return map[code] ?? '';
  }
}

class _RecentActivity extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> items;
  final String Function(String code) symbolFor;

  const _RecentActivity({
    required this.loading,
    required this.error,
    required this.items,
    required this.symbolFor,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _SectionShell(
        title: 'Recent activity',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      );
    }
    if (error != null) {
      return _SectionShell(
        title: 'Recent activity',
        child: Text(
          'Could not load transactions: $error',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    if (items.isEmpty) {
      return const _SectionShell(
        title: 'Recent activity',
        child: Text(
          'No recent transactions',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return _SectionShell(
      title: 'Recent activity',
      child: Column(
        children: items.take(3).map((tx) {
          final amount = (tx['amount'] ?? '0').toString();
          final currency = (tx['currency'] ?? '').toString();
          final type = (tx['type'] ?? tx['tx_type'] ?? '')
              .toString()
              .toUpperCase(); // CREDIT/DEBIT
          final status = (tx['status'] ?? '').toString().toUpperCase();
          final created = (tx['created_at'] ?? tx['created'] ?? '').toString();
          final narration = (tx['narration'] ?? '').toString();

          final sign = type == 'DEBIT' ? '-' : '+';
          final symbol = symbolFor(currency);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    type == 'DEBIT' ? Icons.south_west : Icons.north_east,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(narration.isEmpty ? type : narration,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        created,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$sign$symbol$amount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white24, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Bold extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  const _Bold({required this.text, required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            color: color, fontSize: size, fontWeight: FontWeight.bold),
      );
}

class _SemiBold extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  const _SemiBold(
      {required this.text, required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            color: color, fontSize: size, fontWeight: FontWeight.w600),
      );
}
