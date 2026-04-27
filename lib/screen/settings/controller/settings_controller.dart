import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../api/security/security_api.dart';
import '../../../services/api/core_client.dart';
import '../../../services/api/profile_api.dart';

class SettingsController extends GetxController {
  final _storage = GetStorage();

  final isLoading = false.obs;
  final error = ''.obs;

  /// Raw /api/user/me/ payload (schema-safe)
  final me = Rxn<Map<String, dynamic>>();

  /// Derived (UI-friendly)
  final fullName = ''.obs;
  final email = ''.obs;
  final phone = ''.obs;
  final address = ''.obs;
  final countryCode = ''.obs;
  final addressLine1 = ''.obs;
  final addressLine2 = ''.obs;
  final city = ''.obs;
  final state = ''.obs;
  final postalCode = ''.obs;
  final kycStatus = ''.obs;
  final docUploadInProgress = false.obs;
  final saving = false.obs;

  /// Verification (best-effort from payload)
  final isVerified = false.obs;

  /// PIN presence (best-effort, since no status endpoint shared)
  final hasPin = false.obs;
  final avatarUrl = ''.obs;
  final isUploadingAvatar = false.obs;

  bool _boolFrom(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == 'true' || s == '1' || s == 'yes' || s == 'verified';
    }
    return false;
  }

  String _pickString(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  void _applyMe(Map<String, dynamic> m) {
    final fn = _pickString(m, ['full_name', 'fullName', 'name']);
    final first = _pickString(m, ['first_name', 'firstName']);
    final last = _pickString(m, ['last_name', 'lastName', 'surname']);
    countryCode.value = _pickString(m, ['country', 'country_code', 'countryCode']);
    addressLine1.value = _pickString(m, ['address_line1', 'addressLine1', 'address', 'residential_address']);
    addressLine2.value = _pickString(m, ['address_line2', 'addressLine2', 'address2']);
    city.value = _pickString(m, ['city']);
    state.value = _pickString(m, ['state', 'region']);
    postalCode.value = _pickString(m, ['postal_code', 'postalCode', 'zip']);
    kycStatus.value = _pickString(m, ['kyc_status', 'kycStatus', 'status']);

    final computedName = fn.isNotEmpty
        ? fn
        : ([first, last].where((e) => e.isNotEmpty).join(' ').trim());

    fullName.value = computedName.isNotEmpty ? computedName : '—';

    email.value = _pickString(m, ['email']);
    phone.value =
        _pickString(m, ['phone', 'phone_number', 'phoneNumber', 'mobile']);
    final addrCombined = [
      addressLine1.value,
      addressLine2.value,
    ].where((e) => e.trim().isNotEmpty).join(', ');
    address.value = addrCombined.isNotEmpty
        ? addrCombined
        : _pickString(
            m, ['address', 'residential_address', 'residentialAddress']);

    avatarUrl.value = _pickString(m, [
      'avatar',
      'photo',
      'image',
      'profile_image',
      'profileImage',
      'profilePhoto',
      'picture',
    ]);

    // verification flags (schema-safe)
    isVerified.value = _boolFrom(
      m['is_verified'] ??
          m['verified'] ??
          m['kyc_verified'] ??
          m['kycVerified'] ??
          m['bvn_verified'] ??
          m['bvnVerified'] ??
          m['nin_verified'] ??
          m['ninVerified'] ??
          m['email_verified'] ??
          m['emailVerified'],
    );
    if (!isVerified.value) {
      final status = kycStatus.value.toLowerCase();
      if (status == 'approved' || status == 'verified' || status == 'active') {
        isVerified.value = true;
      }
    }

    // hasPin (best effort): use server field if exists, else local storage
    hasPin.value = _boolFrom(m['has_pin'] ?? m['hasPin']) ||
        _storage.read('has_pin') == true ||
        (_storage.read('pin') != null); // legacy fallback

    // Set raw payload last so listeners see fully populated derived fields
    me.value = m;
  }

  Future<bool> uploadAvatar(String filePath) async {
    if (isUploadingAvatar.value) return false;
    isUploadingAvatar.value = true;
    error.value = '';

    try {
      await ProfileApi.ensureInitialized();

      await ProfileApi.I.uploadKycDoc(
        documentType: 'SELFIE',
        file: File(filePath),
      );

      // refresh profile (best effort)
      await loadProfile(silent: true);

      return true;
    } on ProfileApiError catch (e) {
      error.value = e.message;
      return false;
    } catch (_) {
      error.value = 'Failed to upload photo';
      return false;
    } finally {
      isUploadingAvatar.value = false;
    }
  }

  /// Pick and upload a supporting document (image from camera/gallery).
  Future<bool> uploadSupportingDocument(ImageSource source) async {
    if (docUploadInProgress.value) return false;
    docUploadInProgress.value = true;
    error.value = '';
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (picked == null) {
        docUploadInProgress.value = false;
        return false;
      }

      await ProfileApi.ensureInitialized();
      await ProfileApi.I.uploadKycDoc(
        documentType: 'OTHER',
        file: File(picked.path),
      );

      await loadProfile(silent: true);
      return true;
    } on ProfileApiError catch (e) {
      error.value = e.message;
      return false;
    } catch (_) {
      error.value = 'Failed to upload document';
      return false;
    } finally {
      docUploadInProgress.value = false;
    }
  }

  Future<void> loadPinStatus() async {
    try {
      await CoreClient.ensure();
      final api = SecurityApi(dio: CoreClient.I.dio);
      hasPin.value = await api.hasPin();
    } catch (_) {
      // Fall back to allowing Set PIN if the status endpoint fails.
      hasPin.value = false;
    }
  }

  Future<void> loadProfile({bool silent = false}) async {
    if (!silent) {
      isLoading.value = true;
      error.value = '';
    }

    try {
      await ProfileApi.ensureInitialized();
      final prof = await ProfileApi.I.getProfile();
      _applyMe(Map<String, dynamic>.from(prof));
    } on ProfileApiError catch (e) {
      error.value = e.message;
      Get.snackbar('Error', e.message,
          backgroundColor: Colors.red, colorText: Colors.white);
    } catch (_) {
      error.value = 'Failed to load profile';
      Get.snackbar('Error', 'Failed to load profile',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
      await loadPinStatus();
    }
  }

  Future<void> saveProfile() async {
    saving.value = true;
    error.value = '';
    try {
      await ProfileApi.ensureInitialized();
      await ProfileApi.I.updateProfile({
        'phone': phone.value.trim(),
        'country': countryCode.value.trim(),
        'address_line1': addressLine1.value.trim(),
        'address_line2': addressLine2.value.trim(),
        'city': city.value.trim(),
        'state': state.value.trim(),
        'postal_code': postalCode.value.trim(),
      });
      Get.snackbar('Saved', 'Profile updated',
          backgroundColor: Colors.black87, colorText: Colors.white);
      await loadProfile(silent: true);
    } on ProfileApiError catch (e) {
      error.value = e.message;
      Get.snackbar('Error', e.message,
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      saving.value = false;
    }
  }

  /// Back-compat alias for existing call-sites.
  Future<void> loadMe({bool silent = false}) => loadProfile(silent: silent);

  @override
  void onInit() {
    super.onInit();
    loadProfile(silent: false);
  }

  void logout() {
    _storage.erase();
    Get.offAllNamed('/login');
  }
}
