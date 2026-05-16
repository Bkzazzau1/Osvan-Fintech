// lib/screen/transfer/view/send_money_destination_view.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/screen/transfer/controllers/payout_wizard_controller.dart';
import 'package:osvan_app/screen/transfer/view/send_money_details_view.dart';
import 'package:osvan_app/services/api/payouts_api.dart';

const kDarkBg = Color(0xFF070B14);
const kDarkSurface = Color(0xFF0F172A);
const kDarkSurface2 = Color(0xFF0B1220);
const kIceBlue = Color(0xFF60A5FA);

class SendMoneyDestinationView extends StatefulWidget {
  const SendMoneyDestinationView({super.key});

  @override
  State<SendMoneyDestinationView> createState() =>
      _SendMoneyDestinationViewState();
}

class _SendMoneyDestinationViewState extends State<SendMoneyDestinationView> {
  final PayoutWizardController ctrl = Get.find<PayoutWizardController>();

  final _amountCtrl = TextEditingController();
  final _countrySearchCtrl = TextEditingController();
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    if (!_booted) {
      _booted = true;
      PayoutsApi.ensureInitialized().then((_) => ctrl.loadCountries());
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _countrySearchCtrl.dispose();
    super.dispose();
  }

  double _parseAmount(String v) {
    final cleaned = v.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  List<Map<String, String>> _filteredCountries(
    Iterable<Map<String, String>> items,
  ) {
    final query = _countrySearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return items.toList();

    return items.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final code = (c['code'] ?? '').toString().toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();
  }

  bool _selectedCountryMatchesSearch() {
    final query = _countrySearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return true;

    final selected = ctrl.countries.firstWhereOrNull(
      (c) =>
          (c['code'] ?? '').toString().toUpperCase() ==
          ctrl.countryCode.value.toUpperCase(),
    );
    if (selected == null) return false;

    final name = (selected['name'] ?? '').toString().toLowerCase();
    final code = (selected['code'] ?? '').toString().toLowerCase();
    return name.contains(query) || code.contains(query);
  }

  Future<void> _selectFirstFilteredCountry() async {
    final filtered = _filteredCountries(ctrl.countries);
    if (filtered.isEmpty) return;

    final code = (filtered.first['code'] ?? '').toString().trim();
    if (code.isEmpty) return;

    FocusScope.of(context).unfocus();
    await ctrl.onSelectCountry(code);
    if (mounted) setState(() {});
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
                  'Send Money',
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
                  delegate: SliverChildListDelegate.fixed([
                    Obx(() {
                      final loading = ctrl.isLoading.value;
                      final items = ctrl.countries;

                      return _GlassSection(
                        title: 'Destination',
                        subtitle: 'Choose where and how to send',
                        child: Column(
                          children: [
                            if (loading && items.isEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: LinearProgressIndicator(),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: List.generate(
                                  3,
                                  (i) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    height: 14,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (!loading && items.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'No countries available. Tap retry.',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75)),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton(
                                  onPressed: ctrl.loadCountries,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                        color: kIceBlue.withValues(alpha: 0.45)),
                                    backgroundColor:
                                        kIceBlue.withValues(alpha: 0.10),
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Search
                            _DarkTextField(
                              controller: _countrySearchCtrl,
                              label: 'Search country',
                              icon: Icons.search,
                              textInputAction: TextInputAction.search,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _selectFirstFilteredCountry(),
                            ),
                            const SizedBox(height: 12),

                            // Country dropdown
                            Obx(() {
                              final filtered = _filteredCountries(items);

                              final countryItems = filtered
                                  .map((c) => DropdownMenuItem<String>(
                                        value: c['code'],
                                        child: Text(
                                          '${c['name']} (${c['code']})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList();

                              final hasCurrent =
                                  ctrl.countryCode.value.isNotEmpty &&
                                      countryItems.any((it) =>
                                          it.value == ctrl.countryCode.value);

                              return _DarkDropdown<String>(
                                label: 'Country',
                                value:
                                    hasCurrent ? ctrl.countryCode.value : null,
                                hint: filtered.isEmpty
                                    ? 'No matching country'
                                    : 'Select country',
                                items: countryItems,
                                onChanged: loading
                                    ? null
                                    : (v) async {
                                        if (v == null) return;
                                        FocusScope.of(context).unfocus();
                                        await ctrl.onSelectCountry(v);
                                        if (mounted) setState(() {});
                                      },
                              );
                            }),

                            const SizedBox(height: 12),

                            // Method dropdown
                            Obx(() {
                              final ms = ctrl.methods.toList();
                              final current =
                                  ms.contains(ctrl.destination.value)
                                      ? ctrl.destination.value
                                      : (ms.isNotEmpty ? ms.first : null);

                              return _DarkDropdown<String>(
                                label: 'Method',
                                value: current,
                                items: ms
                                    .map((m) => DropdownMenuItem(
                                        value: m, child: Text(m)))
                                    .toList(),
                                onChanged: loading
                                    ? null
                                    : (v) async {
                                        if (v == null) return;
                                        await ctrl.onSelectMethod(v);
                                      },
                              );
                            }),

                            const SizedBox(height: 12),

                            // Amount
                            TextFormField(
                              controller: _amountCtrl,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800),
                              decoration: _darkInputDecoration(
                                label: 'Amount',
                                hint: 'e.g. 1000',
                                icon: Icons.payments_rounded,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}$'),
                                ),
                              ],
                              onChanged: (v) =>
                                  ctrl.amountMajor.value = _parseAmount(v),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Obx(() {
                      final loading = ctrl.isLoading.value;
                      final canContinue = !loading &&
                          ctrl.countryCode.value.isNotEmpty &&
                          _selectedCountryMatchesSearch() &&
                          ctrl.amountMajor.value > 0;

                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: canContinue
                              ? () {
                                  FocusScope.of(context).unfocus();
                                  ctrl.step.value = 2;
                                  Get.to(() => const SendMoneyDetailsView());
                                }
                              : () {
                                  if (loading) return;
                                  Get.snackbar(
                                    'Missing info',
                                    'Select the country from the list and enter an amount',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text(
                            'Continue',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kIceBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      );
                    }),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  const _DarkTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: _darkInputDecoration(label: label, hint: null, icon: icon),
    );
  }
}

class _DarkDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const _DarkDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      isExpanded: true,
      initialValue: value,
      hint: hint == null
          ? null
          : Text(
              hint!,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontWeight: FontWeight.w800,
              ),
            ),
      items: items,
      onChanged: onChanged,
      dropdownColor: kDarkSurface,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      decoration:
          _darkInputDecoration(label: label, hint: null, icon: Icons.public),
    );
  }
}

InputDecoration _darkInputDecoration({
  required String label,
  String? hint,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
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
