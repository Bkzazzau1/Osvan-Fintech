import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../services/password_reset_service.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _formKeyEmail = GlobalKey<FormState>();
  final _formKeyReset = GlobalKey<FormState>();

  // Step 1
  final _emailCtrl = TextEditingController();

  // Step 2
  final _otpCtrl = TextEditingController(); // 6 digits
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // State
  bool _requesting = false;
  bool _resetting = false;
  bool _stepTwo = false;

  // Resend timer
  static const int _resendSeconds = 60;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _req(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? 'Enter $label' : null;

  String? _emailValidator(String? v) {
    if (_req(v, 'email') != null) return 'Enter email';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim());
    return ok ? null : 'Enter a valid email';
  }

  String? _passwordValidator(String? v) {
    if (_req(v, 'password') != null) return 'Enter password';
    if ((v ?? '').length < 6) return 'Minimum 6 characters';
    return null;
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _countdown = 0);
        return;
      }
      setState(() => _countdown--);
    });
  }

  Future<void> _requestOtp() async {
    if (!_formKeyEmail.currentState!.validate()) return;
    setState(() => _requesting = true);
    try {
      await PasswordResetService.requestOtp(email: _emailCtrl.text);
      Get.snackbar('OTP Sent', 'Check your email for the 6-digit code.',
          backgroundColor: Colors.green, colorText: Colors.white);
      setState(() => _stepTwo = true);
      _startCountdown();
    } on PasswordResetError catch (e) {
      Get.snackbar('Error', e.details ?? 'Could not send OTP',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_countdown > 0) return;
    await _requestOtp();
  }

  Future<void> _submitReset() async {
    if (!_formKeyReset.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      Get.snackbar('Password', 'Passwords do not match',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    setState(() => _resetting = true);
    try {
      await PasswordResetService.resetWithOtp(
        email: _emailCtrl.text,
        otp: _otpCtrl.text,
        password: _passwordCtrl.text,
      );
      Get.snackbar('Password Reset', 'Your password has been updated.',
          backgroundColor: Colors.green, colorText: Colors.white);
      Get.offAllNamed('/login');
    } on PasswordResetError catch (e) {
      Get.snackbar('Error', e.details ?? 'Reset failed',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5));
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTwo ? 'Verify OTP & Reset' : 'Reset Password'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _stepTwo ? _buildStepTwo() : _buildStepOne(),
      ),
    );
  }

  // ---------- Step 1: enter email ----------
  Widget _buildStepOne() {
    return Form(
      key: _formKeyEmail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter your account email to receive an OTP.',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            validator: _emailValidator,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _requesting ? null : _requestOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _requesting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send OTP'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Get.offAllNamed('/login'),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  // ---------- Step 2: OTP + new password ----------
  Widget _buildStepTwo() {
    return Form(
      key: _formKeyReset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('We sent a 6-digit code to ${_emailCtrl.text.trim()}.',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6)
            ],
            decoration: const InputDecoration(
              labelText: 'OTP (6 digits)',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (_req(v, 'OTP') != null) return 'Enter OTP';
              if ((v ?? '').length != 6) return 'Enter 6 digits';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New Password',
              border: OutlineInputBorder(),
            ),
            validator: _passwordValidator,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm New Password',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v != _passwordCtrl.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: _countdown == 0 && !_requesting ? _resendOtp : null,
                child: Text(
                    _countdown == 0 ? 'Resend OTP' : 'Resend in $_countdown s'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetting ? null : _submitReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _resetting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Reset Password'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _stepTwo = false),
            child: const Text('Change email'),
          ),
        ],
      ),
    );
  }
}
