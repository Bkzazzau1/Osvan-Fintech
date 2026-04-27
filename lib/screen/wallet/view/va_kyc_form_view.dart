// lib/screen/wallet/view/va_kyc_form_view.dart
// Premium KYC form UI (same logic) — modern, unique, luxury glass + consistent SectionCards
//
// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';

import '../controllers/va_kyc_form_controller.dart';

class VAKycFormView extends GetView<VAKycFormController> {
  const VAKycFormView({super.key});

  // Generate a hidden reference when empty (never shown to user)
  void _ensureHiddenReference() {
    if (controller.reference.text.trim().isEmpty) {
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final rnd = (Random().nextInt(900000) + 100000).toString(); // 6 digits
      controller.reference.text = 'OSV-VA-$ts-$rnd';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Defensive: ensure controller exists even if screen was pushed directly
    if (!Get.isRegistered<VAKycFormController>()) {
      Get.put(VAKycFormController());
    }

    // 🔒 Make sure a reference exists silently (no UI)
    _ensureHiddenReference();

    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF0B1220), Color(0xFF111827)]
              : const [Color(0xFFF6FAFF), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Create Virtual Account'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : Colors.black,
        ),
        body: Stack(
          children: [
            Positioned(
              top: -90,
              left: -80,
              child: _GlowBlob(
                color: osvanGreen.withOpacity(isDark ? .18 : .10),
                size: 240,
              ),
            ),
            Positioned(
              bottom: -110,
              right: -90,
              child: _GlowBlob(
                color: const Color(0xFF60A5FA).withOpacity(isDark ? .15 : .09),
                size: 280,
              ),
            ),
            Form(
              key: controller.formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeroHeader(
                    title: "Complete KYC",
                    subtitle: "Your details must match your identity record.",
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _SectionTitle(
                            icon: Icons.person_rounded,
                            title: 'Personal information',
                            subtitle: 'Enter your basic details',
                          ),
                          const SizedBox(height: 12),
                          _field(
                            context,
                            'First Name',
                            controller.firstName,
                            validator: controller.vReq,
                          ),
                          _field(
                            context,
                            'Last Name',
                            controller.lastName,
                            validator: controller.vReq,
                          ),
                          _field(
                            context,
                            'Email',
                            controller.customerEmail,
                            keyboard: TextInputType.emailAddress,
                            validator: controller.vEmail,
                          ),
                          _field(
                            context,
                            'Phone Number',
                            controller.phoneNumber,
                            keyboard: TextInputType.phone,
                            validator: controller.vPhone,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  _GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            icon: Icons.verified_user_rounded,
                            title: 'Bank & verification',
                            subtitle:
                                'Choose provider and add the required identity fields',
                          ),
                          const SizedBox(height: 12),

                          // Bank
                          Obx(
                            () => DropdownButtonFormField<String>(
                              value: controller.bank.value,
                              decoration: _dec(
                                context,
                                label: 'Bank',
                                icon: Icons.account_balance_outlined,
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'providus', child: Text('Providus')),
                                DropdownMenuItem(
                                    value: 'safehaven',
                                    child: Text('Safehaven')),
                              ],
                              onChanged: (v) {
                                if (v != null) controller.bank.value = v;
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          // BVN
                          _field(
                            context,
                            'BVN (11 digits)',
                            controller.bvn,
                            keyboard: TextInputType.number,
                            validator: controller.vBvn,
                          ),

                          const SizedBox(height: 12),

                          // DOB (only for Providus)
                          Obx(() {
                            final isProvidus =
                                controller.bank.value == 'providus';
                            final label = isProvidus
                                ? 'Date of Birth (YYYY-MM-DD) *'
                                : 'Date of Birth (YYYY-MM-DD) (only for Providus)';
                            return GestureDetector(
                              onTap: () => controller.pickDob(context),
                              child: AbsorbPointer(
                                absorbing: true,
                                child: _field(
                                  context,
                                  label,
                                  controller.dateOfBirth,
                                  validator: controller.vDobIfProvidus,
                                  suffix: const Icon(Icons.calendar_today),
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 10),
                          Obx(
                            () => controller.errorText.value == null
                                ? const SizedBox.shrink()
                                : _InlineError(
                                    text: controller.errorText.value!),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: controller.isSubmitting.value
                            ? null
                            : () {
                                _ensureHiddenReference();
                                controller.submit();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: osvanGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: controller.isSubmitting.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _FootNote(
                    text:
                        'We only use your information to create your virtual account with the selected bank.',
                    isDark: isDark,
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

  // Reusable input
  Widget _field(
    BuildContext context,
    String label,
    TextEditingController c, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        validator: validator,
        decoration: _dec(
          context,
          label: label,
          icon: Icons.edit_outlined,
          suffix: suffix,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Premium UI components (local)
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
    return Column(
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
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.70),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0F172A) : Colors.white)
                .withOpacity(isDark ? 0.72 : 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.10),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                color: Colors.black.withOpacity(isDark ? 0.30 : 0.08),
                offset: const Offset(0, 10),
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

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 60,
              spreadRadius: 10,
              color: color.withOpacity(0.55),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _dec(
  BuildContext context, {
  required String label,
  required IconData icon,
  Widget? suffix,
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
    suffixIcon: suffix,
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
