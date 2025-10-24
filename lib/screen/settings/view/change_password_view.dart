import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/colors.dart';
import '../../../services/change_password_service.dart';

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

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      Get.snackbar(
        "Error",
        "New passwords do not match",
        backgroundColor: Colors.red[600],
        colorText: Colors.white,
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
        backgroundColor: Colors.green[600],
        colorText: Colors.white,
      );
      Get.back();
    } on ChangePasswordError catch (e) {
      if (e.code == 'unauthorized') {
        Get.snackbar('Session expired', e.details ?? 'Please log in again.',
            backgroundColor: Colors.red, colorText: Colors.white);
        Get.offAllNamed('/login');
        return;
      }
      Get.snackbar(
        "Error",
        e.details ?? 'Could not change password',
        backgroundColor: Colors.red[600],
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (_) {
      Get.snackbar(
        "Error",
        "Something went wrong. Try again.",
        backgroundColor: Colors.red[600],
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
        backgroundColor: osvanGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                "Update your login password.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _oldPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Current Password",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _req(v, 'current password'),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "New Password",
                  border: OutlineInputBorder(),
                ),
                validator: _newPwdValidator,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm New Password",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _req(v, 'confirmation'),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: osvanGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 14,
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
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
