// lib/screen/transfer/view/send_money_details_view.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/screen/transfer/controllers/payout_wizard_controller.dart';
import 'package:osvan_app/screen/transfer/view/send_money_confirm_view.dart';

const kDarkBg = Color(0xFF070B14);
const kDarkSurface = Color(0xFF0F172A);
const kDarkSurface2 = Color(0xFF0B1220);
const kIceBlue = Color(0xFF60A5FA);

class SendMoneyDetailsView extends StatefulWidget {
  const SendMoneyDetailsView({super.key});
  @override
  State<SendMoneyDetailsView> createState() => _SendMoneyDetailsViewState();
}

class _SendMoneyDetailsViewState extends State<SendMoneyDetailsView> {
  PayoutWizardController get ctrl => Get.find<PayoutWizardController>();

  final _formKey = GlobalKey<FormState>();
  final _bankSearchCtrl = TextEditingController();
  final RxString _bankQuery = ''.obs;

  bool get _needsLookupFlow {
    final cc = ctrl.countryCode.value.toUpperCase();
    final dest = ctrl.destination.value.toUpperCase();
    return (cc == 'NG' && dest == 'BANK') ||
        (cc == 'GH' && dest == 'MOBILE_NUMBER');
  }

  String _label(String name) {
    final s = name.replaceAll('.', ' ').replaceAll('_', ' ');
    return s.isEmpty ? 'Field' : s[0].toUpperCase() + s.substring(1);
  }

  String? _safeSelectedValue({
    required String fieldName,
    required List<DropdownMenuItem<String>> items,
  }) {
    final raw = ctrl.form[fieldName]?.toString();
    if (raw == null || raw.trim().isEmpty) return null;

    final ok = items.any((it) => it.value == raw);
    if (ok) return raw;

    ctrl.form.remove(fieldName);
    return null;
  }

  String _bankPickValue(String code, String name) =>
      '${code.trim()}|${name.trim()}';

  String? _selectedBankPick(List<DropdownMenuItem<String>> items) {
    final code = (ctrl.form['bankCode'] ?? '').toString().trim();
    final name = (ctrl.form['bankName'] ?? '').toString().trim();

    if (code.isEmpty) return null;

    if (name.isNotEmpty) {
      final exact = _bankPickValue(code, name);
      if (items.any((it) => it.value == exact)) return exact;
    }

    final prefix = '$code|';
    for (final it in items) {
      final v = it.value ?? '';
      if (v.startsWith(prefix)) return v;
    }

    ctrl.form.remove('bankCode');
    ctrl.form.remove('bankName');
    return null;
  }

  Widget _verifiedNameCard(String name) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            kIceBlue.withValues(alpha: 0.35),
            kIceBlue.withValues(alpha: 0.16),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: kIceBlue.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withValues(alpha: 0.35),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDynamicField(Map<String, dynamic> f) {
    final name = (f['name'] ?? f['key'] ?? '').toString();
    if (name.isEmpty) return const SizedBox.shrink();

    final nameLower = name.toLowerCase().trim();
    final type = (f['type'] ?? 'string').toString().toLowerCase();
    final required = f['required'] == true;

    if (f.containsKey('const')) return const SizedBox.shrink();

    if (nameLower == 'type') {
      final current = (ctrl.form[name] ?? '').toString().trim();
      if (current.isEmpty) {
        final opts = (f['enum'] ?? f['options']);
        if (opts is List && opts.isNotEmpty) {
          ctrl.form[name] = opts.first.toString().toUpperCase();
        } else {
          ctrl.form[name] = ctrl.destination.value.toUpperCase();
        }
      }
      return const SizedBox.shrink();
    }

    if (nameLower == 'accountname') {
      return const SizedBox.shrink();
    }

    if (f['enum'] is List || f['options'] is List) {
      final opts = (f['enum'] ?? f['options']) as List;
      final items = opts
          .map((o) => DropdownMenuItem<String>(
                value: o.toString(),
                child: Text(o.toString(), overflow: TextOverflow.ellipsis),
              ))
          .toList();

      return Obx(() {
        final selected = _safeSelectedValue(fieldName: name, items: items);

        return DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: selected,
          dropdownColor: kDarkSurface,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          decoration: _darkInputDecoration(
            label: _label(name),
            icon: Icons.tune_rounded,
          ),
          items: items,
          onChanged: (v) => ctrl.form[name] = v,
          validator: required
              ? (v) => (v == null || v.isEmpty) ? 'Required' : null
              : null,
        );
      });
    }

    if (nameLower == 'bankcode') {
      return Obx(() {
        if (ctrl.isLoading.value && ctrl.banks.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bank',
                  style:
                      TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              const SizedBox(height: 6),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          );
        }

        if (ctrl.banks.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bank',
                  style:
                      TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => ctrl.loadBanksIfNeeded(),
                icon: const Icon(Icons.refresh),
                label: const Text('Load banks'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: kIceBlue.withValues(alpha: 0.45)),
                  backgroundColor: kIceBlue.withValues(alpha: 0.10),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No banks available for ${ctrl.countryCode.value}/${ctrl.currency.value}.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
              ),
            ],
          );
        }

        final query = _bankSearchCtrl.text.toLowerCase();
        final localQuery = _bankQuery.value.toLowerCase();
        final activeQuery = localQuery.isNotEmpty ? localQuery : query;

        final banksFiltered = activeQuery.isEmpty
            ? ctrl.banks
            : ctrl.banks.where((b) {
                final n = (b['name'] ?? '').toString().toLowerCase();
                final c = (b['code'] ?? '').toString().toLowerCase();
                return n.contains(activeQuery) || c.contains(activeQuery);
              }).toList();

        final items = banksFiltered.map((b) {
          final code = (b['code'] ?? '').toString().trim();
          final bankName = (b['name'] ?? '').toString().trim();
          final pick = _bankPickValue(code, bankName);

          return DropdownMenuItem<String>(
            value: pick,
            child: Text(
              bankName.isEmpty ? code : bankName,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }).toList();

        final selected = _selectedBankPick(items);

        final key = ValueKey(
          'bank-dropdown-${ctrl.countryCode.value}-${ctrl.currency.value}-${ctrl.banks.length}',
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _bankSearchCtrl,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
              decoration: _darkInputDecoration(
                label: 'Search bank',
                icon: Icons.search,
              ),
              onChanged: (v) => _bankQuery.value = v,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: key,
              isExpanded: true,
              initialValue: selected,
              dropdownColor: kDarkSurface,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
              decoration: _darkInputDecoration(
                  label: 'Bank', icon: Icons.account_balance_rounded),
              items: items,
              onChanged: (pick) {
                if (pick == null || pick.trim().isEmpty) {
                  ctrl.form.remove('bankCode');
                  ctrl.form.remove('bankName');

                  if (_needsLookupFlow) {
                    ctrl.form.remove('accountName');
                    ctrl.resolvedName.value = null;
                    ctrl.lookupAvailable.value = false;
                    ctrl.lookupMessage.value = '';
                  }
                  return;
                }

                final parts = pick.split('|');
                final code = parts.isNotEmpty ? parts.first.trim() : '';
                final bankName =
                    parts.length > 1 ? parts.sublist(1).join('|').trim() : '';

                ctrl.form[name] = code;
                ctrl.form['bankCode'] = code;
                ctrl.form['bankName'] = bankName;

                if (_needsLookupFlow) {
                  ctrl.form.remove('accountName');
                  ctrl.resolvedName.value = null;
                  ctrl.lookupAvailable.value = false;
                  ctrl.lookupMessage.value = '';
                }
              },
              validator: required
                  ? (v) => (v == null || v.isEmpty) ? 'Required' : null
                  : null,
            ),
          ],
        );
      });
    }

    if (nameLower == 'accountnumber') {
      return Obx(() {
        final showVerify = _needsLookupFlow;

        final an = (ctrl.form['accountNumber'] ?? '').toString().trim();
        final is10Digits = RegExp(r'^\d{10}$').hasMatch(an);
        final canResolve = showVerify && ctrl.canResolveAccount && is10Digits;

        final resName = ctrl.resolvedName.value;
        final formName = ctrl.form['accountName'];
        final resolved = (resName ?? formName ?? '').toString().trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
              decoration: _darkInputDecoration(
                label: showVerify ? 'Account Number' : _label(name),
                icon: Icons.numbers_rounded,
                helper: showVerify ? 'Enter 10-digit account number' : null,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: showVerify
                  ? <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ]
                  : <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
              onChanged: (v) {
                ctrl.form[name] = v;

                if (showVerify) {
                  ctrl.form.remove('accountName');
                  ctrl.resolvedName.value = null;
                  ctrl.lookupAvailable.value = false;
                  ctrl.lookupMessage.value = '';
                  ctrl.form.refresh();
                }
              },
              validator: required
                  ? (v) {
                      final vv = (v ?? '').trim();
                      if (vv.isEmpty) return 'Required';
                      if (showVerify && !RegExp(r'^\d{10}$').hasMatch(vv)) {
                        return 'Account number must be 10 digits';
                      }
                      return null;
                    }
                  : null,
            ),
            if (showVerify) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canResolve ? () => ctrl.resolveNow() : null,
                  icon: ctrl.resolvingName.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_rounded),
                  label: const Text(
                    'Verify Account',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kIceBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              if (resolved.isNotEmpty) _verifiedNameCard(resolved),
              if (resolved.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Verify to fetch account name.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ],
        );
      });
    }

    final isNumber = type == 'number' || type == 'integer';
    return TextFormField(
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      decoration: _darkInputDecoration(
        label: _label(name),
        icon: isNumber ? Icons.calculate_rounded : Icons.text_fields_rounded,
      ),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: (v) => ctrl.form[name] = v,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  'Recipient Details',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    _GlassSection(
                      title: 'Provide Details',
                      subtitle: 'Fill in the required recipient information',
                      child: Form(
                        key: _formKey,
                        child: Obx(() {
                          final mustVerify = _needsLookupFlow;
                          final resName = ctrl.resolvedName.value;
                          final formName = ctrl.form['accountName'];
                          final resolved =
                              (resName ?? formName ?? '').toString().trim();

                          final canContinue =
                              !mustVerify || resolved.isNotEmpty;

                          return Column(
                            children: [
                              ...ctrl.fields.map(buildDynamicField),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: canContinue
                                      ? () {
                                          if (_formKey.currentState!
                                              .validate()) {
                                            ctrl.step.value = 3;
                                            Get.to(() =>
                                                const SendMoneyConfirmView());
                                          }
                                        }
                                      : null,
                                  icon: const Icon(Icons.arrow_forward),
                                  label: Text(
                                    canContinue
                                        ? 'Continue'
                                        : 'Verify account name to continue',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kIceBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bankSearchCtrl.dispose();
    _bankQuery.close();
    super.dispose();
  }
}

class _GlassSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _GlassSection(
      {required this.title, required this.child, this.subtitle});

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

InputDecoration _darkInputDecoration({
  required String label,
  required IconData icon,
  String? hint,
  String? helper,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
    helperStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
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
  );
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
