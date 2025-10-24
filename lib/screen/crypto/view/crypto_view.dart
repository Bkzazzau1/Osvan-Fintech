// lib/screen/crypto/view/crypto_view.dart
// Orchestrates UI only. Logic lives in controller/service.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ for status bar / overlay style
import 'package:get/get.dart';
import 'package:osvan_app/controller/crypto_controller.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/crypto/widgets/receive_sheet.dart';
import 'package:osvan_app/screen/crypto/widgets/send_sheet.dart';
import 'package:osvan_app/services/auth_service.dart'; // ✅ provides AuthService.getToken()
import 'package:osvan_app/services/crypto_service.dart';

class CryptoView extends StatefulWidget {
  final String baseUrl;
  const CryptoView({super.key, required this.baseUrl});

  @override
  State<CryptoView> createState() => _CryptoViewState();
}

class _CryptoViewState extends State<CryptoView> {
  String? _selectedCoin;
  late final CryptoController c;

  @override
  void initState() {
    super.initState();
    // ✅ Create controller ONCE for fast first paint, attach JWT via tokenProvider
    c = Get.put(
      CryptoController(
        CryptoService(
          baseUrl: widget.baseUrl, // e.g., https://fintech.osvan.africa/api/v1
          tokenProvider: () async {
            // Return bare JWT (no "Bearer ")
            return await AuthService.getToken();
          },
        ),
      ),
      permanent: true,
    );

    // ✅ Prime data after first frame (coins, balances, txs)
    Future.microtask(() => c.refreshAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto'),
        backgroundColor: osvanGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        // ✅ force constant white header text & icons
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          Obx(
            () => IconButton(
              onPressed: c.isLoading.value ? null : c.refreshAll,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: Obx(() {
        // unique + sorted
        final coins = c.balances.map((b) => b.coin).toSet().toList()..sort();

        // ✅ aggregate balances by coin (sum across networks)
        final Map<String, double> totals = {};
        for (final b in c.balances) {
          totals[b.coin] = (totals[b.coin] ?? 0) + b.balance;
        }

        // pick default (USDT if exists)
        if (coins.isNotEmpty &&
            (_selectedCoin == null || !coins.contains(_selectedCoin))) {
          _selectedCoin = coins.contains('USDT') ? 'USDT' : coins.first;
        }

        if (c.isLoading.value && c.balances.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final activeCoin =
            _selectedCoin ??
            (coins.contains('USDT')
                ? 'USDT'
                : (coins.isNotEmpty ? coins.first : 'USDT'));

        // ✅ use aggregated total per coin
        final activeBal = totals[activeCoin] ?? 0.0;

        return RefreshIndicator(
          onRefresh: c.refreshAll,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // coin chips
              if (coins.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: coins.map((coin) {
                      final selected =
                          coin ==
                          (_selectedCoin ??
                              (coins.contains('USDT') ? 'USDT' : coins.first));
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(coin),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedCoin = coin),
                          selectedColor: osvanGreen,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 12),

              // active balance
              _BalanceCard(coin: activeCoin, amount: activeBal),

              const SizedBox(height: 16),

              // list of balances
              ...c.balances.map(
                (b) => _BalanceTile(
                  coin: b.coin,
                  network: b.network,
                  amount: b.balance,
                  onTap: () => setState(() => _selectedCoin = b.coin),
                ),
              ),

              const SizedBox(height: 20),

              // actions row 1
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      label: 'Receive',
                      icon: Icons.qr_code_2,
                      onTap: () => _showCenteredDialog(
                        context,
                        child: ReceiveSheet(controller: c),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      label: 'Send',
                      icon: Icons.send_rounded,
                      onTap: () => _showCenteredDialog(
                        context,
                        child: SendSheet(controller: c),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // actions row 2
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      label: 'Cash out',
                      icon: Icons.payments_rounded,
                      onTap: () => _showCenteredDialog(
                        context,
                        child: const _CashoutDialog(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      label: 'Convert',
                      icon: Icons.swap_horiz_rounded,
                      onTap: () => _showCenteredDialog(
                        context,
                        child: const _ConvertDialog(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Text(
                'Recent activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              if (c.txs.isEmpty)
                const Text(
                  'No transactions yet. Generate an address or send crypto to get started.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...c.txs.map(
                  (t) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Icon(
                      t.type == 'deposit' ? Icons.south_west : Icons.north_east,
                      color: t.type == 'deposit' ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      '${t.type.toUpperCase()} • ${t.coin} (${t.network})',
                    ),
                    subtitle: Text('${t.status} • ${t.createdAt.toLocal()}'),
                    trailing: Text(
                      (t.type == 'deposit' ? '+' : '-') +
                          t.amount.toStringAsFixed(2),
                      style: TextStyle(
                        color: t.type == 'deposit' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      }),
    );
  }

  // ===== Centered dialog helper =====
  void _showCenteredDialog(BuildContext context, {required Widget child}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String coin;
  final double amount;
  const _BalanceCard({required this.coin, required this.amount});

  String _fmt(String coin, double v) {
    // ✅ nicer precision per asset
    if (coin == 'BTC') return v.toStringAsFixed(8);
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: osvanGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wallet Balance',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '${_fmt(coin, amount)} $coin',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Icon(
            Icons.account_balance_wallet,
            color: Colors.white,
            size: 40,
          ),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final String coin;
  final String network;
  final double amount;
  final VoidCallback? onTap;
  const _BalanceTile({
    required this.coin,
    required this.network,
    required this.amount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        title: Text('$coin • $network'),
        subtitle: const Text('Available balance'),
        trailing: Text(
          amount.toStringAsFixed(4),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// Light mode: green icon+text; Dark mode: theme defaults
// Centered content
class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // ignore: deprecated_member_use
            BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.05)),
          ],
          color: Theme.of(context).cardColor,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: isLightMode ? osvanGreen : null),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isLightMode ? osvanGreen : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Centered content for Cashout / Convert =====
class _CashoutDialog extends StatelessWidget {
  const _CashoutDialog();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 8),
        Text(
          'Cash out (NGN • GHS • KES)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Coming soon — will call payout quote → initiate via backend.',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
      ],
    );
  }
}

class _ConvertDialog extends StatelessWidget {
  const _ConvertDialog();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 8),
        Text(
          'Convert to Main Wallet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Coming soon — will call convert quote → confirm via backend.',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
      ],
    );
  }
}
