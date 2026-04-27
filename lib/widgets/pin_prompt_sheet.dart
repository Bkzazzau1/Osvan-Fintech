// lib/widgets/pin_prompt_sheet.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

typedef PinSubmit = Future<bool> Function(String pin);

class PinPromptSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final PinSubmit onSubmit;

  const PinPromptSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSubmit,
  });

  static Future<String?> show({
    required String title,
    required String subtitle,
    required PinSubmit onSubmit,
  }) async {
    return await Get.bottomSheet<String?>(
      PinPromptSheet(title: title, subtitle: subtitle, onSubmit: onSubmit),
      isScrollControlled: true,
      ignoreSafeArea: false,
      elevation: 2,
    );
  }

  @override
  State<PinPromptSheet> createState() => _PinPromptSheetState();
}

class _PinPromptSheetState extends State<PinPromptSheet> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await widget.onSubmit(_pinController.text.trim());
    if (ok) {
      if (mounted) Get.back(result: _pinController.text.trim());
    } else {
      setState(() {
        _error = "Invalid PIN or rejected";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Material(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(2))),
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(widget.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: "Transaction PIN",
                    counterText: "",
                  ),
                  validator: (v) {
                    final s = (v ?? "").trim();
                    if (s.length != 4) return "Enter 4-digit PIN";
                    if (!RegExp(r'^\d{4}$').hasMatch(s)) return "Digits only";
                    return null;
                  },
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Confirm"),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
