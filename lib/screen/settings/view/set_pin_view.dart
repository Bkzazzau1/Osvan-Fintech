import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/colors.dart';

class SetPinView extends StatefulWidget {
  const SetPinView({super.key});

  @override
  State<SetPinView> createState() => _SetPinViewState();
}

class _SetPinViewState extends State<SetPinView> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final storage = GetStorage();

  void _savePin() {
    if (_formKey.currentState!.validate()) {
      if (_pinController.text != _confirmPinController.text) {
        Get.snackbar(
          "Mismatch",
          "PINs do not match",
          backgroundColor: Colors.red[400],
          colorText: Colors.white,
        );
        return;
      }

      storage.write('pin', _pinController.text);
      Get.snackbar(
        "Success",
        "PIN set successfully",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set Transaction PIN"),
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
                "Set a 4-digit PIN to authorize transactions securely.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: "Enter 4-digit PIN",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.length != 4 ? 'PIN must be 4 digits' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: "Confirm PIN",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.length != 4 ? 'PIN must be 4 digits' : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _savePin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: osvanGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 60,
                    vertical: 14,
                  ),
                ),
                child: const Text(
                  "Save PIN",
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
