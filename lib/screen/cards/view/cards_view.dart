// CardsView (split version) - PREMIUM UI upgrade (logic unchanged)
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/routes/app_routes.dart';
import 'package:osvan_app/screen/cards/services/card_service.dart';
import 'package:osvan_app/services/api_client.dart';
import 'package:osvan_app/services/biometric_service.dart';
import 'package:osvan_app/widgets/luxury_background.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widgets/card_tile.dart';
import 'widgets/section_card.dart';
import 'widgets/transactions_sheet.dart';

// ───────────────────── Local ViewModel ─────────────────────
class CardVM {
  final String id;
  final String label;
  final String brand; // visa/mastercard/unknown
  final String last4; // ****
  final String currency; // USD
  final String status; // ACTIVE | FROZEN | TERMINATED | etc.
  final int? balanceMinor; // cents (nullable)

  const CardVM({
    required this.id,
    required this.label,
    required this.brand,
    required this.last4,
    required this.currency,
    required this.status,
    this.balanceMinor,
  });

  bool get isFrozen => status.toUpperCase() == 'FROZEN';
  bool get isTerminated => status.toUpperCase() == 'TERMINATED';

  String balanceFormatted() {
    final v = (balanceMinor ?? 0) / 100.0;
    return v.toStringAsFixed(2);
  }

  factory CardVM.fromMap(Map<String, dynamic> m) {
    String s(dynamic v, [String d = '']) => (v == null ? d : v.toString());
    num nn(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      return num.tryParse(v.toString()) ?? 0;
    }

    final id = s(m['id'] ?? m['cardId']);
    final brand = s(m['brand'] ?? m['cardBrand'] ?? m['provider'] ?? 'unknown');
    final currency = s(m['currency'] ?? 'USD');
    final status =
        s(m['status'] ?? (m['frozen'] == true ? 'FROZEN' : 'ACTIVE'));
    final label = s(m['label'] ?? m['name'] ?? 'Card');

    String last4 = s(m['last4'] ?? m['lastFour']);
    if (last4.isEmpty) {
      final number = s(m['number']);
      last4 = (number.isNotEmpty && number.length >= 4)
          ? number.substring(number.length - 4)
          : '****';
    }

    int? cents;
    for (final k in [
      'balance_minor',
      'balanceMinor',
      'balance_cents',
      'available_cents'
    ]) {
      final v = nn(m[k]);
      if (v > 0) {
        cents = v.toInt();
        break;
      }
    }
    if (cents == null) {
      final major = nn(m['balance'] ?? m['available'] ?? m['availableBalance']);
      if (major != 0) cents = (major * 100).round();
    }

    return CardVM(
      id: id,
      label: label,
      brand: brand,
      last4: last4,
      currency: currency,
      status: status,
      balanceMinor: cents,
    );
  }
}

class RevealCardBottomSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final int expiresIn;

  const RevealCardBottomSheet({
    super.key,
    required this.data,
    this.expiresIn = 30,
  });

  @override
  State<RevealCardBottomSheet> createState() => _RevealCardBottomSheetState();
}

class _RevealCardBottomSheetState extends State<RevealCardBottomSheet> {
  late int left;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    left = widget.expiresIn.clamp(5, 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) {
        _timer?.cancel();
        if (Get.isBottomSheetOpen == true) Get.back();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    Get.snackbar('Copied', '$label copied',
        snackPosition: SnackPosition.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    final number = (d['number'] ?? '').toString();
    final cvv = (d['cvv'] ?? '').toString();
    final expiry = (d['expiry'] ?? '').toString();
    final name = (d['name'] ?? '').toString();
    final brand = (d['brand'] ?? '').toString().toUpperCase();
    final balance = (d['balanceDisplay'] ?? '').toString();
    final billing = d['billing'];
    String billingText = '';
    if (billing is Map) {
      final street = (billing['street'] ?? '').toString();
      final city = (billing['city'] ?? '').toString();
      final state = (billing['state'] ?? '').toString();
      final zip = (billing['zipCode'] ?? billing['zip'] ?? '').toString();
      final country =
          (billing['country'] ?? billing['countryCode'] ?? '').toString();
      billingText = [
        street,
        [city, state].where((s) => s.trim().isNotEmpty).join(', '),
        zip,
        country
      ].where((s) => s.trim().isNotEmpty).join(' · ');
    }

    return SafeArea(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            const Positioned.fill(child: LuxuryBackground()),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.70),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Card Details',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          'Auto-hide 00:${left.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (balance.isNotEmpty) ...[
                      _row('Balance', balance,
                          onCopy: () => _copy('Balance', balance)),
                      const SizedBox(height: 10),
                    ],
                    if (brand.isNotEmpty) ...[
                      _row('Brand', brand),
                      const SizedBox(height: 10),
                    ],
                    _row('Card Number', number.isEmpty ? '-' : number,
                        onCopy: number.isEmpty
                            ? null
                            : () => _copy('Card Number', number)),
                    const SizedBox(height: 10),
                    _row('Expiry', expiry.isEmpty ? '-' : expiry,
                        onCopy: expiry.isEmpty
                            ? null
                            : () => _copy('Expiry', expiry)),
                    const SizedBox(height: 10),
                    _row('CVV', cvv.isEmpty ? '-' : cvv,
                        onCopy: cvv.isEmpty ? null : () => _copy('CVV', cvv)),
                    if (name.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _row('Name', name, onCopy: () => _copy('Name', name)),
                    ],
                    if (billingText.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _row('Billing address', billingText,
                          onCopy: () => _copy('Billing address', billingText)),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Get.back(),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {VoidCallback? onCopy}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

// ───────────────────── Screen ─────────────────────
class CardsView extends StatefulWidget {
  const CardsView({super.key});
  @override
  State<CardsView> createState() => _CardsViewState();
}

class _CardsViewState extends State<CardsView> {
  final _loading = false.obs;
  final _cards = <CardVM>[].obs;

  // Busy flags to prevent double-taps
  final _freezeBusy = <String, bool>{}.obs;
  final _terminateBusy = <String, bool>{}.obs;

  // KYC gate
  final _kycRegistered = false.obs;

  // Amount/reference (dialogs)
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController(text: '');
  final String _currency = 'USD';

  // Shared luxury surface
  static const _surface = Color(0xFF0F172A);
  static const int _maxCards = 3;

  @override
  void initState() {
    super.initState();
    _loadKycAndCards();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  // ───────────────────── Data loaders ─────────────────────
  Future<void> _loadKycAndCards() async {
    _loading.value = true;
    try {
      _kycRegistered.value = await CardService.isCardUserRegistered();
      final items = await CardService.listCards();
      final vms = items.map<CardVM>((m) => CardVM.fromMap(m)).toList();
      final visible = vms.where((x) => !x.isTerminated).toList();
      _cards.assignAll(visible);
      await _syncKycFromCards();
    } catch (e) {
      _showError('Failed to load cards', e);
    } finally {
      _loading.value = false;
    }
  }

  Future<void> _loadCards() async {
    _loading.value = true;
    try {
      final items = await CardService.listCards();
      final vms = items.map<CardVM>((m) => CardVM.fromMap(m)).toList();
      final visible = vms.where((x) => !x.isTerminated).toList();
      _cards.assignAll(visible);
      await _syncKycFromCards();
    } catch (e) {
      _showError('Failed to load cards', e);
    } finally {
      _loading.value = false;
    }
  }

  Future<void> _refresh() async {
    _kycRegistered.value = await CardService.isCardUserRegistered();
    await _loadCards();
  }

  Future<void> _syncKycFromCards() async {
    if (_cards.isNotEmpty && !_kycRegistered.value) {
      _kycRegistered.value = true;
      await CardService.setCardUserRegistered(true);
    }
  }

  // ───────────────────── Helpers ─────────────────────
  int _toMinor(String s) {
    final n = double.tryParse(s.trim()) ?? 0;
    return (n * 100).round();
  }

  void _showError(String title, dynamic e) {
    final msg = _extractErrorMessage(e);
    Get.snackbar(title, msg,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 6));
  }

  String _extractErrorMessage(dynamic e) {
    try {
      if (e is Map) {
        final msg =
            (e['message'] ?? e['detail'] ?? e['error'] ?? '').toString();
        final code = (e['code'] ?? e['status'] ?? '').toString();
        final provider =
            (e['providerMessage'] ?? e['details'] ?? '').toString();
        final parts = <String>[];
        if (msg.isNotEmpty) parts.add(msg);
        if (code.isNotEmpty && code != 'null') parts.add('Code: $code');
        if (provider.isNotEmpty) parts.add('Details: $provider');
        return parts.join(' | ');
      }
      return e.toString();
    } catch (_) {
      return e.toString();
    }
  }

  InputDecoration _luxInput(String label, {String? hint, String? prefixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      filled: true,
      fillColor: const Color(0xFF0B1220).withOpacity(0.65),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: osvanGreen, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _luxDialogShell({
    required Widget child,
    required double radius,
    Color glow = osvanGreen,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: _surface.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      )
                    ],
                  ),
                  child: child,
                ),
              ),
              Positioned(
                right: -80,
                top: -80,
                child: IgnorePointer(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: glow.withOpacity(0.10),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 80,
                          spreadRadius: 20,
                          color: glow.withOpacity(0.22),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────── Amount dialog (luxury) ─────────────────────
  Future<Map<String, dynamic>?> _amountDialog({
    required String title,
    bool showCloseToggle = false,
  }) async {
    bool closeCard = false;
    _amountCtrl.text = '';
    _referenceCtrl.text = '';

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) {
        return Material(
          color: Colors.transparent,
          child: _luxDialogShell(
            radius: 22,
            glow: osvanGreen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: osvanGreen.withOpacity(0.14),
                          shape: BoxShape.circle,
                        ),
                        child:
                            const Icon(Icons.tune_rounded, color: osvanGreen),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: _luxInput(
                      'Amount ($_currency)',
                      hint: 'e.g. 25.00',
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _referenceCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _luxInput(
                      'Reference (optional)',
                      hint: 'auto if left empty',
                    ),
                  ),
                  if (showCloseToggle) ...[
                    const SizedBox(height: 10),
                    StatefulBuilder(
                      builder: (ctx, setS) => Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: CheckboxListTile(
                          value: closeCard,
                          onChanged: (v) => setS(() => closeCard = v == true),
                          title: const Text(
                            'Close card after withdrawal',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            'If enabled, amount can be empty and the card will be closed.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.70),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          activeColor: osvanGreen,
                          checkColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.18)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: osvanGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            final cents = _toMinor(_amountCtrl.text);
                            if (!showCloseToggle && cents <= 0) {
                              Get.snackbar(
                                  'Amount', 'Enter a valid amount (> 0)',
                                  snackPosition: SnackPosition.BOTTOM);
                              return;
                            }
                            Navigator.pop(context, {
                              'amountCents': cents,
                              'reference': _referenceCtrl.text.trim().isEmpty
                                  ? null
                                  : _referenceCtrl.text.trim(),
                              'closeCard': closeCard,
                            });
                          },
                          child: const Text(
                            'Continue',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────────────── Actions (service calls) ─────────────────────
  Future<void> _topUp(CardVM c) async {
    final res = await _amountDialog(title: 'Top up card');
    if (res == null) return;
    final cents = res['amountCents'] as int? ?? 0;
    final ref = res['reference'] as String?;
    if (cents <= 0) {
      Get.snackbar('Amount', 'Enter a valid amount (> 0)',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      await CardService.topUpByPath(
        cardId: c.id,
        amountCents: cents,
        currency: _currency,
        reference: ref,
      );
      Get.snackbar('Success', 'Card topped up',
          snackPosition: SnackPosition.BOTTOM);
      await _loadCards();
    } catch (e) {
      _showError('Top up failed', e);
    }
  }

  Future<void> _withdraw(CardVM c) async {
    final res =
        await _amountDialog(title: 'Withdraw from card', showCloseToggle: true);
    if (res == null) return;
    final cents = res['amountCents'] as int?;
    final closeCard = res['closeCard'] as bool? ?? false;
    if ((cents == null || cents <= 0) && !closeCard) {
      Get.snackbar('Amount', 'Enter a valid amount or choose Close card',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      await CardService.withdrawByPath(
        cardId: c.id,
        currency: _currency,
        amountCents: cents,
        closeCard: closeCard,
      );
      Get.snackbar('Success',
          closeCard ? 'Card closed via withdrawal' : 'Withdrawal complete',
          snackPosition: SnackPosition.BOTTOM);
      await _loadCards();
    } catch (e) {
      _showError('Withdrawal failed', e);
    }
  }

  Future<void> _revealCard(CardVM c) async {
    try {
      final ok = await BiometricService.authenticateBiometric();
      if (!ok) {
        final msg =
            BiometricService.lastErrorMessage ?? 'Verification cancelled.';
        Get.snackbar('Verify identity', msg,
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final api = await ApiClient.ensureInitialized();
      final t = await api.reverifyTicket();
      final ticket = (t['ticket'] ?? '').toString();
      final expiresIn = int.tryParse('${t['expiresIn'] ?? 30}') ?? 30;
      if (ticket.isEmpty) {
        Get.snackbar('Error', 'Unable to verify. Try again.',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final resp =
          await CardService.revealCard(cardId: c.id.toString(), ticket: ticket);
      final raw = (resp['data'] is Map)
          ? Map<String, dynamic>.from(resp['data'])
          : (Map<String, dynamic>.from(resp));

      final number = (raw['cardNumber'] ?? raw['number'] ?? '').toString();
      final cvv = (raw['cvv2'] ?? raw['cvv'] ?? '').toString();

      String expiry = '';
      final valid = (raw['valid'] ?? raw['expiry'] ?? '').toString();
      if (valid.contains('/')) {
        expiry = valid;
      } else if (valid.contains('-')) {
        final dt = DateTime.tryParse(valid);
        if (dt != null) {
          final mm = dt.month.toString().padLeft(2, '0');
          final yy = (dt.year % 100).toString().padLeft(2, '0');
          expiry = '$mm/$yy';
        }
      }

      final name = (raw['cardName'] ?? raw['customerName'] ?? '').toString();
      final brand = (raw['cardBrand'] ?? c.brand).toString();
      final currency = (raw['currency'] ?? c.currency).toString().toUpperCase();
      final billing = raw['billingAddress'];

      String balanceDisplay = '';
      final bal = raw['balance'];
      if (bal is num) {
        final major = bal / 100.0;
        balanceDisplay =
            '${currency.isNotEmpty ? '$currency ' : ''}${major.toStringAsFixed(2)}';
      } else if (bal != null) {
        balanceDisplay = bal.toString();
      }

      final data = <String, dynamic>{
        ...raw,
        'number': number,
        'cvv': cvv,
        'expiry': expiry,
        'name': name,
        'brand': brand,
        'balanceDisplay': balanceDisplay,
        'billing': billing,
      };

      Get.bottomSheet(
        RevealCardBottomSheet(
          data: data,
          expiresIn: expiresIn,
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    } catch (e) {
      _showError('Reveal failed', e);
    }
  }

  Future<void> _toggleFreeze(CardVM c) async {
    final id = c.id;
    if (id.isEmpty) return;
    if (_freezeBusy[id] == true) return;

    _freezeBusy[id] = true;
    _freezeBusy.refresh();
    try {
      if (c.isFrozen) {
        await CardService.unfreezeCard(id);
        Get.snackbar('Unfrozen', 'Card is now ACTIVE',
            snackPosition: SnackPosition.BOTTOM);
      } else {
        await CardService.freezeCard(id);
        Get.snackbar('Frozen', 'Card is now FROZEN',
            snackPosition: SnackPosition.BOTTOM);
      }
      await _loadCards();
    } catch (e) {
      _showError('Failed to update freeze state', e);
    } finally {
      _freezeBusy[id] = false;
      _freezeBusy.refresh();
    }
  }

  Future<void> _confirmTerminate(CardVM c) async {
    final id = c.id;
    if (id.isEmpty) return;
    if (_terminateBusy[id] == true) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) {
        return _luxDialogShell(
          radius: 22,
          glow: Colors.redAccent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_rounded,
                          color: Colors.redAccent),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Terminate card?',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'This will permanently terminate the card '
                  '(${c.brand.toUpperCase()} •••• ${c.last4}). You cannot undo this action.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side:
                              BorderSide(color: Colors.white.withOpacity(0.18)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Terminate',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok != true) return;

    _terminateBusy[id] = true;
    _terminateBusy.refresh();
    try {
      await CardService.terminateCard(id);
      Get.snackbar('Terminated', 'Card has been permanently terminated',
          snackPosition: SnackPosition.BOTTOM);
      await _loadCards();
    } catch (e) {
      _showError('Failed to terminate card', e);
    } finally {
      _terminateBusy[id] = false;
      _terminateBusy.refresh();
    }
  }

  Future<void> _openStatement(CardVM c) async {
    try {
      final url = CardService.getStatementUrl(c.id);
      final uri = Uri.parse(url);
      if (!await canLaunchUrl(uri)) {
        Get.snackbar('Error', 'Cannot open statement',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showError('Failed to open statement', e);
    }
  }

  void _openTransactions(CardVM c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.65),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Stack(
            children: [
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: _surface.withOpacity(0.84),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(22)),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: Column(
                    children: [
                      // sheet handle + header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.receipt_long_rounded,
                                    color: Colors.white),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Transactions',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Close',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close_rounded,
                                      color: Colors.white70),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Divider(color: Colors.white.withOpacity(0.08)),
                          ],
                        ),
                      ),
                      Expanded(child: TransactionsSheet(cardId: c.id)),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: -80,
                top: -80,
                child: IgnorePointer(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFF60A5FA).withOpacity(0.08),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 90,
                          spreadRadius: 26,
                          color: const Color(0xFF60A5FA).withOpacity(0.18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _goRegisterKyc() async {
    if (_kycRegistered.value) {
      Get.snackbar('KYC', 'Card KYC is already approved',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final res = await Get.toNamed(AppRoutes.cardsRegisterUser);
    final ok = (res == true);
    if (ok) {
      _kycRegistered.value = true;
      await CardService.setCardUserRegistered(true);
      await _loadCards();
      Get.snackbar('KYC', 'Card user registration completed',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showCardLimit() {
    Get.snackbar(
      'Card limit reached',
      'You can create up to $_maxCards cards.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _goCreateCard() async {
    if (!_kycRegistered.value) {
      await _goRegisterKyc();
      return;
    }
    if (_cards.length >= _maxCards) {
      _showCardLimit();
      return;
    }
    await Get.toNamed(AppRoutes.createCard);
  }

  // ───────────────────── PREMIUM UI BLOCKS ─────────────────────
  Widget _header(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return Obx(() {
      final total = _cards.length;
      final frozen = _cards.where((x) => x.isFrozen).length;
      final active = total - frozen;

      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? _surface : Colors.white)
                      .withOpacity(isDark ? 0.70 : 0.95),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.10),
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: osvanGreen.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.credit_card_rounded,
                              color: osvanGreen.withOpacity(0.95)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Cards Vault",
                                style: th.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Manage virtual cards, statements, and actions",
                                style: th.textTheme.bodySmall?.copyWith(
                                  color: th.textTheme.bodySmall?.color
                                      ?.withOpacity(0.70),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: "Refresh",
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                        )
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      children: [
                        _statChip(
                          context,
                          label: "Active",
                          value: "$active",
                          icon: Icons.check_circle_rounded,
                          tint: osvanGreen,
                          compact: true,
                        ),
                        _statChip(
                          context,
                          label: "Frozen",
                          value: "$frozen",
                          icon: Icons.ac_unit_rounded,
                          tint: Colors.amber,
                          compact: true,
                        ),
                        _statChip(
                          context,
                          label: "Total",
                          value: "$total",
                          icon: Icons.layers_rounded,
                          tint: const Color(0xFF60A5FA),
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        osvanGreen.withOpacity(0.10),
                        Colors.transparent,
                        const Color(0xFF60A5FA).withOpacity(0.06),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _statChip(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color tint,
    bool compact = false,
  }) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tint),
          SizedBox(width: compact ? 6 : 8),
          Text(
            label,
            style: th.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: th.textTheme.bodySmall?.color?.withOpacity(0.75),
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            value,
            style: th.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kycBannerPremium() {
    return Obx(() {
      final approved = _kycRegistered.value;

      final icon = approved ? Icons.verified_rounded : Icons.shield_rounded;
      final tint = approved ? osvanGreen : Colors.amber;

      final title = approved ? "Card KYC approved" : "Complete Card KYC";
      final desc = approved
          ? "You can request and manage cards without limitations."
          : "To request a virtual card, your identity verification is required.";

      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surface.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tint.withOpacity(0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: tint),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.75),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: approved ? Colors.white12 : osvanGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: approved ? null : _goRegisterKyc,
                      child: Text(
                        approved ? "Approved" : "Register",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -60,
              top: -60,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: tint.withOpacity(0.12),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 70,
                        spreadRadius: 14,
                        color: tint.withOpacity(0.22),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _emptyState(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return Column(
      children: [
        _header(context),
        const SizedBox(height: 14),
        _kycBannerPremium(),
        const SizedBox(height: 14),
        Card(
          elevation: 10,
          shadowColor: Colors.black.withOpacity(0.08),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: osvanGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_card_rounded,
                      color: osvanGreen.withOpacity(0.95), size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  "No cards yet",
                  style: th.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _kycRegistered.value
                      ? "Create a new virtual card to start spending securely."
                      : "Complete Card KYC to unlock card requests.",
                  textAlign: TextAlign.center,
                  style: th.textTheme.bodyMedium?.copyWith(
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.70),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text("Reload"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _goCreateCard,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text("Request Card"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: osvanGreen,
                          foregroundColor: Colors.black,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  // ───────────────────── UI ─────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final scrollBottomPadding = kBottomNavigationBarHeight + 24 + bottomSafe;

    final dark = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF070B14),
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
            const LuxuryBackground(),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                toolbarHeight: 52,
                title: Text(
                  'Cards',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                ),
                centerTitle: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                systemOverlayStyle: SystemUiOverlayStyle.light,
              ),
              body: RefreshIndicator(
                onRefresh: _refresh,
                child: Obx(() {
                  if (_loading.value) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding:
                          EdgeInsets.fromLTRB(16, 16, 16, scrollBottomPadding),
                      children: const [
                        SizedBox(height: 140),
                        Center(child: CircularProgressIndicator()),
                        SizedBox(height: 600),
                      ],
                    );
                  }

                  if (_cards.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding:
                          EdgeInsets.fromLTRB(16, 16, 16, scrollBottomPadding),
                      children: [
                        _emptyState(context),
                      ],
                    );
                  }

                  return ListView(
                    padding:
                        EdgeInsets.fromLTRB(16, 16, 16, scrollBottomPadding),
                    children: [
                      _header(context),
                      const SizedBox(height: 14),
                      _kycBannerPremium(),
                      const SizedBox(height: 14),

                      SectionCard(
                        title: 'Your cards',
                        subtitle:
                            'Tap a card to open transactions, statement, or actions',
                        child: Column(
                          children: List.generate(
                            _cards.length,
                            (i) => Padding(
                              padding: EdgeInsets.only(
                                  bottom: i == _cards.length - 1 ? 0 : 12),
                              child: CardTile(
                                card: _cards[i],
                                freezeBusy: _freezeBusy[_cards[i].id] == true,
                                termBusy: _terminateBusy[_cards[i].id] == true,
                                onOpenActions: (c) => CardTile.openActions(
                                  context,
                                  card: c,
                                  freezeBusy: _freezeBusy[c.id] == true,
                                  termBusy: _terminateBusy[c.id] == true,
                                  onViewTx: () => _openTransactions(c),
                                  onReveal: () => _revealCard(c),
                                  onStatement: () => _openStatement(c),
                                  onTopUp: () => _topUp(c),
                                  onWithdraw: () => _withdraw(c),
                                  onToggleFreeze: () => _toggleFreeze(c),
                                  onTerminate: () => _confirmTerminate(c),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_cards.length < _maxCards) ...[
                        const SizedBox(height: 14),
                        SectionCard(
                          title: 'Create another card',
                          subtitle:
                              'You can have up to $_maxCards virtual cards.',
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _goCreateCard,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Request Card'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: osvanGreen,
                                foregroundColor: Colors.black,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 80),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
