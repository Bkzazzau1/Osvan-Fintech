import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/routes/app_routes.dart';
import 'package:osvan_app/services/api_client.dart';

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

  // ────────────────────────────────────────────────────────────────────
  // Validators
  // ────────────────────────────────────────────────────────────────────
  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Invalid email';
  }

  String? _bvn(String? v) {
    final s = (v ?? '').trim();
    return (s.length == 11 && int.tryParse(s) != null)
        ? null
        : 'BVN must be 11 digits';
  }

  String? _phone(String? v) {
    final s = (v ?? '').trim();
    // allow leading + and spaces; 8–20 digits total tolerance
    final ok = RegExp(r'^[+\d][\d\s]{7,19}$').hasMatch(s);
    return ok ? null : 'Enter a valid phone number';
  }

  String? _dobIfProvidus(String? v) {
    if (bank.value != 'providus') return null; // only required for providus
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Date of birth is required for Providus';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return 'Use YYYY-MM-DD';
    // extra sanity (non-fatal if parse throws)
    try {
      DateTime.parse(s);
    } catch (_) {
      return 'Invalid date';
    }
    return null;
  }

  // ────────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────────
  Future<void> pickDob(BuildContext context) async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 25, now.month, now.day);
    final first = DateTime(now.year - 100, 1, 1);
    final last = DateTime(now.year - 16, now.month, now.day);
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

  String _generateRef() =>
      'OSV-VA-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 20)}';

  @override
  void onInit() {
    super.onInit();
    reference.text = _generateRef();
    _prefillFromUserMe(); // best-effort; silent on failure
  }

  // Prefill using /api/user/me/
  Future<void> _prefillFromUserMe() async {
    try {
      await ApiClient.ensureInitialized();
      final me = await ApiClient.shared.getMe();
      _applyMeMap(me);
    } catch (_) {/* silent */}
  }

  void _applyMeMap(dynamic me) {
    if (me is! Map) return;
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = me[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final fn = pick(['first_name', 'firstName', 'given_name', 'givenName']);
    final ln =
        pick(['last_name', 'lastName', 'surname', 'family_name', 'familyName']);
    final em = pick(['email', 'user_email']);
    final ph = pick(['phone', 'phone_number', 'mobile', 'msisdn']);

    if (firstName.text.isEmpty && fn.isNotEmpty) firstName.text = fn;
    if (lastName.text.isEmpty && ln.isNotEmpty) lastName.text = ln;
    if (customerEmail.text.isEmpty && em.isNotEmpty) customerEmail.text = em;
    if (phoneNumber.text.isEmpty && ph.isNotEmpty) phoneNumber.text = ph;
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    isSubmitting.value = true;
    errorText.value = null;

    try {
      final formPayload = <String, dynamic>{
        // Brails field names (exact)
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'bvn': bvn.text.trim(),
        'customerEmail': customerEmail.text.trim(),
        'reference': reference.text.trim(),
        'bank': bank.value, // 'safehaven' or 'providus'
        'phoneNumber': phoneNumber.text.trim(),
        if (bank.value == 'providus') 'dateOfBirth': dateOfBirth.text.trim(),
      };

      await ApiClient.ensureInitialized();
      final res =
          await ApiClient.shared.createVirtualAccount(payload: formPayload);

      if (res['ok'] == true) {
        // Detect inline mode from Add Money
        final inline =
            (Get.arguments is Map) && (Get.arguments['inline'] == true);

        if (inline) {
          // ✅ Inline: return true; Add Money will call loadVA()
          Get.back(result: true);
        } else {
          Get.snackbar(
            'Receiving Account',
            'Receiving account created successfully.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4),
          );
          Get.offAllNamed(AppRoutes.main);
        }
      } else {
        final msg =
            (res['message'] ?? 'Failed to create receiving account').toString();
        Get.snackbar('Receiving Account', msg,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4));
      }
    } catch (e) {
      errorText.value = e.toString();
      Get.snackbar('Receiving Account', errorText.value!,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4));
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
