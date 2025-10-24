import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
// ignore: library_prefixes
import 'package:osvan_app/screen/wallet/services/config_service.dart';

import '../../../services/register_service.dart';


class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();

  final _surnameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController(); // readOnly text (yyyy-MM-dd)
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String _country = 'Nigeria';
  bool _saving = false;
  DateTime? _dob;

  final List<String> _countries = const [
    'Nigeria',
    'Ghana',
    'Kenya',
    'United States',
    'United Kingdom',
    'Others',
  ];

  @override
  void dispose() {
    _surnameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _dobCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    // reasonable adult range; adjust as needed
    final first = DateTime(now.year - 100, 1, 1);
    final last = DateTime(now.year - 16, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: first,
      lastDate: last,
      helpText: 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = _formatDate(picked);
      });
    }
  }

  String _formatDate(DateTime d) {
    // yyyy-MM-dd without extra deps
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String? _req(String? v, String label) {
    if (v == null || v.trim().isEmpty) return 'Enter $label';
    return null;
  }

  String? _emailValidator(String? v) {
    if (_req(v, 'email') != null) return 'Enter email';
    final s = v!.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  String? _passwordValidator(String? v) {
    if (_req(v, 'password') != null) return 'Enter password';
    if ((v ?? '').length < 6) return 'Minimum 6 characters';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      Get.snackbar('Date of Birth', 'Please select your date of birth',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      Get.snackbar('Password', 'Passwords do not match',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    setState(() => _saving = true);
    try {
      await RegisterService.register(
        email: _emailCtrl.text,
        surname: _surnameCtrl.text,
        firstName: _firstNameCtrl.text,
        middleName: _middleNameCtrl.text.isEmpty ? null : _middleNameCtrl.text,
        dateOfBirth: _dobCtrl.text, // yyyy-MM-dd
        phone: _phoneCtrl.text,
        country: _country,
        password: _passwordCtrl.text,
        address: _addressCtrl.text,
      );

      Get.snackbar('Success', 'Account created successfully. Please log in.',
          backgroundColor: Colors.green, colorText: Colors.white);

      // navigate: adjust to your route constant
      Get.offAllNamed('/login');
      // If you keep using main.dart routes alias, you could do:
      // Get.offAllNamed(AppRoutes.main as String);
    } on RegisterServiceError catch (e) {
      final msg = e.details ?? 'Registration failed';
      Get.snackbar('Error', msg,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5));
    } catch (_) {
      Get.snackbar('Error', 'Something went wrong. Try again.',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = 'API: ${ConfigService.baseUrl}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Country
              DropdownButtonFormField<String>(
                value: _country,
                items: _countries
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _country = val!),
                decoration: const InputDecoration(
                    labelText: 'Country', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              // Surname
              TextFormField(
                controller: _surnameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Surname (Last name)',
                    border: OutlineInputBorder()),
                validator: (v) => _req(v, 'surname'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // First name
              TextFormField(
                controller: _firstNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'First Name', border: OutlineInputBorder()),
                validator: (v) => _req(v, 'first name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Middle name (optional)
              TextFormField(
                controller: _middleNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Middle Name (optional)',
                    border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // DOB
              TextFormField(
                controller: _dobCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth (yyyy-MM-dd)',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _pickDob,
                validator: (v) => _req(v, 'date of birth'),
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]'))
                ],
                decoration: const InputDecoration(
                    labelText: 'Phone Number', border: OutlineInputBorder()),
                validator: (v) => _req(v, 'phone number'),
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
                validator: _emailValidator,
              ),
              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                    labelText: 'Residential Address',
                    border: OutlineInputBorder()),
                validator: (v) => _req(v, 'address'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password', border: OutlineInputBorder()),
                validator: _passwordValidator,
              ),
              const SizedBox(height: 16),

              // Confirm
              TextFormField(
                controller: _confirmPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder()),
                validator: (v) =>
                    v != _passwordCtrl.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Register',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(hint,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),

              const SizedBox(height: 16),
              TextButton(
                  onPressed: () => Get.toNamed('/login'),
                  child: const Text('Already have an account? Login')),
            ],
          ),
        ),
      ),
    );
  }
}
