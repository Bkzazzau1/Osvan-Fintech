// lib/screen/transfer/view/send_money_confirm_view.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/screen/transfer/controllers/payout_wizard_controller.dart';
import 'package:osvan_app/screen/transfer/view/transfer_receipt_view.dart';
import 'package:osvan_app/services/api/payouts_api.dart';

const kDarkBg = Color(0xFF070B14);
const kDarkSurface = Color(0xFF0F172A);
const kDarkSurface2 = Color(0xFF0B1220);
const kIceBlue = Color(0xFF60A5FA);

class SendMoneyConfirmView extends StatefulWidget {
  const SendMoneyConfirmView({super.key});
  @override
  State<SendMoneyConfirmView> createState() => _SendMoneyConfirmViewState();
}

class _SendMoneyConfirmViewState extends State<SendMoneyConfirmView> {
  final ctrl = Get.find<PayoutWizardController>();
  final _noteCtrl = TextEditingController();

  // ✅ Provider minimum (Brails): NG payout minimum is ₦500
  static const double _ngPayoutMinMajor = 500.0;

  @override
  void initState() {
    super.initState();

    // ✅ IMPORTANT: defer GetX state mutations until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bool changed = false;

      final rn = (ctrl.resolvedName.value ?? '').toString().trim();
      if (rn.isNotEmpty &&
          (ctrl.form['accountName'] ?? '').toString().trim().isEmpty) {
        ctrl.form['accountName'] = rn;
        changed = true;
      }

      final cur = ctrl.currency.value.toString().trim().toUpperCase();
      final existing = (ctrl.form['sourceWalletCurrency'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      if (existing.isEmpty && cur.isNotEmpty) {
        ctrl.form['sourceWalletCurrency'] = cur;
        changed = true;
      }

      if (changed) ctrl.form.refresh();
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<String?> _askForPin(BuildContext context) async {
    final pinCtrl = TextEditingController();
    String? result;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? error;

        return StatefulBuilder(
          builder: (ctx2, setState) {
            return AlertDialog(
              backgroundColor: kDarkSurface,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
              contentTextStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.75)),
              title: const Text('Enter Transaction PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: '4-digit PIN',
                      counterText: '',
                      labelStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: kIceBlue.withValues(alpha: 0.55)),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(ctx2).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    result = null;
                    Navigator.of(ctx2).pop();
                  },
                  child: Text(
                    'Cancel',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kIceBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final v = pinCtrl.text.trim();
                    if (v.length != 4) {
                      setState(() => error = 'PIN must be 4 digits');
                      return;
                    }
                    result = v;
                    Navigator.of(ctx2).pop();
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      pinCtrl.dispose();
    });

    return result;
  }

  String _safeBeneficiaryName() {
    final a = (ctrl.resolvedName.value ?? '').toString().trim();
    if (a.isNotEmpty) return a;

    final b = (ctrl.form['accountName'] ?? '').toString().trim();
    if (b.isNotEmpty) return b;

    final c = (ctrl.form['beneficiaryName'] ?? '').toString().trim();
    if (c.isNotEmpty) return c;

    return '';
  }

  String _safeProviderOrBank() {
    final method = ctrl.destination.value.toUpperCase().trim();
    if (method == 'MOBILEMONEY' ||
        method == 'MOBILE_MONEY' ||
        method == 'MOBILE_NUMBER') {
      return (ctrl.form['network'] ?? '').toString();
    }

    final bankCode = (ctrl.form['bankCode'] ?? '').toString().trim();
    if (bankCode.isNotEmpty) return bankCode;

    return '';
  }

  String _safeBankName() => (ctrl.form['bankName'] ?? '').toString().trim();

  bool _passesMinimumRules() {
    final cc = ctrl.countryCode.value.toUpperCase().trim();
    final amount = ctrl.amountMajor.value;

    if (cc == 'NG' && amount < _ngPayoutMinMajor) {
      Get.snackbar(
        'Amount too low',
        'Minimum transfer is ₦${_ngPayoutMinMajor.toStringAsFixed(0)}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = Colors.white.withValues(alpha: 0.75);
    final valueColor = Colors.white;

    final recipient = _safeBeneficiaryName();
    final bankName = _safeBankName();
    final bankCode = _safeProviderOrBank();

    return Scaffold(
      backgroundColor: kDarkBg,
      body: Stack(
        children: [
          const _LuxuryBackground(),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                centerTitle: true,
                title: const Text(
                  'Confirm Transfer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed(
                    [
                      _GlassSection(
                        title: 'Review',
                        subtitle: 'Double-check before sending',
                        child: Column(
                          children: [
                            _kv('Country', ctrl.countryCode.value, labelColor,
                                valueColor),
                            _kv('Method', ctrl.destination.value, labelColor,
                                valueColor),
                            _kv('Currency', ctrl.currency.value, labelColor,
                                valueColor),
                            _kv(
                                'Amount',
                                ctrl.amountMajor.value.toStringAsFixed(2),
                                labelColor,
                                valueColor),
                            if (recipient.isNotEmpty)
                              _kv('Recipient Name', recipient, labelColor,
                                  valueColor),
                            if (bankName.isNotEmpty)
                              _kv('Bank', bankName, labelColor, valueColor),
                            if (bankCode.isNotEmpty)
                              _kv('Bank Code', bankCode, labelColor,
                                  valueColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GlassSection(
                        title: 'Note (optional)',
                        child: _DarkTextField(
                          controller: _noteCtrl,
                          label: 'Add a description',
                          icon: Icons.edit_note_rounded,
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GlassSection(
                        title: 'Authorize & Send',
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: Obx(() {
                                final busy = ctrl.isLoading.value;

                                return ElevatedButton(
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          Map<String, dynamic> finalizeRes =
                                              <String, dynamic>{};

                                          try {
                                            await PayoutsApi
                                                .ensureInitialized();

                                            if (!_passesMinimumRules()) return;

                                            final note = _noteCtrl.text.trim();
                                            if (note.isNotEmpty) {
                                              ctrl.form['description'] = note;
                                            }

                                            final cur = ctrl.currency.value
                                                .toString()
                                                .trim()
                                                .toUpperCase();
                                            final src = (ctrl.form[
                                                        'sourceWalletCurrency'] ??
                                                    '')
                                                .toString()
                                                .trim()
                                                .toUpperCase();
                                            if (src.isEmpty && cur.isNotEmpty) {
                                              ctrl.form[
                                                  'sourceWalletCurrency'] = cur;
                                            }

                                            final rn =
                                                (ctrl.resolvedName.value ?? '')
                                                    .toString()
                                                    .trim();
                                            if (rn.isNotEmpty) {
                                              ctrl.form['accountName'] = rn;
                                            }

                                            ctrl.form.refresh();

                                            await ctrl.initPayout();

                                            final txId =
                                                (ctrl.transactionId.value ?? '')
                                                    .trim();
                                            if (txId.isEmpty) {
                                              throw 'Missing transaction id from init payout';
                                            }

                                            final pin =
                                                await _askForPin(context);
                                            if (pin == null) return;

                                            finalizeRes =
                                                await PayoutsApi.I.finalize(
                                              transactionId: txId,
                                              pin: pin,
                                            );

                                            final initRes =
                                                ctrl.initResponse.value ?? {};
                                            final initData =
                                                (initRes['data'] is Map)
                                                    ? Map<String, dynamic>.from(
                                                        initRes['data'])
                                                    : <String, dynamic>{};

                                            final finData =
                                                (finalizeRes['data'] is Map)
                                                    ? Map<String, dynamic>.from(
                                                        finalizeRes['data'])
                                                    : <String, dynamic>{};

                                            final status = (finData['status'] ??
                                                    finalizeRes['status'] ??
                                                    initData['status'] ??
                                                    'PENDING')
                                                .toString();

                                            final receipt = {
                                              'country': ctrl.countryCode.value,
                                              'method': ctrl.destination.value,
                                              'currency': ctrl.currency.value,
                                              'amount': ctrl.amountMajor.value
                                                  .toStringAsFixed(2),
                                              'beneficiary':
                                                  _safeBeneficiaryName(),
                                              'providerOrBank':
                                                  _safeProviderOrBank(),
                                              'status': status,
                                              'reference':
                                                  initData['reference'] ??
                                                      initRes['reference'] ??
                                                      '',
                                              'transactionId': txId,
                                              'raw': {
                                                'init': initRes,
                                                'finalize': finalizeRes,
                                              },
                                            };

                                            Get.off(() => TransferReceiptView(
                                                  transferData: receipt,
                                                ));
                                          } catch (e) {
                                            Get.snackbar(
                                              'Transfer failed',
                                              e.toString(),
                                              snackPosition:
                                                  SnackPosition.BOTTOM,
                                              backgroundColor: Colors.red,
                                              colorText: Colors.white,
                                            );
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kIceBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Send Now',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w900),
                                        ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, Color labelColor, Color valueColor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                k,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                v,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
}

class _GlassSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _GlassSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: kDarkSurface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;

  const _DarkTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        prefixIcon: Icon(icon, color: kIceBlue),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kIceBlue.withValues(alpha: 0.55)),
        ),
      ),
    );
  }
}

class _LuxuryBackground extends StatelessWidget {
  const _LuxuryBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kDarkBg, kDarkSurface2, kDarkBg],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -80,
            child: _GlowBlob(color: kIceBlue, size: 260, opacity: 0.10),
          ),
          Positioned(
            top: 190,
            right: -120,
            child:
                _GlowBlob(color: Color(0xFF10B981), size: 260, opacity: 0.06),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child:
                _GlowBlob(color: Colors.purpleAccent, size: 320, opacity: 0.06),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowBlob({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: size,
            height: size,
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}
