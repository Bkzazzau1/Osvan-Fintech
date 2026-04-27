// lib/screen/auth/register_view.dart
// Premium registration UI (glass + sectioned inputs)
// - Keeps your RegisterService usage intact
// - Fixes "title entering the box" by standardizing InputDecoration
// - Uses your same gradient background rule
//
// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';

import '../../../services/register_service.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();

  final _surnameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController(); // readOnly (yyyy-MM-dd)
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String _country = 'Nigeria';
  bool _saving = false;
  bool _pwVisible = false;
  bool _cpwVisible = false;
  DateTime? _dob;

  final List<String> _countries = const [
    'Nigeria',
    'Ghana',
    'Kenya',
    'United States',
    'United Kingdom',
    'Others',
  ];

  @override
  void dispose() {
    _surnameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _dobCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 100, 1, 1);
    final last = DateTime(now.year - 16, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: first,
      lastDate: last,
      helpText: 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = _formatDate(picked);
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _req(String? v, String label) {
    if (v == null || v.trim().isEmpty) return 'Enter $label';
    return null;
  }

  String? _emailValidator(String? v) {
    if (_req(v, 'email') != null) return 'Enter email';
    final s = v!.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  String? _passwordValidator(String? v) {
    if (_req(v, 'password') != null) return 'Enter password';
    if ((v ?? '').length < 6) return 'Minimum 6 characters';
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_dob == null) {
      Get.snackbar(
        'Date of Birth',
        'Please select your date of birth',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      Get.snackbar(
        'Password',
        'Passwords do not match',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await RegisterService.register(
        email: _emailCtrl.text.trim(),
        surname: _surnameCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim().isEmpty
            ? null
            : _middleNameCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text, // yyyy-MM-dd
        phone: _phoneCtrl.text.trim(),
        country: _country,
        password: _passwordCtrl.text,
        address: _addressCtrl.text.trim(),
      );

      final debugCode = await RegisterService.requestEmailOtp(
        email: _emailCtrl.text.trim(),
      );

      Get.snackbar(
        'Check your inbox',
        debugCode != null
            ? 'Dev code: $debugCode'
            : 'We sent a 6-digit code to your email',
        backgroundColor: Colors.black87,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );

      Get.toNamed('/verify-email', arguments: {
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });
    } on RegisterServiceError catch (e) {
      final msg = e.details ?? 'Registration failed';
      Get.snackbar(
        'Error',
        msg,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } catch (_) {
      Get.snackbar(
        'Error',
        'Something went wrong. Try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          title: const Text('Create Account'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: isDark ? Colors.white : Colors.black,
          elevation: 0,
        ),
        body: Stack(
          children: [
            Positioned(
              top: -80,
              left: -60,
              child: _GlowBlob(
                color: osvanGreen.withOpacity(isDark ? .18 : .10),
                size: 220,
              ),
            ),
            Positioned(
              bottom: -90,
              right: -70,
              child: _GlowBlob(
                color: const Color(0xFF60A5FA).withOpacity(isDark ? .16 : .10),
                size: 260,
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Register your account',
                              style: th.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fill in the details below to continue',
                              style: th.textTheme.bodyMedium?.copyWith(
                                color: th.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.65),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _SectionTitle(
                              icon: Icons.public,
                              title: 'Country',
                              subtitle: 'Choose your primary country',
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: _country,
                              items: _countries
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c)))
                                  .toList(),
                              onChanged: _saving
                                  ? null
                                  : (val) => setState(
                                      () => _country = val ?? _country),
                              decoration: _dec(
                                context,
                                label: 'Country',
                                icon: Icons.public,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _SectionTitle(
                              icon: Icons.badge_outlined,
                              title: 'Personal details',
                              subtitle: 'Use your real legal name',
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _surnameCtrl,
                                    enabled: !_saving,
                                    decoration: _dec(
                                      context,
                                      label: 'Surname',
                                      icon: Icons.badge_outlined,
                                      isDark: isDark,
                                    ),
                                    validator: (v) => _req(v, 'surname'),
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameCtrl,
                                    enabled: !_saving,
                                    decoration: _dec(
                                      context,
                                      label: 'First name',
                                      icon: Icons.person_outline,
                                      isDark: isDark,
                                    ),
                                    validator: (v) => _req(v, 'first name'),
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _middleNameCtrl,
                              enabled: !_saving,
                              decoration: _dec(
                                context,
                                label: 'Middle name (optional)',
                                icon: Icons.person_add_alt_1_outlined,
                                isDark: isDark,
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _dobCtrl,
                                    readOnly: true,
                                    enabled: !_saving,
                                    decoration: _dec(
                                      context,
                                      label: 'Date of birth (yyyy-MM-dd)',
                                      icon: Icons.cake_outlined,
                                      isDark: isDark,
                                      suffix: const Icon(Icons.calendar_today),
                                    ),
                                    onTap: _saving ? null : _pickDob,
                                    validator: (v) => _req(v, 'date of birth'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneCtrl,
                                    enabled: !_saving,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9+\-\s]'),
                                      )
                                    ],
                                    decoration: _dec(
                                      context,
                                      label: 'Phone number',
                                      icon: Icons.phone_outlined,
                                      isDark: isDark,
                                    ),
                                    validator: (v) => _req(v, 'phone number'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            _SectionTitle(
                              icon: Icons.alternate_email,
                              title: 'Account',
                              subtitle: 'We will verify your email',
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _emailCtrl,
                              enabled: !_saving,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _dec(
                                context,
                                label: 'Email address',
                                icon: Icons.alternate_email,
                                isDark: isDark,
                              ),
                              validator: _emailValidator,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _addressCtrl,
                              enabled: !_saving,
                              maxLines: 2,
                              decoration: _dec(
                                context,
                                label: 'Residential address',
                                icon: Icons.home_outlined,
                                isDark: isDark,
                              ),
                              validator: (v) => _req(v, 'address'),
                            ),
                            const SizedBox(height: 16),

                            _SectionTitle(
                              icon: Icons.lock_outline,
                              title: 'Security',
                              subtitle: 'Use a strong password',
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _passwordCtrl,
                              enabled: !_saving,
                              obscureText: !_pwVisible,
                              decoration: _dec(
                                context,
                                label: 'Password',
                                icon: Icons.lock_outline,
                                isDark: isDark,
                                suffix: IconButton(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(
                                          () => _pwVisible = !_pwVisible),
                                  icon: Icon(_pwVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                ),
                              ),
                              validator: _passwordValidator,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _confirmPasswordCtrl,
                              enabled: !_saving,
                              obscureText: !_cpwVisible,
                              decoration: _dec(
                                context,
                                label: 'Confirm password',
                                icon: Icons.lock_reset_outlined,
                                isDark: isDark,
                                suffix: IconButton(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(
                                          () => _cpwVisible = !_cpwVisible),
                                  icon: Icon(_cpwVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                ),
                              ),
                              validator: (v) => v != _passwordCtrl.text
                                  ? 'Passwords do not match'
                                  : null,
                            ),

                            const SizedBox(height: 18),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: osvanGreen,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
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
                                        'Register',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'By continuing, you agree to our Terms & Privacy Policy.',
                              style: th.textTheme.bodySmall?.copyWith(
                                color: th.textTheme.bodySmall?.color
                                    ?.withOpacity(0.65),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: TextButton(
                                onPressed: _saving
                                    ? null
                                    : () => Get.toNamed('/login'),
                                child: const Text(
                                    'Already have an account? Login'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
  required bool isDark,
  Widget? suffix,
}) {
  final th = Theme.of(context);
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
    labelStyle: th.textTheme.bodySmall?.copyWith(
      color: th.textTheme.bodySmall?.color?.withOpacity(0.75),
      fontWeight: FontWeight.w600,
    ),
  );
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
                .withOpacity(isDark ? 0.72 : 0.88),
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
