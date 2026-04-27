// lib/screen/cards/register_card_user_view.dart
// Updated to match Dashboard luxury UI 100% (same theme + background + glass cards)
//
// ✅ Behavior kept:
// - Prefills from /api/user/me (best effort) + optional initial map
// - Locks fields we already have (email/first/last/phone)
// - Hides/masks identity summary by default (Show/Hide toggle)
// - Enforces BVN when country is NG
// - Uploads user photo via gallery/camera (uploads to cards KYC + uses URL)
// - Sticky bottom submit bar
//
// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/routes/app_routes.dart';
import 'package:osvan_app/screen/cards/services/card_service.dart';
import 'package:osvan_app/services/api/api_paths_cards.dart';
import 'package:osvan_app/services/api_client.dart';
import 'package:osvan_app/utils/nav.dart';

class RegisterCardUserView extends StatefulWidget {
  /// Optional prefill (e.g., from /api/user/me or previous form)
  /// Keys supported:
  /// customerEmail, firstName, lastName, phoneNumber, idType, idNumber,
  /// city, state, country, zipCode, line1, houseName, idImage, bvn,
  /// dateOfBirth (YYYY-MM-DD)
  final Map<String, String>? initial;

  const RegisterCardUserView({super.key, this.initial});

  @override
  State<RegisterCardUserView> createState() => _RegisterCardUserViewState();
}

class _RegisterCardUserViewState extends State<RegisterCardUserView> {
  final _formKey = GlobalKey<FormState>();

  // -- Controllers
  final _customerEmail = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _idType = TextEditingController(); // BVN | NIN | PASSPORT | ...
  final _idNumber = TextEditingController();

  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zipCode = TextEditingController();
  final _line1 = TextEditingController();
  final _houseName = TextEditingController();

  final _bvn = TextEditingController(); // If NG, required
  final _idImage =
      TextEditingController(); // Required URL (mirrors uploaded photo)
  final _userPhoto = TextEditingController(); // picked label only
  final _dateOfBirth = TextEditingController(); // YYYY-MM-DD

  final _picker = ImagePicker();
  String? _userPhotoPayload; // uploaded HTTPS URL for user photo

  // Country (ISO2)
  String _countryIso2 = 'NG';
  final List<Map<String, String>> _countries = const [
    {'label': 'Nigeria', 'code': 'NG'},
    {'label': 'Ghana', 'code': 'GH'},
    {'label': 'Kenya', 'code': 'KE'},
    {'label': 'Uganda', 'code': 'UG'},
    {'label': 'United States', 'code': 'US'},
    {'label': 'United Kingdom', 'code': 'GB'},
    {'label': 'United Arab Emirates', 'code': 'AE'},
    {'label': 'Singapore', 'code': 'SG'},
    {'label': 'China', 'code': 'CN'},
    {'label': 'Hong Kong', 'code': 'HK'},
    {'label': 'South Africa', 'code': 'ZA'},
    {'label': 'Other (enter ISO2 manually)', 'code': 'OTHER'},
  ];
  final List<String> _ngIdTypes = const [
    'NIN',
    'PASSPORT',
    'DRIVERS_LICENSE',
    'PVC'
  ];
  final _otherCountry = TextEditingController(); // when OTHER is selected

  bool _submitting = false;
  bool _uploadingPhoto = false;

  // Lock user-known fields (professional UX)
  bool _lockEmail = false;
  bool _lockFirst = false;
  bool _lockLast = false;
  bool _lockPhone = false;

  bool _hideIdentity = true; // mask by default

  String _normalizePhone(String raw, String countryIso2) {
    var p = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (countryIso2 == 'NG') {
      if (p.startsWith('+234')) return p;
      if (p.startsWith('234')) return '+$p';
      if (p.startsWith('0') && p.length == 11) {
        return '+234${p.substring(1)}';
      }
    }
    return p;
  }

  String _cleanDigits(String v) => v.replaceAll(RegExp(r'[^0-9]'), '');

  bool _isValidBvn(String v) => RegExp(r'^\d{11}$').hasMatch(_cleanDigits(v));

  // ────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Prefill from /api/user/me (best effort)
    _prefillFromMe();

    // Prefill from optional initial map
    void setIf(String key, TextEditingController c) {
      final v = widget.initial?[key];
      if (v != null && v.trim().isNotEmpty) c.text = v.trim();
    }

    setIf('customerEmail', _customerEmail);
    setIf('firstName', _firstName);
    setIf('lastName', _lastName);
    setIf('phoneNumber', _phoneNumber);
    setIf('idType', _idType);
    setIf('idNumber', _idNumber);
    setIf('city', _city);
    setIf('state', _state);
    setIf('zipCode', _zipCode);
    setIf('line1', _line1);
    setIf('houseName', _houseName);
    setIf('bvn', _bvn);
    setIf('idImage', _idImage);
    setIf('userPhoto', _userPhoto);
    setIf('dateOfBirth', _dateOfBirth);

    final initPhoto = widget.initial?['userPhoto']?.trim();
    if (initPhoto != null && initPhoto.isNotEmpty) {
      _userPhotoPayload = initPhoto;
      if (_idImage.text.trim().isEmpty) _idImage.text = initPhoto;
    }

    final initCountry = widget.initial?['country']?.trim();
    if (initCountry != null && initCountry.isNotEmpty) {
      final iso = _toISO2(initCountry);
      if (_countries.any((c) => c['code'] == iso)) {
        _countryIso2 = iso;
      } else {
        _countryIso2 = 'OTHER';
        _otherCountry.text = iso;
      }
    }
  }

  @override
  void dispose() {
    _customerEmail.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phoneNumber.dispose();
    _idType.dispose();
    _idNumber.dispose();
    _city.dispose();
    _state.dispose();
    _zipCode.dispose();
    _line1.dispose();
    _houseName.dispose();
    _bvn.dispose();
    _idImage.dispose();
    _userPhoto.dispose();
    _dateOfBirth.dispose();
    _otherCountry.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Validators
  // ────────────────────────────────────────────────────────────────────────────
  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _emailV(String? v) {
    if (_req(v) != null) return 'Required';
    final s = v!.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Invalid email';
  }

  String? _dobV(String? v) {
    if (_req(v) != null) return 'Required';
    final s = v!.trim();
    final ok = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s);
    return ok ? null : 'Use YYYY-MM-DD';
  }

  String? _iso2V(String? v) {
    final s = (v ?? '').trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(s)) return 'Provide a valid ISO2 code';
    return null;
  }

  String _maskEmail(String email) {
    if (email.trim().isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name.substring(0, 2)}***@$domain';
  }

  String _maskPhone(String phone) {
    final s = phone.replaceAll(RegExp(r'\s+'), '');
    if (s.length <= 4) return '***';
    return '***${s.substring(s.length - 4)}';
  }

  // Accept names or ISO2, return ISO2 (fallback 'NG' if unknown)
  String _toISO2(String v) {
    final x = v.trim().toUpperCase();
    switch (x) {
      case 'NIGERIA':
      case 'NG':
        return 'NG';
      case 'GHANA':
      case 'GH':
        return 'GH';
      case 'KENYA':
      case 'KE':
        return 'KE';
      case 'UGANDA':
      case 'UG':
        return 'UG';
      case 'UNITED STATES':
      case 'USA':
      case 'US':
        return 'US';
      case 'UNITED KINGDOM':
      case 'UK':
      case 'GB':
        return 'GB';
      case 'UNITED ARAB EMIRATES':
      case 'UAE':
      case 'AE':
        return 'AE';
      case 'SINGAPORE':
      case 'SG':
        return 'SG';
      case 'CHINA':
      case 'CN':
        return 'CN';
      case 'HONG KONG':
      case 'HK':
        return 'HK';
      case 'SOUTH AFRICA':
      case 'ZA':
        return 'ZA';
      default:
        return x.length == 2 ? x : 'NG';
    }
  }

  Future<List<int>> _compressToBytes(XFile file) async {
    final path = File(file.path).absolute.path;
    final bytes = await FlutterImageCompress.compressWithFile(
      path,
      quality: 70,
      minWidth: 512,
      minHeight: 512,
      format: CompressFormat.jpeg,
    );

    if (bytes == null) throw Exception('Could not compress image');

    if (bytes.length > 450000) {
      throw Exception(
        'Image too large after compression. Pick a smaller photo.',
      );
    }

    return bytes;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 25, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 10),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(primary: osvanGreen),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    final yyyy = picked.year.toString().padLeft(4, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    _dateOfBirth.text = '$yyyy-$mm-$dd';
    setState(() {});
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Submit
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final iso2 =
        _countryIso2 == 'OTHER' ? _toISO2(_otherCountry.text) : _countryIso2;
    final photoPayload = (_userPhotoPayload ?? '').trim();

    // Enforce BVN for NG
    debugPrint(
        '[BVN] raw="${_bvn.text}" cleaned="${_cleanDigits(_bvn.text)}" len=${_cleanDigits(_bvn.text).length}');
    if (iso2 == 'NG' && _bvn.text.trim().isEmpty) {
      Get.snackbar(
        'BVN required',
        'Please enter a valid BVN for Nigeria',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (iso2 == 'NG' && !_isValidBvn(_bvn.text)) {
      Get.snackbar(
        'Invalid BVN',
        'BVN must be 11 digits.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Must have user photo payload
    if (photoPayload.isEmpty) {
      Get.snackbar(
        'User photo',
        'Please upload or capture a clear face photo.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (photoPayload.startsWith('data:image')) {
      Get.snackbar(
        'User photo',
        'Photo must be uploaded (URL), not inline base64.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      debugPrint('[CardKYC] POST ${ApiPathsCards.registerUser}');
      final photoUrl = photoPayload;
      final idImageUrl =
          photoUrl; // provider requires idImage; mirror userPhoto
      final payload = <String, dynamic>{
        'customerEmail': _customerEmail.text.trim(),
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'phoneNumber': _normalizePhone(_phoneNumber.text, iso2),
        'idType': _idType.text.trim(),
        'idNumber': _idNumber.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'country': iso2,
        'zipCode': _zipCode.text.trim(),
        'line1': _line1.text.trim(),
        'houseName': _houseName.text.trim(),
        'idImage': idImageUrl,
        'bvn': _cleanDigits(_bvn.text),
        'userPhoto': photoPayload, // ALWAYS send payload
        'dateOfBirth': _dateOfBirth.text.trim(),
      };

      await CardService.registerCardUser(payload);
      await CardService.setCardUserRegistered(true);

      Get.snackbar(
        'Success',
        'Card KYC submitted',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(milliseconds: 900),
      );

      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 250));

      // Return to Cards and refresh list/flags
      Get.offAllNamed(AppRoutes.cards, arguments: {'refresh': true});
    } catch (e) {
      final msg = _extractErr(e);
      Get.snackbar(
        'Registration failed',
        msg.isNotEmpty ? msg : 'Registration failed. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 6),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _extractErr(dynamic e) {
    try {
      if (e is dio.DioException) {
        final data = e.response?.data;
        if (data is Map) {
          final m = data['message'] ?? data['detail'] ?? data['error'];
          if (m is List) return m.join(', ');
          return (m ?? data['errors'] ?? 'Request failed').toString();
        }
        return e.message ?? 'Request failed';
      }
      if (e is Map) {
        final m = e['message'] ?? e['detail'] ?? e['error'] ?? e['errors'];
        if (m is List) return m.join(', ');
        return (m ?? 'Failed').toString();
      }
      return e.toString();
    } catch (_) {
      return 'Failed';
    }
  }

  Future<void> _prefillFromMe() async {
    try {
      final api = await ApiClient.ensureInitialized();
      final me = await api.getMe();

      final email = (me['email'] ?? '').toString().trim();
      final first =
          (me['first_name'] ?? me['firstName'] ?? '').toString().trim();
      final last = (me['last_name'] ?? me['lastName'] ?? '').toString().trim();
      final phone = (me['phone'] ??
              me['phone_number'] ??
              me['phoneNumber'] ??
              me['mobile'] ??
              '')
          .toString()
          .trim();

      if (!mounted) return;

      setState(() {
        if (email.isNotEmpty) {
          _customerEmail.text = email;
          _lockEmail = true;
        }
        if (first.isNotEmpty) {
          _firstName.text = first;
          _lockFirst = true;
        }
        if (last.isNotEmpty) {
          _lastName.text = last;
          _lockLast = true;
        }
        if (phone.isNotEmpty) {
          _phoneNumber.text = phone;
          _lockPhone = true;
        }
      });
    } catch (_) {
      // best-effort; keep fields editable if fetch fails
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return;

      if (!mounted) return;
      setState(() {
        _uploadingPhoto = true;
        _userPhoto.text =
            '${source == ImageSource.camera ? 'Captured' : 'Selected'}: ${file.name}';
      });

      final bytes = await _compressToBytes(file);
      final uploadUrl = await CardService.uploadCardKycPhoto(
        bytes,
        filename: file.name.isNotEmpty ? file.name : 'photo.jpg',
      );

      if (!mounted) return;
      setState(() {
        _userPhotoPayload = uploadUrl;
        if (_idImage.text.trim().isEmpty) _idImage.text = uploadUrl;
        _uploadingPhoto = false;
      });

      Get.snackbar(
        'Uploaded',
        'Photo uploaded successfully.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(milliseconds: 1200),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      Get.snackbar(
        'Photo',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // UI helpers (Dashboard style)
  // ────────────────────────────────────────────────────────────────────────────
  InputDecoration _dx(BuildContext context, String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFF0F1524),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: osvanGreen, width: 1.7),
      ),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.78)),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Single-mode: Premium Dark Theme wrapper (same approach as Dashboard)
    final dark = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF070B14),
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: osvanGreen,
        secondary: osvanGreen,
      ),
    );

    final emailText = _customerEmail.text.trim();
    final phoneText = _phoneNumber.text.trim();
    final firstText = _firstName.text.trim();
    final lastText = _lastName.text.trim();
    final fullName = ('$firstText $lastText').trim();
    final hasAnyIdentity =
        emailText.isNotEmpty || phoneText.isNotEmpty || fullName.isNotEmpty;
    final isNg = _countryIso2 == 'NG';
    String? ngIdValue;
    if (isNg) {
      final current = _idType.text.trim().toUpperCase();
      ngIdValue = _ngIdTypes.contains(current) ? current : _ngIdTypes.first;
      if (_idType.text.trim().toUpperCase() != ngIdValue) {
        _idType.text = ngIdValue;
      }
    }

    return Theme(
      data: dark,
      child: Scaffold(
        backgroundColor: const Color(0xFF070B14),
        body: Stack(
          children: [
            const _LuxuryBackground(),

            // App bar (custom, matches dashboard vibe)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => safeBack(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Register Card User',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            AbsorbPointer(
              absorbing: _submitting || _uploadingPhoto,
              child: Padding(
                padding: const EdgeInsets.only(top: 64),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                    children: [
                      if (_submitting)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const LinearProgressIndicator(minHeight: 2),
                        ),
                      const SizedBox(height: 14),

                      SectionCard(
                        title: 'Card KYC',
                        subtitle:
                            'Provide accurate details to unlock virtual card requests.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _Bullet(
                              text:
                                  'Use your legal name and a reachable phone number.',
                            ),
                            SizedBox(height: 6),
                            _Bullet(
                              text:
                                  'Upload clear ID and user photo for verification.',
                            ),
                            SizedBox(height: 6),
                            _Bullet(
                                text: 'Nigeria: BVN is required for approval.'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Identity
                      SectionCard(
                        title: 'Identity & Contact',
                        subtitle: 'Tell us who you are',
                        child: Column(
                          children: [
                            if (hasAnyIdentity) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B1220),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.10),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.verified_user_outlined,
                                          size: 18,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Account Details',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => setState(
                                            () =>
                                                _hideIdentity = !_hideIdentity,
                                          ),
                                          child: Text(
                                            _hideIdentity ? 'Show' : 'Hide',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (fullName.isNotEmpty)
                                      Text(
                                        'Name: ${_hideIdentity ? '***' : fullName}',
                                      ),
                                    if (emailText.isNotEmpty)
                                      Text(
                                        'Email: ${_hideIdentity ? _maskEmail(emailText) : emailText}',
                                      ),
                                    if (phoneText.isNotEmpty)
                                      Text(
                                        'Phone: ${_hideIdentity ? _maskPhone(phoneText) : phoneText}',
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _customerEmail,
                              decoration: _dx(
                                context,
                                'Email',
                                hint: 'name@example.com',
                              ),
                              readOnly: _lockEmail,
                              validator: _emailV,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstName,
                                    decoration: _dx(context, 'First Name'),
                                    validator: _req,
                                    readOnly: _lockFirst,
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastName,
                                    decoration: _dx(context, 'Last Name'),
                                    validator: _req,
                                    readOnly: _lockLast,
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneNumber,
                              decoration: _dx(
                                context,
                                'Phone Number',
                                hint: '+2348012345678',
                              ),
                              readOnly: _lockPhone,
                              validator: _req,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Government ID
                      SectionCard(
                        title: 'Government ID',
                        subtitle: 'We use this to verify your identity',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: isNg
                                      ? DropdownButtonFormField<String>(
                                          value: ngIdValue,
                                          decoration: _dx(
                                            context,
                                            'ID Type',
                                          ),
                                          isExpanded: true,
                                          items: _ngIdTypes
                                              .map(
                                                (t) => DropdownMenuItem(
                                                  value: t,
                                                  child: Text(
                                                    t,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          selectedItemBuilder: (context) {
                                            return _ngIdTypes
                                                .map(
                                                  (t) => Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: Text(
                                                      t,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList();
                                          },
                                          onChanged: (v) {
                                            if (v == null) return;
                                            setState(() => _idType.text = v);
                                          },
                                          validator: (v) => _req(v),
                                        )
                                      : TextFormField(
                                          controller: _idType,
                                          decoration: _dx(
                                            context,
                                            'ID Type',
                                            hint: 'NIN / PASSPORT',
                                          ),
                                          validator: _req,
                                          textInputAction: TextInputAction.next,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _idNumber,
                                    decoration: _dx(context, 'ID Number'),
                                    validator: _req,
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _idImage,
                              readOnly: true,
                              decoration: _dx(
                                context,
                                'ID Image (Required)',
                                hint: 'Auto-set from uploaded photo',
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Address
                      SectionCard(
                        title: 'Address',
                        subtitle: 'Your residential address',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _city,
                                    decoration: _dx(context, 'City'),
                                    validator: _req,
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _state,
                                    decoration: _dx(context, 'State/Region'),
                                    validator: _req,
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _countries
                                      .any((c) => c['code'] == _countryIso2)
                                  ? _countryIso2
                                  : 'OTHER',
                              decoration: _dx(context, 'Country (ISO2)'),
                              isExpanded: true,
                              dropdownColor: const Color(0xFF0F172A),
                              items: _countries
                                  .map(
                                    (c) => DropdownMenuItem<String>(
                                      value: c['code']!,
                                      child: Text(
                                        '${c['label']} (${c['code']})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _countryIso2 = v ?? 'NG'),
                            ),
                            if (_countryIso2 == 'OTHER') ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _otherCountry,
                                decoration: _dx(
                                  context,
                                  'Enter ISO2 code manually',
                                  hint: 'e.g. DE',
                                ),
                                validator: (v) =>
                                    _countryIso2 == 'OTHER' ? _iso2V(v) : null,
                                textInputAction: TextInputAction.next,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _zipCode,
                                    decoration: _dx(context, 'Zip/Postal Code'),
                                    validator: _req,
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _line1,
                                    decoration: _dx(context, 'Address Line 1'),
                                    validator: _req,
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _houseName,
                              decoration: _dx(context, 'House Name / Number'),
                              validator: _req,
                              textInputAction: TextInputAction.next,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Media + DOB + BVN
                      SectionCard(
                        title: 'Verification Media & DOB',
                        subtitle: 'Final details to complete your KYC',
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _userPhoto,
                              readOnly: true,
                              decoration: _dx(
                                context,
                                'User Photo',
                                hint: 'Upload or capture a clear face photo',
                              ).copyWith(
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Pick from gallery',
                                      icon: const Icon(
                                          Icons.photo_library_outlined),
                                      onPressed: () =>
                                          _pickPhoto(ImageSource.gallery),
                                    ),
                                    IconButton(
                                      tooltip: 'Capture from camera',
                                      icon: const Icon(
                                          Icons.photo_camera_outlined),
                                      onPressed: () =>
                                          _pickPhoto(ImageSource.camera),
                                    ),
                                  ],
                                ),
                              ),
                              validator: (_) => (_userPhotoPayload == null ||
                                      _userPhotoPayload!.trim().isEmpty)
                                  ? 'Upload required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _dateOfBirth,
                              readOnly: true,
                              onTap: _pickDob,
                              decoration: _dx(
                                context,
                                'Date of Birth',
                              ).copyWith(
                                suffixIcon:
                                    const Icon(Icons.calendar_month_rounded),
                              ),
                              validator: _dobV,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _bvn,
                              decoration: _dx(context, 'BVN (Nigeria only)'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(11),
                              ],
                              onChanged: (v) {
                                final cleaned = _cleanDigits(v);
                                if (cleaned != v) {
                                  _bvn.value = _bvn.value.copyWith(
                                    text: cleaned,
                                    selection: TextSelection.collapsed(
                                        offset: cleaned.length),
                                  );
                                }
                              },
                              validator: (_) {
                                final iso2 = _countryIso2 == 'OTHER'
                                    ? _toISO2(_otherCountry.text)
                                    : _countryIso2;

                                if (iso2 != 'NG') return null;

                                final cleaned = _cleanDigits(_bvn.text);
                                if (cleaned.isEmpty) {
                                  return 'BVN is required for Nigeria';
                                }
                                if (!_isValidBvn(cleaned)) {
                                  return 'BVN must be 11 digits';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      SectionCard(
                        title: 'Notes',
                        child: Text(
                          '- Country must be ISO2 (e.g., NG, GH, US).\n'
                          '- Nigeria (NG): BVN is required.\n'
                          '- Date format must be YYYY-MM-DD.\n'
                          '- Selfie photo is uploaded and sent as URL (idImage defaults to it).',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withOpacity(0.72),
                                    height: 1.35,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky Submit Bar (dashboard dark)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.06)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.55),
                      blurRadius: 22,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: osvanGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _submitting ? null : _submit,
                      icon:
                          const Icon(Icons.verified_user, color: Colors.white),
                      label: Text(
                        _submitting ? 'Submitting...' : 'Register',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Dashboard-matching background + blobs
// ──────────────────────────────────────────────────────────────────────────────
class _LuxuryBackground extends StatelessWidget {
  const _LuxuryBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF070B14),
            Color(0xFF0B1220),
            Color(0xFF070B14),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -80,
            child: _GlowBlob(color: osvanGreen, size: 260, opacity: 0.12),
          ),
          Positioned(
            top: 140,
            right: -120,
            child: _GlowBlob(
              color: Colors.blueAccent,
              size: 260,
              opacity: 0.10,
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _GlowBlob(
              color: Colors.purpleAccent,
              size: 300,
              opacity: 0.08,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowBlob({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: size,
            height: size,
            color: color.withOpacity(opacity),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Dashboard-matching SectionCard (glass)
// ──────────────────────────────────────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final bool noPadding;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.noPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || subtitle != null) ...[
          Text(
            title ?? '',
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: t.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.70),
                height: 1.2,
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: noPadding
                  ? child
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: child,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.86),
                  height: 1.25,
                ),
          ),
        ),
      ],
    );
  }
}
