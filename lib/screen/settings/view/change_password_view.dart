// lib/screen/settings/views/change_password_view.dart
// Updated to match Dashboard luxury UI 100% (same theme + background + glass cards)
//
// ✅ Behavior kept: must be email-verified before changing password.
// ✅ Handles unauthorized → redirect to /login.
// ✅ Sticky CTA.
// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/colors.dart';
import '../../../services/change_password_service.dart';
import '../../../utils/nav.dart';
import '../controller/settings_controller.dart';

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _saving = false;

  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _req(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? 'Enter $label' : null;

  String? _newPwdValidator(String? v) {
    if (_req(v, 'new password') != null) return 'Enter new password';
    if ((v ?? '').length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  InputDecoration _dec(
    BuildContext context, {
    required String label,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      suffixIcon: suffix,
    );
  }

  Future<void> _changePassword() async {
    final sc = Get.find<SettingsController>();

    if (!sc.isVerified.value) {
      Get.snackbar(
        "Email not verified",
        "Please verify your email before changing password.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      Get.snackbar(
        "Error",
        "New passwords do not match",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ChangePasswordService.change(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      Get.snackbar(
        "Success",
        "Password changed successfully",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.back();
    } on ChangePasswordError catch (e) {
      if (e.code == 'unauthorized') {
        Get.snackbar(
          'Session expired',
          e.details ?? 'Please log in again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        Get.offAllNamed('/login');
        return;
      }

      Get.snackbar(
        "Error",
        e.details ?? 'Could not change password',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    } catch (_) {
      Get.snackbar(
        "Error",
        "Something went wrong. Try again.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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

              // Header
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
                          'Change Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              AbsorbPointer(
                absorbing: _saving,
                child: Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
                    children: [
                      if (_saving)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const LinearProgressIndicator(minHeight: 2),
                        ),
                      const SizedBox(height: 14),
                      SectionCard(
                        title: "Security",
                        subtitle: "Update your login password",
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _oldPasswordController,
                                obscureText: !_showOld,
                                decoration: _dec(
                                  context,
                                  label: "Current Password",
                                  suffix: IconButton(
                                    tooltip: _showOld ? "Hide" : "Show",
                                    onPressed: () =>
                                        setState(() => _showOld = !_showOld),
                                    icon: Icon(
                                      _showOld
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                                validator: (v) => _req(v, 'current password'),
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: !_showNew,
                                decoration: _dec(
                                  context,
                                  label: "New Password",
                                  suffix: IconButton(
                                    tooltip: _showNew ? "Hide" : "Show",
                                    onPressed: () =>
                                        setState(() => _showNew = !_showNew),
                                    icon: Icon(
                                      _showNew
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                                validator: _newPwdValidator,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: !_showConfirm,
                                decoration: _dec(
                                  context,
                                  label: "Confirm New Password",
                                  suffix: IconButton(
                                    tooltip: _showConfirm ? "Hide" : "Show",
                                    onPressed: () => setState(
                                      () => _showConfirm = !_showConfirm,
                                    ),
                                    icon: Icon(
                                      _showConfirm
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                                validator: (v) => _req(v, 'confirmation'),
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _changePassword(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky CTA (dashboard style)
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
                  onPressed: _saving ? null : _changePassword,
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
                          "Update Password",
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

// Background + blobs
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

// SectionCard (glass)
class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
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
              child: Padding(
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
