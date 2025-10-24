import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/colors.dart';
import '../../../services/auth_service.dart'; // for logout if you have it
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

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    // Safety confirm dialog
    Get.defaultDialog(
      title: "Confirm Closure",
      middleText: "Are you sure you want to close your account?",
      textConfirm: "Yes, Close",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
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
          );

          // Optional: clear tokens and send to login
          try { await AuthService.logout(); } catch (_) {}
          Get.offAllNamed("/login");
        } on CloseAccountError catch (e) {
          if (e.code == 'unauthorized') {
            Get.snackbar('Session expired', e.details ?? 'Please log in again.',
                backgroundColor: Colors.red, colorText: Colors.white);
            Get.offAllNamed('/login');
            return;
          }
          Get.snackbar(
            "Error",
            e.details ?? 'Could not submit request',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        } catch (_) {
          Get.snackbar(
            "Error",
            "Something went wrong. Try again.",
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        } finally {
          if (mounted) setState(() => _submitting = false);
        }
      },
    );
  }

  String? _confirmValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Type CLOSE to confirm';
    if (v.trim().toUpperCase() != 'CLOSE') return 'Please type CLOSE';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Close Account"),
        backgroundColor: osvanGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Closing your account is irreversible. Your cards will be frozen and wallets locked for review by compliance.",
                style: TextStyle(fontSize: 14, color: Colors.red),
              ),
              const SizedBox(height: 16),

              const Text(
                "Please tell us why you're closing your account (optional):",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Type your reason here...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _confirmCtrl,
                decoration: const InputDecoration(
                  labelText: 'Type CLOSE to confirm',
                  border: OutlineInputBorder(),
                ),
                validator: _confirmValidator,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 14,
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          "Request Account Closure",
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
