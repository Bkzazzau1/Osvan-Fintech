// lib/screen/auth/login_view.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/controller/theme_controller.dart';
import 'package:osvan_app/screen/wallet/services/wallets_service.dart';
import 'package:osvan_app/services/auth_service.dart'; // ✅ unified AuthService
import 'package:osvan_app/services/biometric_service.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _useFingerprint = false;
  bool _loading = false;

  final themeController = Get.find<ThemeController>();

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Optional biometric gate
    if (_useFingerprint) {
      final ok = await BiometricService.authenticateUser(useBiometrics: true);
      if (!ok) {
        Get.snackbar(
          "Access Denied",
          "Fingerprint authentication failed",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
          icon: const Icon(Icons.error, color: Colors.white),
        );
        return;
      }
    }

    setState(() => _loading = true);
    try {
      // Real backend login -> Django SimpleJWT (or your custom login)
      final result = await AuthService.login(
          email: email, password: password, username: '');

      String? access;
      String? refresh;

      if (result is String) {
        access = result as String?;
      } else {
        access = (result['access'] ?? result['token'] ?? result['access_token'])
            ?.toString();
      }
      refresh = (result['refresh'] ?? result['refresh_token'])?.toString();

      if (access == null || access.isEmpty) {
        throw Exception("Login response missing access token");
      }

      await AuthService.setTokens(access: access, refresh: refresh);

      // Fire-and-forget: prefetch wallets to make /main feel instant
      unawaited(Future(() async {
        try {
          await WalletsService.instance.fetchWallets();
        } catch (_) {}
      }));

      Get.snackbar(
        "Login Successful",
        "Welcome back",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      Get.offAllNamed('/main');
    } catch (e) {
      Get.snackbar(
        'Login Failed',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/logo.png',
                            width: 180,
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Center(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Welcome Back!',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Login to continue to Osvan.',
                                style: TextStyle(fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please enter your email'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(
                                    () => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please enter your password'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Get.toNamed('/forgot-password'),
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _loading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _loading
                                  ? null
                                  : () async {
                                      _useFingerprint = true;
                                      await _handleLogin();
                                      _useFingerprint = false;
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                padding: const EdgeInsets.all(16),
                                shape: const CircleBorder(),
                              ),
                              child: const Icon(Icons.fingerprint,
                                  size: 24, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Dark Mode'),
                            Obx(
                              () => Switch(
                                value: themeController.isDarkMode,
                                onChanged: (value) =>
                                    themeController.toggleTheme(value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account?"),
                            TextButton(
                              onPressed: () => Get.toNamed('/register'),
                              child: const Text('Register'),
                            ),
                          ],
                        ),

                        // ------------------------
                        // 🔧 Test Console (VA + Credit)
                        // ------------------------
                        const Divider(height: 32),
                        const Text('Test Console (VA + Credit)',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _ShortTestPanel(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------
// Internal: Short test panel
// ---------------------------
class _ShortTestPanel extends StatefulWidget {
  @override
  State<_ShortTestPanel> createState() => _ShortTestPanelState();
}

class _ShortTestPanelState extends State<_ShortTestPanel> {
  final tokenCtrl = TextEditingController();
  final walletCtrl = TextEditingController();
  final currencyCtrl = TextEditingController(text: 'NGN'); // kept for credit
  final amountCtrl = TextEditingController(text: '10.00');
  final logs = <String>[];
  void log(Object m) => setState(() => logs.add(m.toString()));

  @override
  void dispose() {
    tokenCtrl.dispose();
    walletCtrl.dispose();
    currencyCtrl.dispose();
    amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallets = WalletsService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: tokenCtrl,
          decoration: const InputDecoration(
            labelText: 'Paste ACCESS token (JWT)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: () async {
                try {
                  await AuthService.setTokens(access: tokenCtrl.text.trim());
                  log('Token set.');
                } catch (e) {
                  log('Set token error: $e');
                }
              },
              child: const Text('Set Token'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  final list = await wallets.fetchWallets();
                  log('Wallets: ${list.map((w) => w.id).toList()}');
                } catch (e) {
                  log('List wallets error: $e');
                }
              },
              child: const Text('List Wallets'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: walletCtrl,
          decoration: const InputDecoration(
            labelText: 'Wallet ID (optional for display/logs)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Currency (kept for credit)
            SizedBox(
              width: 110,
              child: TextField(
                controller: currencyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  // ✅ WalletsService.createVirtualAccount() has no 'currency' param
                  final va = await wallets.createVirtualAccount();
                  log('VA: $va');
                } catch (e) {
                  log('Create/Fetch VA error: $e');
                }
              },
              child: const Text('Create/Fetch VA'),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 140,
              child: TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  final ccy = (currencyCtrl.text.trim().isEmpty)
                      ? 'NGN'
                      : currencyCtrl.text.trim().toUpperCase();
                  // ✅ creditWallet expects {currency, amount}
                  final r = await wallets.creditWallet(
                    currency: ccy,
                    amount: amountCtrl.text.trim(),
                  );
                  log('Credit OK [$ccy]: $r');
                } catch (e) {
                  log('Credit error: $e');
                }
              },
              child: const Text('Credit Wallet'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 160,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ListView.builder(
            itemCount: logs.length,
            itemBuilder: (_, i) => Text(
              logs[i],
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }
}
