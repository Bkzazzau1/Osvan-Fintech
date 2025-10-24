// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/routes/app_routes.dart'; // ✅ for navigation
import 'package:osvan_app/screen/wallet/services/config_service.dart';

import '../models/card_model.dart';
import '../services/card_service.dart';

class CardsView extends StatefulWidget {
  const CardsView({super.key});

  @override
  State<CardsView> createState() => _CardsViewState();
}

class _CardsViewState extends State<CardsView> {
  late Future<List<CardModel>> _cardsFuture;
  late final ConfigService _cfg;

  @override
  void initState() {
    super.initState();
    _cfg = Get.find<ConfigService>();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _cardsFuture = CardService.getCards();
    });
  }

  Color _getCardColor(String provider, bool frozen) {
    if (frozen) return Colors.grey.shade600;
    switch (provider.toLowerCase()) {
      case 'visa':
        return Colors.blue.shade700;
      case 'mastercard':
        return Colors.orange.shade700;
      default:
        return osvanGreen;
    }
  }

  String _getCardLogo(String provider) {
    switch (provider.toLowerCase()) {
      case 'visa':
        return 'assets/visa.png';
      case 'mastercard':
        return 'assets/mastercard.png';
      default:
        return '';
    }
  }

  String _maskNumber(String number) {
    final onlyDigits = number.replaceAll(RegExp(r'\s'), '');
    if (onlyDigits.length >= 16) {
      final last4 = onlyDigits.substring(onlyDigits.length - 4);
      return '**** **** **** $last4';
    }
    return number;
  }

  String _fmtBalance(String raw) {
    if (raw.isEmpty) return '--';
    return raw;
  }

  Future<void> _onFreezeOrUnfreeze(CardModel card) async {
    try {
      await CardService.toggleFreeze(card.id, !card.frozen);
      _refresh();
      Get.snackbar(
        'Success',
        card.frozen ? 'Card unfrozen' : 'Card frozen',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'Error',
        'Failed to update card status',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _onViewPin(CardModel card) async {
    try {
      final pin = await CardService.getCardPin(card.id);
      Get.snackbar(
        'PIN',
        'Your card PIN is $pin',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 6),
      );
    } catch (_) {
      Get.snackbar(
        'Error',
        'Failed to fetch PIN',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _onDelete(CardModel card) async {
    try {
      await CardService.deleteCard(card.id);
      _refresh();
      Get.snackbar(
        'Deleted',
        'Card deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'Error',
        'Failed to delete card',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // =========================
  // New per-card money dialogs (respect Control API)
  // =========================

  Future<void> _showFundCardDialog(CardModel card) async {
    if (!_cfg.cardsFundEnabled) {
      Get.snackbar('Unavailable', 'Card funding is temporarily disabled',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final amountController = TextEditingController();
    final currencyController =
        TextEditingController(text: _cfg.defaultCardCurrency);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fund Card from Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: currencyController,
              decoration: const InputDecoration(
                  labelText: 'Wallet Currency (e.g. USD)'),
            ),
            if (_cfg.usdCardOnly)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Note: Cards are USD-only.',
                    style: TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ccy = currencyController.text.trim().toUpperCase();
              if (_cfg.usdCardOnly && ccy != 'USD') {
                Get.snackbar(
                  'Invalid currency',
                  'Only USD is supported for card operations at the moment.',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              Navigator.pop(context);
              try {
                await CardService.fundWalletViaCard(
                  cardId: card.id,
                  currency: ccy,
                  amount: amountController.text.trim(),
                );
                Get.snackbar('Success', 'Card funded',
                    snackPosition: SnackPosition.BOTTOM);
                _refresh();
              } catch (_) {
                Get.snackbar('Error', 'Failed to fund card',
                    snackPosition: SnackPosition.BOTTOM);
              }
            },
            child: const Text('Fund Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWithdrawDialog(CardModel card) async {
    if (!_cfg.cardsWithdrawEnabled) {
      Get.snackbar('Unavailable', 'Card withdrawal is temporarily disabled',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final amountController = TextEditingController();
    final currencyController =
        TextEditingController(text: _cfg.defaultCardCurrency);
    bool closeCard = false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setS) {
        return AlertDialog(
          title: const Text('Withdraw from Card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: currencyController,
                decoration:
                    const InputDecoration(labelText: 'Currency (e.g. USD)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: closeCard,
                    onChanged: (v) => setS(() => closeCard = v ?? false),
                  ),
                  const Expanded(child: Text('Close card after withdrawal')),
                ],
              ),
              if (_cfg.usdCardOnly)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Note: Cards are USD-only.',
                    style: TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final ccy = currencyController.text.trim().toUpperCase();
                if (_cfg.usdCardOnly && ccy != 'USD') {
                  Get.snackbar(
                    'Invalid currency',
                    'Only USD is supported for card operations at the moment.',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }

                Navigator.pop(context);
                try {
                  await CardService.withdrawFromCard(
                    cardId: card.id,
                    currency: ccy,
                    amount: amountController.text.trim(),
                    closeCard: closeCard,
                  );
                  Get.snackbar('Success', 'Withdrawal successful',
                      snackPosition: SnackPosition.BOTTOM);
                  _refresh();
                } catch (_) {
                  Get.snackbar('Error', 'Failed to withdraw',
                      snackPosition: SnackPosition.BOTTOM);
                }
              },
              child: const Text('Withdraw'),
            ),
          ],
        );
      }),
    );
  }

  void _showCardActions(CardModel card) {
    // Snapshot flags (use Obx if you want dynamic live updates inside the sheet)
    final fundEnabled = _cfg.cardsFundEnabled;
    final withdrawEnabled = _cfg.cardsWithdrawEnabled;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              children: [
                ListTile(
                  leading: Icon(card.frozen ? Icons.lock_open : Icons.lock),
                  title: Text(card.frozen ? 'Unfreeze Card' : 'Freeze Card'),
                  onTap: () {
                    Navigator.pop(context);
                    _onFreezeOrUnfreeze(card);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('View PIN'),
                  onTap: () {
                    Navigator.pop(context);
                    _onViewPin(card);
                  },
                ),
                // 🔽 Money actions (per-card) — respect flags
                Opacity(
                  opacity: fundEnabled ? 1.0 : 0.4,
                  child: ListTile(
                    leading: const Icon(Icons.arrow_upward),
                    title: const Text('Fund Card from Wallet'),
                    onTap: fundEnabled
                        ? () {
                            Navigator.pop(context);
                            _showFundCardDialog(card);
                          }
                        : null,
                  ),
                ),
                Opacity(
                  opacity: withdrawEnabled ? 1.0 : 0.4,
                  child: ListTile(
                    leading: const Icon(Icons.arrow_downward),
                    title: const Text('Withdraw to Wallet'),
                    onTap: withdrawEnabled
                        ? () {
                            Navigator.pop(context);
                            _showWithdrawDialog(card);
                          }
                        : null,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Delete Card'),
                  onTap: () {
                    Navigator.pop(context);
                    _onDelete(card);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // FAB now keeps only actions that are not card-specific
  void _showFABMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.add_card),
                title: const Text('Request New Card'),
                onTap: () async {
                  Navigator.pop(context);
                  final created = await Get.toNamed(AppRoutes.createCard);
                  if (created == true) _refresh();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.credit_card_off, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No cards yet',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showFABMenu,
              icon: const Icon(Icons.add_card),
              label: const Text('Request a Card'),
            )
          ],
        ),
      ),
    );
  }

  Widget _errorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('Error: $error', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTile(CardModel card) {
    final color = _getCardColor(card.provider, card.frozen);
    final logo = _getCardLogo(card.provider);
    final masked = _maskNumber(card.number);
    final balance = _fmtBalance(card.balance);

    return GestureDetector(
      onTap: () => _showCardActions(card),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.type,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              balance,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  masked,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  card.expiry,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.bottomRight,
              child: logo.isNotEmpty
                  ? Image.asset(logo, height: 32)
                  : Text(
                      card.provider,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
            if (card.frozen)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Frozen',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topNotice() {
    final notices = <String>[];
    if (_cfg.usdCardOnly) notices.add('USD-only');
    if (!_cfg.cardsFundEnabled) notices.add('Funding disabled');
    if (!_cfg.cardsWithdrawEnabled) notices.add('Withdrawal disabled');
    if (notices.isEmpty) return const SizedBox.shrink();

    final text = notices.join(' • ');
    return Container(
      width: double.infinity,
      color: Colors.amber.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in Obx so notices react to config changes on the fly
    return Obx(() {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Cards'),
          backgroundColor: osvanGreen,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0),
            child: _topNotice(),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            _refresh();
          },
          child: FutureBuilder<List<CardModel>>(
            future: _cardsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _errorState(snapshot.error);
              }
              final cards = snapshot.data ?? [];
              if (cards.isEmpty) return _emptyState();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cards.length,
                itemBuilder: (context, i) => _buildCardTile(cards[i]),
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: osvanGreen,
          icon: const Icon(Icons.more_vert),
          label: const Text('Actions'),
          onPressed: _showFABMenu,
        ),
      );
    });
  }
}
