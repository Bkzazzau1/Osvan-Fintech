import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/colors.dart';

class ChangePinView extends StatefulWidget {
  const ChangePinView({super.key});

  @override
  State<ChangePinView> createState() => _ChangePinViewState();
}

class _ChangePinViewState extends State<ChangePinView> {
  final _formKey = GlobalKey<FormState>();
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final storage = GetStorage();

  void _changePin() {
    if (_formKey.currentState!.validate()) {
      final storedPin = storage.read('pin');
      if (_oldPinController.text != storedPin) {
        Get.snackbar(
          "Invalid",
          "Old PIN is incorrect",
          backgroundColor: Colors.red[600],
          colorText: Colors.white,
        );
        return;
      }

      if (_newPinController.text != _confirmPinController.text) {
        Get.snackbar(
          "Mismatch",
          "New PINs do not match",
          backgroundColor: Colors.red[600],
          colorText: Colors.white,
        );
        return;
      }

      storage.write('pin', _newPinController.text);
      Get.snackbar(
        "Success",
        "PIN changed successfully",
        backgroundColor: Colors.green[600],
        colorText: Colors.white,
      );

      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Transaction PIN"),
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
                "Change your 4-digit PIN used for sending payments.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _oldPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: "Current PIN",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.length != 4 ? 'PIN must be 4 digits' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: "New PIN",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.length != 4 ? 'PIN must be 4 digits' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: "Confirm New PIN",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.length != 4 ? 'PIN must be 4 digits' : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _changePin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: osvanGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 60,
                    vertical: 14,
                  ),
                ),
                child: const Text(
                  "Update PIN",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
