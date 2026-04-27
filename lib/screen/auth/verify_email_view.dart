// lib/screen/auth/verify_email_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/services/auth_service.dart';
import 'package:osvan_app/services/register_service.dart';

class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({super.key});

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();

  bool _busy = false;
  late final String email;
  late final String password; // used to login after verify

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? {};
    email = (args['email'] ?? '').toString().trim();
    password = (args['password'] ?? '').toString();

    // Immediately request a fresh OTP to avoid expiry/race issues.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resend(auto: true));
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      // Verify OTP
      await RegisterService.verifyEmailOtp(
        email: email,
        code: _codeCtrl.text.trim(),
      );

      // Login → go main shell
      await AuthService.login(email: email, password: password, username: '');
      Get.offAllNamed('/main');

      Get.snackbar('Verified', 'Email verified successfully',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Verification failed', '$e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend({bool auto = false}) async {
    try {
      final dbg = await RegisterService.requestEmailOtp(email: email);

      // In dev/int, backend returns debugCode — auto-fill & auto-verify for speed.
      if ((dbg ?? '').isNotEmpty) {
        _codeCtrl.text = dbg!;
        if (auto && mounted) {
          // auto-verify only on first load to reduce user taps
          await _submit();
          return;
        }
        Get.snackbar('OTP sent', 'Code (dev): $dbg',
            backgroundColor: Colors.black87, colorText: Colors.white);
      } else {
        if (!auto) {
          Get.snackbar('OTP sent', 'Check your email: $email',
              backgroundColor: Colors.black87, colorText: Colors.white);
        }
      }
    } catch (e) {
      Get.snackbar('Error', '$e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text('We sent a 6-digit code to $email',
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Enter 6-digit code',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().length != 6)
                    ? 'Enter the 6-digit code'
                    : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Verify and Continue'),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => _resend(auto: false),
                child: const Text('Resend code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
