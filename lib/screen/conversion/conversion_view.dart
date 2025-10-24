// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/colors.dart';
import '../../../models/currency_model.dart';

class ConversionView extends StatefulWidget {
  const ConversionView({super.key});

  @override
  State<ConversionView> createState() => _ConversionViewState();
}

class _ConversionViewState extends State<ConversionView> {
  String? fromCurrency;
  String? toCurrency;
  final amountController = TextEditingController();

  final allCurrencies = [
    ...currencyList.map(
      (c) => {'code': c.code, 'symbol': c.symbol, 'name': c.name},
    ),
    ...stablecoins.map(
      (s) => {
        'code': s.ticker,
        'symbol': _getSymbolForStablecoin(s.ticker),
        'name': s.name,
      },
    ),
  ];

  final Map<String, double> wallet = {
    "NGN": 15000.0,
    "USD": 200.0,
    "USDT": 90.5,
    "GHS": 800.0,
    "EUR": 100.0,
    "XOF": 88000.0,
    "KES": 12000.0,
    "ZMW": 950.0,
    "TUSD": 50.0,
    "USDC": 110.0,
    "FDUSD": 40.0,
    "EUROC": 30.0,
    "GYEN": 1000.0,
    "XSGD": 180.0,
    "CADC": 70.0,
    "HKD": 600.0,
  };

  static String _getSymbolForStablecoin(String ticker) {
    switch (ticker) {
      case 'USDT':
      case 'USDC':
      case 'TUSD':
      case 'USDP':
      case 'FDUSD':
      case 'USDS':
        return '\$';
      case 'EUROC':
        return '€';
      case 'GYEN':
        return '¥';
      case 'XSGD':
        return 'S\$';
      case 'CADC':
        return 'C\$';
      case 'HKD':
        return 'HK\$';
      default:
        return ticker;
    }
  }

  void showSummaryModal() {
    final double amount = double.tryParse(amountController.text) ?? 0;
    const double rate = 1.2; // Mock rate
    const double feePercent = 0.02;
    final double fee = amount * feePercent;
    final double total = (amount - fee) * rate;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Conversion Summary",
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text("From: $fromCurrency", style: textTheme.bodyMedium),
              Text("To: $toCurrency", style: textTheme.bodyMedium),
              Text("Amount: $amount", style: textTheme.bodyMedium),
              Text(
                "Fee (2%): ${fee.toStringAsFixed(2)}",
                style: textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              Text(
                "You’ll Receive: ${total.toStringAsFixed(2)} $toCurrency",
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Get.back();
                      Get.snackbar("Success", "Conversion Completed");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: osvanGreen,
                    ),
                    child: const Text("Confirm"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildCurrencyDropdown({
    required String label,
    required String? value,
    required Function(String?) onChanged,
    String? exclude,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      value: value,
      items: allCurrencies
          .where((c) => exclude == null || c['code'] != exclude)
          .map((c) {
            return DropdownMenuItem(
              value: c['code'],
              child: Text('${c['code']} – ${c['symbol']} ${c['name']}'),
            );
          })
          .toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double currentBalance = fromCurrency != null
        ? (wallet[fromCurrency!] ?? 0.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Currency Conversion"),
        backgroundColor: osvanGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            buildCurrencyDropdown(
              label: "From Currency",
              value: fromCurrency,
              onChanged: (val) => setState(() => fromCurrency = val),
              exclude: toCurrency,
            ),
            const SizedBox(height: 8),
            Text(
              "Balance: ${currentBalance.toStringAsFixed(2)} $fromCurrency",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            buildCurrencyDropdown(
              label: "To Currency",
              value: toCurrency,
              onChanged: (val) => setState(() => toCurrency = val),
              exclude: fromCurrency,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount to Convert"),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                final amt = double.tryParse(amountController.text);

                if (fromCurrency == null ||
                    toCurrency == null ||
                    amt == null ||
                    amt <= 0) {
                  Get.snackbar("Error", "Please fill in all valid fields");
                  return;
                }

                if (fromCurrency == toCurrency) {
                  Get.snackbar("Error", "Cannot convert the same currency");
                  return;
                }

                if (amt > (wallet[fromCurrency!] ?? 0.0)) {
                  Get.snackbar("Error", "Insufficient balance");
                  return;
                }

                showSummaryModal();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: osvanGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.currency_exchange),
              label: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
