// lib/screen/wallet/views/add_money_view.dart
// Premium Add Money (VA + Collections) — modern, unique, luxury glass + consistent SectionCards
// - Logic preserved (VA via AddMoneyController, KE/UG via CollectionsService)
// - Adds premium UI: glass surfaces, header, better spacing, copy rows, empty/error states
//
// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/config/feature_flags.dart';
import 'package:osvan_app/core/colors.dart';
// NGN VA (GetX)
import 'package:osvan_app/screen/wallet/controllers/add_money_controller.dart';
// KES/UGX Collections service
import 'package:osvan_app/screen/wallet/services/collections_service.dart';
// ✅ VA KYC form view import
import 'package:osvan_app/screen/wallet/view/va_kyc_form_view.dart';

class AddMoneyView extends StatefulWidget {
  const AddMoneyView({super.key});

  @override
  State<AddMoneyView> createState() => _AddMoneyViewState();
}

class _AddMoneyViewState extends State<AddMoneyView> {
  // Controllers/Services
  late final AddMoneyController addMoneyCtrl;
  late final CollectionsService collectionsSvc;

  // UI State
  String selectedCountry = 'Nigeria';
  String selectedMethod = 'Bank Transfer';

  Map<String, String> collectionDetails = {};
  bool isLoading = false;
  String? errorMessage;

  final ScrollController _scrollCtrl = ScrollController();

  // Countries displayed in the selector. Apple-facing UI shows only the
  // currently supported receiving account corridor.
  List<String> get countries => FeatureFlags.isAppleReviewSurface
      ? const ['Nigeria']
      : const ['Nigeria', 'Kenya', 'Uganda'];

  // Countries where Mobile Money may be supported
  final mobileMoneyCountries = const {'Kenya', 'Uganda'};

  bool supportsBoth(String country) => mobileMoneyCountries.contains(country);

  @override
  void initState() {
    super.initState();

    // Wire GetX controller locally
    addMoneyCtrl = Get.put(AddMoneyController(), tag: 'inline-add-money');
    addMoneyCtrl.selectedCurrency.value = 'NGN';
    addMoneyCtrl.loadVA();

    // Collections service
    collectionsSvc = CollectionsService();

    _loadFundingDetails();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    Get.delete<AddMoneyController>(tag: 'inline-add-money', force: true);
    super.dispose();
  }

  Future<void> _loadFundingDetails() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      collectionDetails.clear();
    });

    try {
      if (selectedCountry == 'Nigeria') {
        // NGN handled by GetX card (VA) – nothing to fetch here.
        errorMessage = null;
      } else if (selectedCountry == 'Kenya' || selectedCountry == 'Uganda') {
        await _fetchCollectionDetails(); // uses current selectedMethod
      } else {
        errorMessage = 'Funding for $selectedCountry is currently unavailable.';
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchCollectionDetails() async {
    try {
      final method = (selectedMethod == 'Mobile Money') ? 'momo' : 'bank';
      final data = await collectionsSvc.getDetails(
        country: selectedCountry,
        method: method,
      );

      // Defensive normalization: accept any dynamic map, stringify values
      collectionDetails = {
        for (final entry in data.entries)
          entry.key.toString(): (entry.value).toString(),
      };

      errorMessage = null;
    } catch (e) {
      collectionDetails = {};
      errorMessage = e.toString();
    }
    if (mounted) setState(() {});
  }

  List<Map<String, String>> getCountryFields() {
    if (selectedCountry == 'Nigeria') {
      return const [
        {'label': 'Info', 'value': 'Use the Receiving Account (NGN) card above.'},
      ];
    }

    if ((selectedCountry == 'Kenya' || selectedCountry == 'Uganda') &&
        collectionDetails.isNotEmpty) {
      return collectionDetails.entries
          .map((e) => {'label': e.key, 'value': e.value})
          .toList();
    }

    if (errorMessage != null) {
      return [
        {'label': 'Info', 'value': errorMessage!},
      ];
    }

    return const [
      {'label': 'Account/Paybill', 'value': 'Coming Soon'},
      {'label': 'Reference', 'value': '---'},
      {'label': 'Provider', 'value': '---'},
    ];
  }

  Future<void> copyToClipboard(String label, String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: v));
    if (!mounted) return;
    Get.snackbar(
      'Copied',
      '$label copied',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _onPullToRefresh() async {
    final isNigeria = selectedCountry == 'Nigeria';
    final isKEorUG = selectedCountry == 'Kenya' || selectedCountry == 'Uganda';

    setState(() {
      errorMessage = null;
    });

    if (isNigeria) {
      await addMoneyCtrl.loadVA();
    }
    if (isKEorUG) {
      await _fetchCollectionDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    const isDark = true;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF070B14), Color(0xFF0B1220), Color(0xFF070B14)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Add Money'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: Stack(
          children: [
            const _LuxuryBackground(),
            RefreshIndicator(
              onRefresh: _onPullToRefresh,
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  _HeroHeader(
                    title: "Fund your wallet",
                    subtitle: FeatureFlags.isAppleReviewSurface
                        ? "Use your Nigeria receiving account for NGN bank transfers."
                        : "Use bank transfer or mobile money depending on your country.",
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // ——— NGN Receiving Account (GetX) ———
                  Obx(() {
                    final show = (selectedCountry == 'Nigeria');
                    if (!show) return const SizedBox.shrink();

                    final va = addMoneyCtrl.va.value;

                    return _GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                              icon: Icons.account_balance_rounded,
                              title: 'Receiving Account (NGN)',
                              subtitle:
                                  'Fund your NGN wallet via bank transfer',
                            ),
                            const SizedBox(height: 12),
                            if (addMoneyCtrl.isLoadingVA.value)
                              const LinearProgressIndicator(minHeight: 2),
                            if (addMoneyCtrl.vaError.value != null) ...[
                              const SizedBox(height: 10),
                              _InlineError(text: addMoneyCtrl.vaError.value!),
                            ],
                            if (va == null) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Create your receiving account to fund your NGN wallet by bank transfer.',
                                style: th.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  _PrimaryButton(
                                    text: 'Get Receiving Account',
                                    onPressed: () async {
                                      final ok = await Get.to<bool>(
                                        () => const VAKycFormView(),
                                        arguments: {'inline': true},
                                      );
                                      if (ok == true && mounted) {
                                        await addMoneyCtrl.loadVA();
                                        Get.snackbar(
                                          'Success',
                                          'Receiving account created',
                                          snackPosition: SnackPosition.BOTTOM,
                                        );
                                      }
                                    },
                                  ),
                                  _SecondaryButton(
                                    text: 'Refresh',
                                    onPressed: addMoneyCtrl.loadVA,
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 10),
                              _CopyRow(
                                label: 'Bank',
                                value:
                                    '${va['bank_name'] ?? va['provider'] ?? '-'}',
                                onCopy: () => copyToClipboard(
                                  'Bank',
                                  '${va['bank_name'] ?? va['provider'] ?? '-'}',
                                ),
                              ),
                              _CopyRow(
                                label: 'Account Name',
                                value: '${va['account_name'] ?? '-'}',
                                onCopy: () => copyToClipboard(
                                  'Account Name',
                                  '${va['account_name'] ?? '-'}',
                                ),
                              ),
                              _CopyRow(
                                label: 'Account Number',
                                value: '${va['account_number'] ?? '-'}',
                                strong: true,
                                onCopy: () => copyToClipboard(
                                  'Account Number',
                                  '${va['account_number'] ?? ''}',
                                ),
                              ),
                              if ((va['bank_code'] ?? '').toString().isNotEmpty)
                                _CopyRow(
                                  label: 'Bank Code',
                                  value: '${va['bank_code']}',
                                  onCopy: () => copyToClipboard(
                                    'Bank Code',
                                    '${va['bank_code']}',
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  _SecondaryButton(
                                    text: 'Refresh',
                                    onPressed: addMoneyCtrl.loadVA,
                                  ),
                                  _SecondaryButton(
                                    text: 'Copy Receiving Account',
                                    onPressed: () {
                                      final acct = (va['account_number'] ?? '')
                                          .toString();
                                      if (acct.isNotEmpty) {
                                        copyToClipboard('Receiving Account', acct);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _FootNote(
                                text:
                                    'Send NGN to this account number. Your wallet will update automatically after deposit.',
                                isDark: isDark,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  // ——— Country selector (NG | KE | UG) ———
                  _GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionTitle(
                            icon: Icons.public_rounded,
                            title: 'Funding location',
                            subtitle: FeatureFlags.isAppleReviewSurface
                                ? 'Nigeria bank transfer only'
                                : 'Choose where you are funding from',
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedCountry,
                            decoration: _dec(
                              context,
                              label: 'Country',
                              icon: Icons.public,
                            ),
                            items: countries
                                .map((country) => DropdownMenuItem<String>(
                                      value: country,
                                      child: Text(
                                        country,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                selectedCountry = val;
                                selectedMethod = 'Bank Transfer';
                                collectionDetails.clear();
                                errorMessage = null;
                              });
                              _loadFundingDetails();
                            },
                          ),
                          if (supportsBoth(selectedCountry)) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: selectedMethod,
                              decoration: _dec(
                                context,
                                label: 'Payment Method',
                                icon: Icons.payments_outlined,
                              ),
                              items: const ['Bank Transfer', 'Mobile Money']
                                  .map((m) => DropdownMenuItem<String>(
                                        value: m,
                                        child: Text(
                                          m,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (val) async {
                                if (val == null) return;
                                setState(() => selectedMethod = val);
                                if (selectedCountry == 'Kenya' ||
                                    selectedCountry == 'Uganda') {
                                  await _fetchCollectionDetails();
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ——— Details box (KE/UG collections; NG shows info note) ———
                  _GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            icon: (selectedMethod == 'Mobile Money')
                                ? Icons.phone_iphone_rounded
                                : Icons.receipt_long_rounded,
                            title: (selectedCountry == 'Kenya' ||
                                    selectedCountry == 'Uganda')
                                ? (selectedMethod == 'Mobile Money'
                                    ? 'Mobile Money details'
                                    : 'Bank transfer details')
                                : 'Funding details',
                            subtitle: 'Tap any row to copy',
                          ),
                          const SizedBox(height: 12),
                          if (isLoading)
                            const LinearProgressIndicator(minHeight: 2)
                          else ...[
                            if ((selectedCountry == 'Kenya' ||
                                    selectedCountry == 'Uganda') &&
                                errorMessage != null) ...[
                              _InlineError(text: errorMessage!),
                              const SizedBox(height: 10),
                            ],
                            if (getCountryFields().isEmpty)
                              _EmptyState(isDark: isDark)
                            else
                              ...getCountryFields().map((item) {
                                final label = item['label'] ?? 'Field';
                                final value = item['value'] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _CopyRow(
                                    label: label,
                                    value: value,
                                    onCopy: () => copyToClipboard(label, value),
                                    onTap: () => copyToClipboard(label, value),
                                  ),
                                );
                              }),
                            if (selectedCountry == 'Nigeria') ...[
                              const SizedBox(height: 6),
                              _FootNote(
                                text:
                                    'Use the Receiving Account (NGN) card above. Pull down to refresh.',
                                isDark: isDark,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Premium UI components (local to this file)
// ─────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;

  const _HeroHeader({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: th.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: th.textTheme.bodyMedium?.copyWith(
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.70),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _Pill(text: 'SECURE'),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF60A5FA).withOpacity(isDark ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF60A5FA).withOpacity(isDark ? 0.28 : 0.22),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.4,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: osvanGreen.withOpacity(isDark ? 0.16 : 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: osvanGreen.withOpacity(isDark ? 0.22 : 0.16),
            ),
          ),
          child: Icon(icon, color: osvanGreen, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: th.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: th.textTheme.bodySmall?.copyWith(
                  color: th.textTheme.bodySmall?.color?.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: osvanGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _SecondaryButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white : Colors.black,
        side: BorderSide(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;
  final VoidCallback? onTap;
  final bool strong;

  const _CopyRow({
    required this.label,
    required this.value,
    this.onCopy,
    this.onTap,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: th.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.78),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: th.textTheme.bodyMedium?.copyWith(
                      fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                      letterSpacing: strong ? 0.2 : 0.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF60A5FA).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF60A5FA).withOpacity(0.22),
                  ),
                ),
                child: Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String text;
  const _InlineError({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.85),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
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

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 18,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.70)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "No details yet. Pull down to refresh.",
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
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: size,
            height: size,
            color: color.withOpacity(0.12),
          ),
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
          colors: [
            Color(0xFF070B14),
            Color(0xFF0B1220),
            Color(0xFF070B14),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -80,
            child: _GlowBlob(color: osvanGreen, size: 260),
          ),
          Positioned(
            top: 140,
            right: -120,
            child: _GlowBlob(color: Colors.blueAccent, size: 260),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _GlowBlob(color: Colors.purpleAccent, size: 300),
          ),
        ],
      ),
    );
  }
}

InputDecoration _dec(
  BuildContext context, {
  required String label,
  required IconData icon,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color: (isDark ? Colors.white : Colors.black).withOpacity(0.10),
    ),
  );

  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: osvanGreen, width: 1.3),
    ),
    filled: true,
    fillColor: isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}
