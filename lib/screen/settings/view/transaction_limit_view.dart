// lib/screen/settings/views/transaction_limit_view.dart
// Updated to match Dashboard luxury UI 100% (same theme + background + glass cards)
//
// ✅ Behavior kept: fetch limits, enforce min/max, editable flag, save to backend
// ✅ Unauthorized → redirect to /login
// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/utils/nav.dart';

import '../../../core/colors.dart';
import '../../../services/limit_service.dart';

class TransactionLimitView extends StatefulWidget {
  const TransactionLimitView({super.key});

  @override
  State<TransactionLimitView> createState() => _TransactionLimitViewState();
}

class _TransactionLimitViewState extends State<TransactionLimitView> {
  final _formKey = GlobalKey<FormState>();
  final _dailyCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _editable = true;

  int? _minDaily, _maxDaily, _minMonthly, _maxMonthly;
  int? _initialDaily, _initialMonthly;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final data = await LimitService.getLimits();
      final daily = (data['daily_limit'] ?? 10000).toInt();
      final monthly = (data['monthly_limit'] ?? 30000).toInt();

      _minDaily = (data['min_daily'] ?? 1).toInt();
      _maxDaily = (data['max_daily'] ?? 100000000).toInt();
      _minMonthly = (data['min_monthly'] ?? 1).toInt();
      _maxMonthly = (data['max_monthly'] ?? 1000000000).toInt();

      _editable = (data['editable'] ?? true) == true;

      _initialDaily = daily;
      _initialMonthly = monthly;

      _dailyCtrl.text = daily.toString();
      _monthlyCtrl.text = monthly.toString();
    } on LimitServiceError catch (e) {
      if (e.code == 'unauthorized') {
        Get.snackbar(
          'Session expired',
          'Please log in again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        Get.offAllNamed('/login');
        return;
      }
      Get.snackbar(
        'Error',
        'Could not load limits',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _numberValidator(
    String? value, {
    required int min,
    required int max,
    required String label,
  }) {
    if (value == null || value.trim().isEmpty) return 'Enter $label';
    final v = int.tryParse(value.replaceAll(',', ''));
    if (v == null) return 'Invalid $label';
    if (v < min) return '$label cannot be less than $min';
    if (v > max) return '$label cannot be more than $max';
    return null;
  }

  bool get _changed {
    final d = int.tryParse(_dailyCtrl.text.replaceAll(',', ''));
    final m = int.tryParse(_monthlyCtrl.text.replaceAll(',', ''));
    return d != _initialDaily || m != _initialMonthly;
  }

  Future<void> _save() async {
    if (!_editable) return;
    if (!_formKey.currentState!.validate()) return;

    final daily = int.parse(_dailyCtrl.text.replaceAll(',', ''));
    final monthly = int.parse(_monthlyCtrl.text.replaceAll(',', ''));

    setState(() => _saving = true);
    try {
      await LimitService.updateLimits(daily: daily, monthly: monthly);

      _initialDaily = daily;
      _initialMonthly = monthly;

      Get.snackbar(
        'Saved',
        'Your transaction limits have been updated.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.back();
    } on LimitServiceError catch (e) {
      if (e.code == 'unauthorized') {
        Get.offAllNamed('/login');
        return;
      }
      final msg = e.details ?? 'Failed to update limits';
      Get.snackbar(
        'Update failed',
        msg,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _dailyCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(
    BuildContext context, {
    required String label,
    String? prefixText,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      prefixText: prefixText,
      filled: true,
      fillColor: const Color(0xFF0F1524),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: osvanGreen, width: 1.7),
      ),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.78)),
      helperStyle: TextStyle(color: Colors.white.withOpacity(0.60)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _loading || _saving || !_editable;

    final desc = _editable
        ? 'View or edit your send limits below.'
        : 'Your limits are set by admin and cannot be changed.';

    // ✅ Dashboard dark wrapper
    final dark = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF070B14),
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: osvanGreen,
        secondary: osvanGreen,
      ),
    );

    return Theme(
      data: dark,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xFF070B14),
          body: Stack(
            children: [
              const _LuxuryBackground(),

              // Header (dashboard style)
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => safeBack(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Transaction Limits',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh',
                        onPressed: _loading ? null : _fetch,
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.only(top: 64),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _fetch,
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
                            children: [
                              if (_saving)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: const LinearProgressIndicator(
                                    minHeight: 2,
                                  ),
                                ),
                              const SizedBox(height: 14),

                              SectionCard(
                                title: 'Info',
                                subtitle: 'Keep your account safe',
                                child: Text(
                                  desc,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withOpacity(0.82),
                                        height: 1.3,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SectionCard(
                                title: 'Daily limit',
                                subtitle:
                                    (_minDaily != null && _maxDaily != null)
                                        ? 'Min: $_minDaily • Max: $_maxDaily'
                                        : null,
                                child: TextFormField(
                                  controller: _dailyCtrl,
                                  enabled: _editable && !_saving,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: _dec(
                                    context,
                                    label: 'Daily Limit',
                                    prefixText: '₦ ',
                                  ),
                                  validator: (v) => _numberValidator(
                                    v,
                                    min: _minDaily ?? 1,
                                    max: _maxDaily ?? 1000000000,
                                    label: 'daily limit',
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),
                              SectionCard(
                                title: 'Monthly limit',
                                subtitle: (_minMonthly != null &&
                                        _maxMonthly != null)
                                    ? 'Min: $_minMonthly • Max: $_maxMonthly'
                                    : null,
                                child: TextFormField(
                                  controller: _monthlyCtrl,
                                  enabled: _editable && !_saving,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: _dec(
                                    context,
                                    label: 'Monthly Limit',
                                    prefixText: '₦ ',
                                  ),
                                  validator: (v) => _numberValidator(
                                    v,
                                    min: _minMonthly ?? 1,
                                    max: _maxMonthly ?? 1000000000,
                                    label: 'monthly limit',
                                  ),
                                ),
                              ),

                              if (!_editable) ...[
                                const SizedBox(height: 14),
                                SectionCard(
                                  title: 'Note',
                                  child: Text(
                                    'Contact support to request an increase.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.white.withOpacity(0.72),
                                          height: 1.3,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),

          // Sticky Save Bar (dashboard style)
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
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
                child: ElevatedButton(
                  onPressed: (disabled || !_changed) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: osvanGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Limits',
                          style: TextStyle(fontWeight: FontWeight.w900),
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

// ──────────────────────────────────────────────────────────────────────────────
// Dashboard-matching background + blobs
// ──────────────────────────────────────────────────────────────────────────────
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
            child: _GlowBlob(color: osvanGreen, size: 260, opacity: 0.12),
          ),
          Positioned(
            top: 140,
            right: -120,
            child: _GlowBlob(
              color: Colors.blueAccent,
              size: 260,
              opacity: 0.10,
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _GlowBlob(
              color: Colors.purpleAccent,
              size: 300,
              opacity: 0.08,
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
            color: color.withOpacity(opacity),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Dashboard-matching SectionCard (glass)
// ──────────────────────────────────────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final bool noPadding;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.noPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || subtitle != null) ...[
          Text(
            title ?? '',
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: t.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.70),
                height: 1.2,
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: noPadding
                  ? child
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: child,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
