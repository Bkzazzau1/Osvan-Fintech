// lib/screen/settings/views/close_account_view.dart
// Updated to match Dashboard luxury UI 100% (same theme + background + glass cards)
//
// ✅ Behavior kept: confirm CLOSE, submit request, logout best-effort, redirect to /login
// ✅ Unauthorized → redirect to /login
// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/utils/nav.dart';

import '../../../core/colors.dart';
import '../../../services/auth_service.dart'; // optional: logout
import '../../../services/close_account_service.dart';

class CloseAccountView extends StatefulWidget {
  const CloseAccountView({super.key});

  @override
  State<CloseAccountView> createState() => _CloseAccountViewState();
}

class _CloseAccountViewState extends State<CloseAccountView> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _confirmValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Type CLOSE to confirm';
    if (v.trim().toUpperCase() != 'CLOSE') return 'Please type CLOSE';
    return null;
  }

  Future<void> _submitRequest() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    Get.defaultDialog(
      title: "Confirm Closure",
      middleText: "Are you sure you want to close your account?",
      textConfirm: "Yes, Close",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      cancelTextColor: Colors.white70,
      onConfirm: () async {
        Get.back(); // close dialog

        setState(() => _submitting = true);
        try {
          await CloseAccountService.submit(reason: _reasonController.text);

          Get.snackbar(
            "Request Sent",
            "Your account closure request has been submitted.",
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );

          // best-effort logout
          try {
            await AuthService.logout();
          } catch (_) {}

          Get.offAllNamed("/login");
        } on CloseAccountError catch (e) {
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
            e.details ?? 'Could not submit request',
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
          if (mounted) setState(() => _submitting = false);
        }
      },
    );
  }

  InputDecoration _dec(
    BuildContext context, {
    required String label,
    String? hint,
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
    );
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
                          'Close Account',
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
                absorbing: _submitting,
                child: Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
                    children: [
                      if (_submitting)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const LinearProgressIndicator(minHeight: 2),
                        ),
                      const SizedBox(height: 14),

                      SectionCard(
                        title: "Warning",
                        subtitle: "This action is irreversible",
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.35),
                            ),
                          ),
                          child: const Text(
                            "Closing your account is irreversible. Your cards may be frozen and wallets locked for compliance review.",
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.35,
                              color: Colors.red,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SectionCard(
                        title: "Closure request",
                        subtitle: "Help us understand why (optional)",
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _reasonController,
                                maxLines: 4,
                                decoration: _dec(
                                  context,
                                  label: "Reason (optional)",
                                  hint: "Type your reason here...",
                                ),
                                textInputAction: TextInputAction.newline,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmCtrl,
                                decoration: _dec(
                                  context,
                                  label: "Type CLOSE to confirm",
                                ),
                                validator: _confirmValidator,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submitRequest(),
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
                  onPressed: _submitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Request Account Closure",
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
