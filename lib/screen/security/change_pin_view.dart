// lib/screen/security/change_pin_view.dart
// Dashboard-Luxury Change PIN (100% consistent style)
// ✅ Keeps API calls exactly the same
// ✅ Adds 401 -> redirect to /login
// ✅ Glass cards + dashboard background + header row + sticky CTA
//
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../api/security/security_api.dart';
import '../../core/colors.dart';
import '../../services/api/core_client.dart';
import '../../utils/nav.dart';

class ChangePinView extends StatefulWidget {
  const ChangePinView({super.key});

  @override
  State<ChangePinView> createState() => _ChangePinViewState();
}

class _ChangePinViewState extends State<ChangePinView> {
  final _formKey = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();

  bool _submitting = false;
  bool _showOld = false;
  bool _showNew1 = false;
  bool _showNew2 = false;

  @override
  void dispose() {
    _old.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final o = _old.text.trim();
    final n1 = _new1.text.trim();
    final n2 = _new2.text.trim();

    if (n1 != n2) {
      _toastErr("Mismatch", "New PINs do not match");
      return;
    }
    if (o == n1) {
      _toastErr("Invalid", "New PIN must be different from current PIN");
      return;
    }
    if (!_isStrongEnough(n1)) {
      _toastErr("Weak PIN", "Avoid 0000, 1234, 1111 or repeated patterns");
      return;
    }

    setState(() => _submitting = true);
    try {
      await CoreClient.ensure();
      final api = SecurityApi(dio: CoreClient.I.dio);

      await api.changePin(oldPin: o, newPin: n1);

      _old.clear();
      _new1.clear();
      _new2.clear();

      await Get.dialog<void>(
        AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text(
            'Success',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'PIN changed successfully.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('OK',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      if (mounted) {
        Get.back(result: true);
      }
    } on DioException catch (e) {
      // 401 -> login
      if (e.response?.statusCode == 401) {
        Get.snackbar(
          "Session expired",
          "Please log in again.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Get.offAllNamed('/login');
        return;
      }

      final msg = _extractErr(e) ?? "Failed to change PIN. Please try again.";
      _toastErr("Error", msg);
    } catch (_) {
      _toastErr("Error", "Failed to change PIN. Please try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toastErr(String title, String msg) {
    Get.snackbar(
      title,
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  String? _extractErr(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map && data["message"] is String) return data["message"];
      if (data is Map && data["detail"] is String) return data["detail"];
      if (data is Map && data["error"] is String) return data["error"];
      if (data is Map && data["error"] is Map) {
        final err = data["error"];
        if (err["message"] is String) return err["message"];
        if (err["code"] is String) return err["code"];
      }
      if (data is String && data.trim().isNotEmpty) return data;
    } catch (_) {}
    return null;
  }

  bool _isStrongEnough(String pin) {
    if (pin.length != 4) return false;
    const weak = {
      "0000",
      "1111",
      "2222",
      "3333",
      "4444",
      "5555",
      "6666",
      "7777",
      "8888",
      "9999",
      "1234",
      "4321",
      "1212",
      "1122",
    };
    return !weak.contains(pin);
  }

  InputDecoration _dec({
    required String label,
    required IconData icon,
    required bool show,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      counterText: "",
      suffixIcon: IconButton(
        tooltip: show ? "Hide" : "Show",
        onPressed: onToggle,
        icon: Icon(
          show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        ),
      ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dashboard dark wrapper
    final dark = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF070B14),
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      colorScheme:
          const ColorScheme.dark(primary: osvanGreen, secondary: osvanGreen),
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

              // Header row (dashboard style)
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
                          'Change PIN',
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
                  child: Form(
                    key: _formKey,
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
                        title: "Security",
                        subtitle: "Update your 4-digit transaction PIN",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Choose a PIN that isn’t easy to guess.",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withOpacity(0.72),
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _old,
                              keyboardType: TextInputType.number,
                              obscureText: !_showOld,
                              maxLength: 4,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: _dec(
                                label: "Current PIN",
                                icon: Icons.lock_outline,
                                show: _showOld,
                                onToggle: () =>
                                    setState(() => _showOld = !_showOld),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length != 4)
                                      ? "PIN must be 4 digits"
                                      : null,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _new1,
                              keyboardType: TextInputType.number,
                              obscureText: !_showNew1,
                              maxLength: 4,
                              onChanged: (_) => setState(() {}),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: _dec(
                                label: "New PIN",
                                icon: Icons.lock_reset_rounded,
                                show: _showNew1,
                                onToggle: () =>
                                    setState(() => _showNew1 = !_showNew1),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length != 4)
                                      ? "PIN must be 4 digits"
                                      : null,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 10),
                            _PinStrengthBar(pin: _new1.text.trim()),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _new2,
                              keyboardType: TextInputType.number,
                              obscureText: !_showNew2,
                              maxLength: 4,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: _dec(
                                label: "Confirm New PIN",
                                icon: Icons.lock_rounded,
                                show: _showNew2,
                                onToggle: () =>
                                    setState(() => _showNew2 = !_showNew2),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length != 4)
                                      ? "PIN must be 4 digits"
                                      : null,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _save(),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () {
                                        Get.snackbar(
                                          "Forgot PIN",
                                          "Please contact support@osvan.africa to reset your PIN.",
                                          snackPosition: SnackPosition.BOTTOM,
                                        );
                                      },
                                child: const Text("Forgot PIN?"),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SectionCard(
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                size: 18, color: osvanGreen.withOpacity(0.95)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Never share your PIN. Osvan staff will never ask you for it.",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withOpacity(0.72),
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                child: ElevatedButton(
                  onPressed: _submitting ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: osvanGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          "Change PIN",
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
// Background (same as dashboard)
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
// Glass SectionCard (dashboard style)
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

// ──────────────────────────────────────────────────────────────────────────────
// PIN strength bar (kept)
// ──────────────────────────────────────────────────────────────────────────────
class _PinStrengthBar extends StatelessWidget {
  final String pin;
  const _PinStrengthBar({required this.pin});

  int _score(String p) {
    if (p.length != 4) return 0;

    const weak = {
      "0000",
      "1111",
      "2222",
      "3333",
      "4444",
      "5555",
      "6666",
      "7777",
      "8888",
      "9999",
      "1234",
      "4321",
      "1212",
      "1122",
    };
    if (weak.contains(p)) return 1;

    final allSame = p.split('').toSet().length == 1;
    if (allSame) return 1;

    final seqUp = p == "0123" ||
        p == "1234" ||
        p == "2345" ||
        p == "3456" ||
        p == "4567" ||
        p == "5678" ||
        p == "6789";
    final seqDn = p == "3210" ||
        p == "4321" ||
        p == "5432" ||
        p == "6543" ||
        p == "7654" ||
        p == "8765" ||
        p == "9876";
    if (seqUp || seqDn) return 1;

    final twoPairs = (p[0] == p[1] && p[2] == p[3]) && (p[0] != p[2]);
    final mirrored = p[0] == p[3] && p[1] == p[2];
    if (twoPairs || mirrored) return 2;

    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final s = _score(pin);

    final label = switch (s) {
      0 => "Enter new PIN",
      1 => "Weak PIN",
      2 => "Good PIN",
      _ => "Strong PIN",
    };

    final color = switch (s) {
      0 => (isDark ? Colors.white : Colors.black).withOpacity(0.25),
      1 => Colors.red,
      2 => const Color(0xFFF59E0B),
      _ => osvanGreen,
    };

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: s == 0 ? 0.15 : (s == 1 ? 0.33 : (s == 2 ? 0.66 : 1.0)),
              minHeight: 8,
              backgroundColor:
                  (isDark ? Colors.white : Colors.black).withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: th.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.72),
          ),
        )
      ],
    );
  }
}
