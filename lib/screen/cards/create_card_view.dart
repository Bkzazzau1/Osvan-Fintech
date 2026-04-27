// lib/screen/cards/create_card_view.dart
// Request-new-card form (Dashboard Luxury UI)
//
// FINAL BEHAVIOR (unchanged):
// - This page NEVER opens KYC. If KYC is missing, we show a non-clickable banner + block submit.
// - Amount is converted to MINOR units (cents). $1.00 => 100, sent as amountCents.
// - On success, navigate to CardsView and refresh there.
//
// UI:
// - Dashboard-style luxury background (same glow blobs + glass mood)
// - Uses shared SectionCard widget (single source of truth)
// - Uses bottomNavigationBar instead of Positioned sticky bar (less overlay/tap issues)
//
// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/routes/app_routes.dart';
import 'package:osvan_app/screen/cards/services/card_service.dart';
import 'package:osvan_app/screen/cards/view/widgets/section_card.dart';
import 'package:osvan_app/utils/nav.dart';

class CreateCardView extends StatefulWidget {
  const CreateCardView({super.key});

  @override
  State<CreateCardView> createState() => _CreateCardViewState();
}

class _CreateCardViewState extends State<CreateCardView> {
  final _formKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _amount = TextEditingController();

  final String _currency = 'USD'; // USD-only for now
  final String _brand = 'visa'; // visa only (mastercard hidden)
  final String _type = 'virtual'; // virtual only

  bool _submitting = false;
  final _kycDone = false.obs;
  static const int _maxCards = 3;
  bool _limitReached = false;
  int _cardCount = 0;

  @override
  void initState() {
    super.initState();
    _loadKycFlag();
    _checkCardLimit();
    _prefillFromProfile();
  }

  Future<void> _loadKycFlag() async {
    try {
      _kycDone.value = await CardService.isCardUserRegistered();
    } catch (_) {
      _kycDone.value = false;
    }
  }

  Future<void> _prefillFromProfile() async {
    try {
      final me = await CardService.getMeForCards();
      final email = (me['email'] ?? '').toString().trim();
      final first =
          (me['first_name'] ?? me['firstName'] ?? '').toString().trim();
      final last = (me['last_name'] ?? me['lastName'] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        if (email.isNotEmpty) _email.text = email;
        if (first.isNotEmpty) _firstName.text = first;
        if (last.isNotEmpty) _lastName.text = last;
        if (_amount.text.trim().isEmpty) _amount.text = '3';
      });
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _checkCardLimit() async {
    try {
      final items = await CardService.listCards();
      _cardCount = items
          .where((m) =>
              (m['status'] ?? '').toString().toUpperCase() != 'TERMINATED')
          .length;
      if (!mounted) return;
      setState(() => _limitReached = _cardCount >= _maxCards);
    } catch (_) {
      if (!mounted) return;
      setState(() => _limitReached = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _amount.dispose();
    super.dispose();
  }

  // ─────────────────── Validators ───────────────────
  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _emailV(String? v) {
    if (_req(v) != null) return 'Required';
    final s = v!.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Invalid email';
  }

  String? _money(String? v) {
    if (_req(v) != null) return 'Required';
    final n = _parseMoney(v);
    if (n == null || n <= 0) return 'Enter a valid amount';
    if (n < 3) return 'Minimum is \$3';
    return null;
  }

  // ─────────────────── Helpers ───────────────────
  String _uuidV4() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    return '${hex(b[0])}${hex(b[1])}${hex(b[2])}${hex(b[3])}-'
        '${hex(b[4])}${hex(b[5])}-'
        '${hex(b[6])}${hex(b[7])}-'
        '${hex(b[8])}${hex(b[9])}-'
        '${hex(b[10])}${hex(b[11])}${hex(b[12])}${hex(b[13])}${hex(b[14])}${hex(b[15])}';
  }

  double? _parseMoney(String? raw) {
    if (raw == null) return null;
    var s = raw.trim().replaceAll(',', '');
    if (s.startsWith('.')) s = '0$s';
    if (s.endsWith('.')) s = '${s}0';
    return double.tryParse(s);
  }

  int _toMinorUnits(double major) {
    final fixed = double.parse(major.toStringAsFixed(2));
    return (fixed * 100).round();
  }

  // ─────────────────── Submit ───────────────────
  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (!_kycDone.value) {
      Get.snackbar(
        'Complete KYC',
        'Please complete Card KYC from the Cards screen before requesting a card.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (_limitReached) {
      Get.snackbar(
        'Card limit reached',
        'You can create up to $_maxCards cards.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final parsed = _parseMoney(_amount.text);
      if (parsed == null || parsed <= 0) {
        Get.snackbar('Amount', 'Enter a valid amount',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final amountCents = _toMinorUnits(parsed);

      await CardService.createCard({
        'email': _email.text.trim(),
        'brand': _brand,
        'type': _type,
        'currency': _currency,
        'amountCents': amountCents,
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'reference': _uuidV4(),
      });

      Get.snackbar('Success', 'Card request submitted.',
          snackPosition: SnackPosition.BOTTOM);

      if (mounted) {
        Get.offAllNamed(AppRoutes.cards, arguments: {'refresh': true});
      }
    } on DioException catch (e) {
      final msg = _extractMsg(e.response?.data, e.message);
      Get.snackbar(
        'Request failed',
        msg.isNotEmpty ? msg : 'Request failed. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 6),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        _extractErr(e),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 6),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _extractMsg(dynamic body, String? fallback) {
    try {
      if (body is Map) {
        final nested = (body['payload'] is Map)
            ? ((body['payload']['payload']?['message'] ??
                    body['payload']['error'])
                ?.toString())
            : '';
        final direct =
            (body['error'] ?? body['message'] ?? body['detail'] ?? '')
                .toString();
        final msg = (direct.isNotEmpty ? direct : (nested ?? '')).toString();
        if (msg.isNotEmpty) return msg;
      }
      return (fallback ?? '').toString();
    } catch (_) {
      return (fallback ?? '').toString();
    }
  }

  String _extractErr(dynamic e) {
    try {
      if (e is DioException) {
        final b = e.response?.data;
        final m = _extractMsg(b, e.message);
        if (m.isNotEmpty) return m;
      }
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

  // ─────────────────── UI ───────────────────
  InputDecoration _dx(String label, {String? hint, String? prefixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      filled: true,
      fillColor: const Color(0xFF0F172A).withOpacity(0.55), // more glass
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: osvanGreen, width: 1.8),
      ),
      labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w700),
      hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.40), fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _brandPicker() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'visa', label: Text('Visa')),
      ],
      selected: const {'visa'},
      onSelectionChanged: (_) {},
    );
  }

  Widget _kycBanner() {
    return Obx(() {
      final ok = _kycDone.value;
      final color = ok ? osvanGreen : Colors.amber;
      final bg = ok
          ? osvanGreen.withValues(alpha: 0.12)
          : Colors.amber.withValues(alpha: 0.14);
      final border = ok
          ? osvanGreen.withValues(alpha: 0.35)
          : Colors.amber.withValues(alpha: 0.35);
      final headline = ok ? 'KYC approved' : 'KYC required';
      final text = ok
          ? 'You can request a virtual card now.'
          : 'Complete your Card KYC from the Cards screen before requesting a card.';

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(ok ? Icons.verified : Icons.verified_user,
                  color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _limitBanner() {
    if (!_limitReached) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Card limit reached',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You already have $_cardCount card(s). Maximum is $_maxCards.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _submitting;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        // keep dark mood consistent (same idea as dashboard wrapper)
        data: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF070B14),
          colorScheme: const ColorScheme.dark(
              primary: osvanGreen, secondary: osvanGreen),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF070B14),
          body: Stack(
            children: [
              const _LuxuryBackground(),

              // content
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => safeBack(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            tooltip: 'Back',
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),

                          // brand pill (same idea as dashboard)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: const Color(0xFF0F172A),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.06)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: osvanGreen,
                                    boxShadow: [
                                      BoxShadow(
                                          color: osvanGreen.withOpacity(0.35),
                                          blurRadius: 12),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Request Card',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),
                          IconButton(
                            tooltip: 'Refresh KYC',
                            onPressed: disabled ? null : _loadKycFlag,
                            icon: const Icon(Icons.refresh_rounded,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: disabled,
                        child: RefreshIndicator(
                          onRefresh: _loadKycFlag,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              if (_submitting)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: const LinearProgressIndicator(
                                      minHeight: 2),
                                ),
                              const SizedBox(height: 12),

                              SectionCard(
                                title: 'KYC',
                                subtitle:
                                    'This page cannot open KYC. Card requests require approved KYC.',
                                child: _kycBanner(),
                              ),

                              const SizedBox(height: 12),
                              _limitBanner(),
                              if (_limitReached) const SizedBox(height: 12),

                              SectionCard(
                                title: 'Card details',
                                subtitle:
                                    'Provide the basics to create your virtual card',
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _email,
                                        readOnly: true,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        decoration: _dx('Customer Email',
                                            hint: 'name@example.com'),
                                        validator: _emailV,
                                        textInputAction: TextInputAction.next,
                                      ),
                                      const SizedBox(height: 12),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _firstName,
                                              readOnly: true,
                                              decoration: _dx('First Name'),
                                              validator: _req,
                                              textInputAction:
                                                  TextInputAction.next,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _lastName,
                                              readOnly: true,
                                              decoration: _dx('Last Name'),
                                              validator: _req,
                                              textInputAction:
                                                  TextInputAction.next,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<String>(
                                              initialValue: _currency,
                                              decoration: _dx('Currency'),
                                              items: const [
                                                DropdownMenuItem(
                                                    value: 'USD',
                                                    child: Text('USD')),
                                              ],
                                              onChanged: (_) {},
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _amount,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              decoration: _dx(
                                                'Initial Amount (USD)',
                                                hint: 'e.g. 25.00',
                                                prefixText: '\$ ',
                                              ),
                                              validator: _money,
                                              textInputAction:
                                                  TextInputAction.done,
                                              onFieldSubmitted: (_) =>
                                                  _submit(),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Brand',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.85),
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            _brandPicker(),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Type: $_type',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.70),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              SectionCard(
                                title: 'Notes',
                                child: Text(
                                  '- Minimum initial funding is \$3.\n'
                                  '- Brand: Visa only. Type is virtual.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                  height: 110), // space for bottom bar
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.06))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 22,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: Obx(
                  () => ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: osvanGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: (_submitting || !_kycDone.value || _limitReached)
                        ? null
                        : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add_card),
                    label: Text(
                      _submitting ? 'Submitting...' : 'Request Card',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Same luxury background system as DashboardView
class _LuxuryBackground extends StatelessWidget {
  const _LuxuryBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF070B14), Color(0xFF0B1220), Color(0xFF070B14)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _GlowBlob(color: osvanGreen, size: 260, opacity: 0.12),
          ),
          Positioned(
            top: 140,
            right: -120,
            child:
                _GlowBlob(color: Colors.blueAccent, size: 260, opacity: 0.10),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child:
                _GlowBlob(color: Colors.purpleAccent, size: 300, opacity: 0.08),
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

  const _GlowBlob(
      {required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: size,
            height: size,
            color: color.withOpacity(opacity),
          ),
        ),
      ),
    );
  }
}
