// lib/screen/auth/login_view.dart
// Premium auth UI (glass + luxury card) + biometrics + dark-mode toggle
// - Keeps your AuthController flow untouched (auth.login() -> /main)
// - Stores last email in GetStorage
//
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:osvan_app/utils/nav.dart';
import 'package:get_storage/get_storage.dart';
import 'package:osvan_app/controller/auth_controller.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/services/biometric_service.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _box = GetStorage();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _uiLoading = false;
  bool _credentialsReady = false;

  @override
  void initState() {
    super.initState();

    final savedEmail = _box.read<String>('last_login_email') ?? '';
    if (savedEmail.isNotEmpty) _emailController.text = savedEmail;
    _passwordController.clear();
    _emailController.addListener(_syncCredentialsReady);
    _passwordController.addListener(_syncCredentialsReady);
    _syncCredentialsReady();
  }

  @override
  void dispose() {
    _emailController.removeListener(_syncCredentialsReady);
    _passwordController.removeListener(_syncCredentialsReady);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _syncCredentialsReady() {
    final ready = _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
    if (ready == _credentialsReady) return;
    setState(() => _credentialsReady = ready);
  }

  Future<void> _handleLoginViaController({required bool biometric}) async {
    final auth = Get.find<AuthController>();
    if (_uiLoading || auth.isLoading.value) return;
    if (biometric && !_credentialsReady) {
      _snack(
        title: 'Password required',
        msg: 'Enter your email and password before using biometrics.',
        bg: Colors.orange,
        icon: Icons.lock_outline,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    auth.errorText.value = null;
    debugPrint('[LoginView] starting login (biometric=$biometric)');

    if (biometric) {
      final ready = await BiometricService.isBiometricReady();
      if (!ready) {
        _snack(
          title: "Unavailable",
          msg:
              "Fingerprint/Face ID is not set on this device. Please enable it in phone settings.",
          bg: Colors.orange,
          icon: Icons.fingerprint,
        );
        return;
      }

      final ok = await BiometricService.authenticateBiometric();
      if (!ok) {
        _snack(
          title: "Access denied",
          msg: BiometricService.lastErrorMessage ??
              "Fingerprint authentication failed",
          bg: Colors.redAccent,
          icon: Icons.error,
        );
        return;
      }
    }

    setState(() => _uiLoading = true);
    try {
      auth.emailCtrl.text = _emailController.text.trim();
      auth.passwordCtrl.text = _passwordController.text;

      await auth.login(); // tokens + navigation (/main)

      _box.write('last_login_email', _emailController.text.trim());
      _passwordController.clear();
    } catch (e) {
      auth.errorText.value =
          e.toString().replaceFirst('Exception: ', '').trim();
      debugPrint('[LoginView] login caught error: ${auth.errorText.value}');
      _snack(
        title: 'Login failed',
        msg: e.toString().replaceFirst('Exception: ', ''),
        bg: Colors.redAccent,
        icon: Icons.error,
      );
    } finally {
      debugPrint(
          '[LoginView] stopping loaders uiLoading=$_uiLoading ctrlLoading=${auth.isLoading.value}');
      if (mounted) setState(() => _uiLoading = false);
      auth.isLoading.value = false;
    }
  }

  void _snack({
    required String title,
    required String msg,
    required Color bg,
    required IconData icon,
  }) {
    Get.snackbar(
      title,
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: bg,
      colorText: Colors.white,
      icon: Icon(icon, color: Colors.white),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safeBack(),
        ),
        actions: [],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: const [
              Color(0xFF070B14),
              Color(0xFF0B1220),
              Color(0xFF101827),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // subtle glow blobs
            Positioned(
              top: -110,
              left: -70,
              child: _GlowBlob(
                color: const Color(0xFF60A5FA).withOpacity(.16),
                size: 260,
              ),
            ),
            Positioned(
              top: 220,
              right: -120,
              child: _GlowBlob(
                color: osvanGreen.withOpacity(.12),
                size: 300,
              ),
            ),
            Positioned(
              bottom: -120,
              left: -90,
              child: _GlowBlob(
                color: const Color(0xFFA78BFA).withOpacity(.10),
                size: 290,
              ),
            ),

            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _GlassCard(
                    child: _AuthCard(
                      emailController: _emailController,
                      passwordController: _passwordController,
                      formKey: _formKey,
                      obscurePassword: _obscurePassword,
                      uiLoading: _uiLoading,
                      credentialsReady: _credentialsReady,
                      onToggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      onLogin: () =>
                          _handleLoginViaController(biometric: false),
                      onBiometricLogin: () =>
                          _handleLoginViaController(biometric: true),
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

class _AuthCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final bool obscurePassword;
  final bool uiLoading;
  final bool credentialsReady;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onLogin;
  final Future<void> Function() onBiometricLogin;

  const _AuthCard({
    required this.emailController,
    required this.passwordController,
    required this.formKey,
    required this.obscurePassword,
    required this.uiLoading,
    required this.credentialsReady,
    required this.onToggleObscure,
    required this.onLogin,
    required this.onBiometricLogin,
  });

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final auth = Get.find<AuthController>();

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Colors.white.withOpacity(0.10),
      ),
    );

    InputDecoration dec({
      required String label,
      required IconData icon,
      Widget? suffix,
    }) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.35),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.055),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Form(
        key: formKey,
        child: Obx(() {
          final showLoading = uiLoading || auth.isLoading.value;
          final err = auth.errorText.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF60A5FA).withOpacity(0.95),
                          osvanGreen.withOpacity(0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF60A5FA).withOpacity(0.22),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: th.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Access your Osvan wallet securely',
                          style: th.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.66),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.055),
                      const Color(0xFF60A5FA).withOpacity(0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/fingerprint.svg',
                      height: 20,
                      width: 20,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF60A5FA),
                        BlendMode.srcIn,
                      ),
                      placeholderBuilder: (_) => const Icon(
                        Icons.fingerprint,
                        size: 20,
                        color: Color(0xFF60A5FA),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        credentialsReady
                            ? 'Biometric confirmation ready'
                            : 'Enter password to enable biometrics',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: credentialsReady
                            ? osvanGreen
                            : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (credentialsReady
                                    ? osvanGreen
                                    : const Color(0xFFF59E0B))
                                .withOpacity(0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (err != null && err.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          err,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Email
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !showLoading,
                decoration:
                    dec(label: 'Email address', icon: Icons.email_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
                  return ok ? null : 'Enter a valid email';
                },
              ),
              const SizedBox(height: 14),

              // Password
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                enabled: !showLoading,
                decoration: dec(
                  label: 'Password',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    onPressed: showLoading ? null : onToggleObscure,
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Please enter your password'
                    : null,
                onFieldSubmitted: (_) => showLoading ? null : onLogin(),
              ),

              const SizedBox(height: 10),
              Row(
                children: [
                  _MiniSignal(
                    icon: credentialsReady
                        ? Icons.fingerprint_rounded
                        : Icons.lock_outline_rounded,
                    label:
                        credentialsReady ? 'Biometric ready' : 'Password first',
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: showLoading
                        ? null
                        : () => Get.toNamed('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Login actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: showLoading ? null : onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF60A5FA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: showLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: credentialsReady
                        ? 'Confirm with biometrics'
                        : 'Enter password first',
                    child: ElevatedButton(
                      onPressed: showLoading || !credentialsReady
                          ? null
                          : onBiometricLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: credentialsReady
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white.withOpacity(0.035),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: const CircleBorder(),
                        elevation: 0,
                      ),
                      child: const Icon(Icons.fingerprint, size: 22),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: (Colors.white).withOpacity(0.12),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'or',
                      style: TextStyle(
                        color: (Colors.white).withOpacity(0.55),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: (Colors.white).withOpacity(0.12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed:
                        showLoading ? null : () => Get.toNamed('/register'),
                    child: const Text('Register'),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F172A).withOpacity(0.96),
              const Color(0xFF111C33).withOpacity(0.94),
              const Color(0xFF08111F).withOpacity(0.98),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withOpacity(0.10),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 22,
              color: Colors.black.withOpacity(0.34),
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _MiniSignal extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniSignal({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: osvanGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 12,
              fontWeight: FontWeight.w800,
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
