import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/screen/wallet/services/wallets_service.dart';

class VAKycFormController extends GetxController {
  final formKey = GlobalKey<FormState>();

  // Fields required by Brails
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final bvn = TextEditingController(); // 11 digits
  final customerEmail = TextEditingController(); // email
  final phoneNumber = TextEditingController(); // digits
  final reference = TextEditingController(); // unique
  final dateOfBirth = TextEditingController(); // YYYY-MM-DD (only for providus)
  final bank = 'providus'.obs; // 'providus' | 'safehaven'

  final isSubmitting = false.obs;
  final errorText = RxnString();

  final _svc = WalletsService();

  // ---- validators ----
  String? _req(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  String? _email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Invalid email';
  }

  String? _bvn(String? v) {
    final s = (v ?? '').trim();
    if (s.length != 11 || int.tryParse(s) == null) {
      return 'BVN must be 11 digits';
    }
    return null;
  }

  String? _phone(String? v) {
    final s = (v ?? '').trim();
    if (s.length < 7 || s.length > 16 || int.tryParse(s) == null) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _dobIfProvidus(String? v) {
    if (bank.value != 'providus') return null; // only required for providus
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Date of birth is required for Providus';
    final parts = s.split('-');
    if (parts.length != 3) return 'Use YYYY-MM-DD';
    return null;
  }

  // ---- helpers ----
  Future<void> pickDob(BuildContext context) async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(now.year - 100);
    final last = DateTime(now.year - 16);
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (d != null) {
      dateOfBirth.text =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }

  // simple unique-ish reference if user doesn't edit
  String _generateRef() {
    final rnd = Random();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final salt = rnd.nextInt(1 << 31);
    return 'osvan-$ts-$salt';
  }

  @override
  void onInit() {
    super.onInit();
    reference.text = _generateRef();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    isSubmitting.value = true;
    errorText.value = null;

    try {
      final payload = <String, dynamic>{
        // Brails field names (exactly as required)
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'bvn': bvn.text.trim(),
        'customerEmail': customerEmail.text.trim(),
        'reference': reference.text.trim(),
        'bank': bank.value, // 'safehaven' or 'providus'
        'phoneNumber': phoneNumber.text.trim(),
        if (bank.value == 'providus') 'dateOfBirth': dateOfBirth.text.trim(),
      };

      final created = await _svc.createVirtualAccount(kyc: payload);

      // Return created VA object to the caller (AddMoney screen)
      Get.back(result: created);
    } catch (e) {
      errorText.value = e.toString();
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    firstName.dispose();
    lastName.dispose();
    bvn.dispose();
    customerEmail.dispose();
    phoneNumber.dispose();
    reference.dispose();
    dateOfBirth.dispose();
    super.onClose();
  }

  // expose validators to the view
  String? Function(String?) get vReq => _req;
  String? Function(String?) get vEmail => _email;
  String? Function(String?) get vBvn => _bvn;
  String? Function(String?) get vPhone => _phone;
  String? Function(String?) get vDobIfProvidus => _dobIfProvidus;
}
