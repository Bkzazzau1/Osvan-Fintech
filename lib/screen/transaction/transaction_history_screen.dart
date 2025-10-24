// ignore_for_file: deprecated_member_use

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

  @override
  void initState() {
    super.initState();
    tc = Get.put(TransactionsController(), permanent: true);

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        if (!tc.isLoadingMore.value && !tc.isLoading.value) {
          tc.load(); // load next page
        }
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Transaction History"),
          backgroundColor: osvanGreen),
      body: Obx(() {
        if (tc.isLoading.value && tc.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (tc.error.value != null && tc.items.isEmpty) {
          return _ErrorState(
              msg: tc.error.value!, onRetry: () => tc.load(reset: true));
        }
        return RefreshIndicator(
          onRefresh: () => tc.refreshNow(),
          child: ListView.separated(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: tc.items.length + (tc.isLoadingMore.value ? 1 : 0),
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (context, index) {
              if (index >= tc.items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final Txn tx = tc.items[index];
              return _TxnTile(tx: tx);
            },
          ),
        );
      }),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final Txn tx;
  const _TxnTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isDebit = tx.type.toLowerCase().contains('debit') ||
        tx.type.toLowerCase().contains('send');
    final amountColor = isDebit ? Colors.red : Colors.green;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: osvanGreen.withOpacity(0.1),
        child: Icon(isDebit ? Icons.call_made : Icons.call_received,
            color: osvanGreen),
      ),
      title: Text(_titleFor(tx)),
      subtitle: Text(_dateFmt(tx.createdAt)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_amountFmt(tx.amount, tx.currency),
              style:
                  TextStyle(color: amountColor, fontWeight: FontWeight.bold)),
          if (tx.narration != null && tx.narration!.isNotEmpty)
            Text(tx.narration!,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      onTap: () => Get.toNamed('/transaction-detail', arguments: tx.id),
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

class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorState({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load transactions:\n$msg',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
