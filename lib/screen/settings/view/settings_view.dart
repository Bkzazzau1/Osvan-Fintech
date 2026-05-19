// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../core/colors.dart';
import '../../../services/biometric_service.dart';
import '../controller/settings_controller.dart';

/// Luxury Dark constants (single mode look)
const kDarkBg = Color(0xFF070B14);
const kDarkSurface = Color(0xFF0F172A); // big cards
const kDarkSurface2 = Color(0xFF0B1220);

/// Luxury Ice-Blue accent
const kIceBlue = Color(0xFF60A5FA);

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final SettingsController c;
  final _picker = ImagePicker();

  // Editable fields
  final phoneController = TextEditingController();
  final addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    c = Get.put(SettingsController(), permanent: false);

    ever<Map<String, dynamic>?>(c.me, (m) {
      if (m == null) return;
      phoneController.text = c.phone.value;
      addressController.text = c.address.value;
    });
  }

  @override
  void dispose() {
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  // — Navigation hooks —
  void openChangePinPage() => Get.toNamed('/change-pin');
  void openSetPinPage() => Get.toNamed('/set-pin');
  void openChangePasswordPage() => Get.toNamed('/change-password');
  void openTransactionLimitPage() => Get.toNamed('/transaction-limit');
  void openCloseAccountPage() => Get.toNamed('/close-account');
  void openSupportEmail() => launchUrlString(
        'mailto:support@osvan.africa',
        mode: LaunchMode.externalApplication,
      );

  Future<void> uploadUserImage() async {
    if (c.isUploadingAvatar.value) return;
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final ok = await c.uploadAvatar(picked.path);
    if (ok) {
      Get.snackbar(
        "Updated",
        "Profile photo updated",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else if (c.error.value.isNotEmpty) {
      Get.snackbar(
        "Error",
        c.error.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _uploadDoc() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: kDarkSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Upload document',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded,
                        color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ListTile(
                leading:
                    const Icon(Icons.photo_library_rounded, color: kIceBlue),
                title: const Text('Choose from gallery',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text('PNG/JPG or document photo',
                    style: TextStyle(color: Colors.white.withOpacity(0.65))),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_camera_rounded, color: kIceBlue),
                title: const Text('Take a photo',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text('Use camera to capture the document',
                    style: TextStyle(color: Colors.white.withOpacity(0.65))),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final ok = await c.uploadSupportingDocument(source);
    if (ok) {
      Get.snackbar(
        "Uploaded",
        "Document uploaded successfully",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else if (c.error.value.isNotEmpty) {
      Get.snackbar(
        "Error",
        c.error.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showDoc(String title, String body) {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          height: Get.height * 0.75,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: kDarkSurface2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Share.share(body, subject: title),
                    icon: const Icon(Icons.ios_share_rounded,
                        color: Colors.white),
                    tooltip: 'Share',
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    body,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      height: 1.5,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void handleLogout() {
    Get.defaultDialog(
      title: 'Logout',
      middleText: 'Are you sure you want to log out?',
      textConfirm: 'Yes',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () => c.logout(),
    );
  }

  Future<void> _handleBiometricAuth() async {
    final ready = await BiometricService.isBiometricReady();
    if (!ready) {
      Get.snackbar(
        "Unavailable",
        "Fingerprint/Face ID is not set on this device. Please enable it in phone settings.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    final ok = await BiometricService.authenticateBiometric();
    Get.snackbar(
      ok ? "Authenticated" : "Failed",
      ok
          ? "Biometric authentication successful"
          : (BiometricService.lastErrorMessage ??
              "Authentication failed/cancelled"),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: ok ? Colors.green : Colors.red,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Single-mode premium dark (Settings page too)
    final dark = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kDarkBg,
      colorScheme:
          const ColorScheme.dark(primary: kIceBlue, secondary: kIceBlue),
    );

    return Theme(
      data: dark,
      child: Scaffold(
        backgroundColor: kDarkBg,
        body: Stack(
          children: [
            const _LuxuryBackground(),
            Obx(() {
              final loading = c.isLoading.value;
              final err = c.error.value.trim();

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        if (loading) ...[
                          const LinearProgressIndicator(minHeight: 2),
                          const SizedBox(height: 10),
                        ],
                        if (err.isNotEmpty) ...[
                          _ErrorBanner(
                            text: err,
                            onRetry: () => c.loadMe(silent: false),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Profile header
                        _GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Obx(() {
                                  final hasAvatar =
                                      c.avatarUrl.value.isNotEmpty;
                                  final img = hasAvatar
                                      ? NetworkImage(c.avatarUrl.value)
                                      : const AssetImage(
                                          'assets/images/profile_placeholder.png',
                                        ) as ImageProvider<Object>;

                                  return Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 36,
                                        backgroundImage: img,
                                        backgroundColor:
                                            Colors.white.withOpacity(0.06),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: InkWell(
                                          onTap: uploadUserImage,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: kIceBlue,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: kIceBlue
                                                      .withOpacity(0.35),
                                                  blurRadius: 14,
                                                ),
                                              ],
                                            ),
                                            padding: const EdgeInsets.all(6),
                                            child: c.isUploadingAvatar.value
                                                ? const SizedBox(
                                                    height: 14,
                                                    width: 14,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors.white),
                                                    ),
                                                  )
                                                : const Icon(Icons.edit_rounded,
                                                    size: 16,
                                                    color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.fullName.value.isEmpty
                                            ? '—'
                                            : c.fullName.value,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _pill(
                                            icon: Icons.alternate_email,
                                            text: c.email.value.isEmpty
                                                ? '—'
                                                : c.email.value,
                                          ),
                                          _statusPill(
                                              verified: c.isVerified.value),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Profile section
                        const _SectionTitle(title: 'Profile'),
                        _GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _DarkTextField(
                                  controller: phoneController,
                                  label: "Phone Number",
                                  icon: Icons.phone_outlined,
                                  readOnly: true,
                                ),
                                const SizedBox(height: 12),
                                _DarkTextField(
                                  controller: addressController,
                                  label: "Residential Address",
                                  icon: Icons.home_outlined,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _PrimaryButton(
                                        icon: Icons.save_outlined,
                                        label: "Save",
                                        onTap: () async {
                                          c.phone.value =
                                              phoneController.text.trim();
                                          c.addressLine1.value =
                                              addressController.text.trim();
                                          c.address.value =
                                              addressController.text.trim();
                                          await c.saveProfile();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _OutlineButton(
                                        icon: Icons.upload_file_rounded,
                                        label: "Upload Doc",
                                        onTap: _uploadDoc,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Security section
                        const _SectionTitle(title: 'Security'),
                        _GlassCard(
                          noPadding: true,
                          child: Column(
                            children: [
                              _luxTile(
                                icon: Icons.lock_open_rounded,
                                title: "Set PIN",
                                onTap: openSetPinPage,
                              ),
                              _divider(),
                              _luxTile(
                                icon: Icons.lock_rounded,
                                title: "Change PIN",
                                onTap: openChangePinPage,
                              ),
                              _divider(),
                              _luxTile(
                                icon: Icons.password_rounded,
                                title: "Change Password",
                                onTap: openChangePasswordPage,
                              ),
                              _divider(),
                              _luxTile(
                                icon: Icons.tune_rounded,
                                title: "Transaction Limit",
                                onTap: openTransactionLimitPage,
                              ),
                              _divider(),
                              _luxTile(
                                icon: Icons.delete_forever_rounded,
                                title: "Close Account",
                                onTap: openCloseAccountPage,
                                danger: true,
                              ),
                              _divider(),
                              _luxTile(
                                icon: Icons.fingerprint_rounded,
                                title: "Login with Fingerprint",
                                onTap: _handleBiometricAuth,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Support section
                        const _SectionTitle(title: 'Support'),
                        _GlassCard(
                          noPadding: true,
                          child: Column(
                            children: [
                              _luxTile(
                                icon: Icons.support_agent_rounded,
                                title: "Contact Support",
                                onTap: openSupportEmail,
                              ),
                              _divider(),
                              _luxTile(
                                icon: Icons.privacy_tip_rounded,
                                title: "Privacy Policy",
                                onTap: () =>
                                    _showDoc('Privacy Policy', _privacyText),
                              ),
                              _divider(),
                              _luxTile(
                                icon: Icons.article_rounded,
                                title: "Terms of Use",
                                onTap: () =>
                                    _showDoc('Terms of Use', _termsText),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Logout
                        _DangerButton(
                          icon: Icons.logout_rounded,
                          label: "Logout",
                          onTap: handleLogout,
                        ),

                        const SizedBox(height: 8),
                      ]),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // — UI helpers —
  static Widget _divider() => Divider(
        height: 1,
        thickness: 0.7,
        color: Colors.white.withOpacity(0.07),
      );

  static Widget _pill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.88)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statusPill({required bool verified}) {
    final bg = verified
        ? Colors.green.withOpacity(0.12)
        : Colors.red.withOpacity(0.12);
    final fg = verified ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verified ? Icons.verified_rounded : Icons.error_outline_rounded,
              size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            verified ? "Verified" : "Unverified",
            style: TextStyle(
                color: fg, fontWeight: FontWeight.w900, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  static Widget _luxTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final fg = danger ? Colors.red : Colors.white.withOpacity(0.92);
    final ic = danger ? Colors.red : kIceBlue;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ic.withOpacity(0.14),
          border: Border.all(color: ic.withOpacity(0.18)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: ic, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: Colors.white.withOpacity(0.45)),
      visualDensity: VisualDensity.compact,
      minLeadingWidth: 22,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool readOnly;
  final int maxLines;

  const _DarkTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.readOnly = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
        prefixIcon: Icon(icon, color: kIceBlue),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kIceBlue.withOpacity(0.55)),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final bool noPadding;

  const _GlassCard({required this.child, this.noPadding = false});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: kDarkSurface.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: kIceBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: kIceBlue),
      label: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: kIceBlue.withOpacity(0.40)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: kIceBlue.withOpacity(0.10),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DangerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _LuxuryBackground extends StatelessWidget {
  const _LuxuryBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kDarkBg, kDarkSurface2, kDarkBg],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -80,
            child: _GlowBlob(color: kIceBlue, size: 260, opacity: 0.10),
          ),
          Positioned(
            top: 160,
            right: -120,
            child: _GlowBlob(color: osvanGreen, size: 260, opacity: 0.07),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child:
                _GlowBlob(color: Colors.purpleAccent, size: 320, opacity: 0.07),
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

const String _privacyText = '''
OSVAN PRIVACY POLICY
Last updated: December 2025

Osvan respects your privacy and is committed to protecting your personal and financial data. This explains how we collect, use, store, and protect your information.

1. WHO WE ARE
Osvan is a fintech platform providing digital wallets, virtual cards, transfers, and bill payments. Osvan is not a bank. Financial services are provided through licensed partners.

2. INFORMATION WE COLLECT
- Personal information (name, email, phone, address)
- Identity verification data (BVN, NIN, Passport where required)
- Financial data (wallet balances, transactions)
- Technical data (device, IP, logs)
We do NOT store card CVV, PIN, or private keys.

3. HOW WE USE DATA
- Account creation and management
- Transaction processing
- Fraud prevention and compliance
- Notifications and alerts
- Legal obligations

4. TRANSACTION ALERTS
All transactions generate alerts. Critical actions trigger mandatory security notifications.

5. DATA SHARING
We only share data with regulated partners, payment processors, and legal authorities when required.

6. SECURITY
- HTTPS encryption
- Token authentication
- Access control
- Audit logging

7. DATA RETENTION
We retain data as required by financial laws even after account closure.

8. YOUR RIGHTS
You may request access, correction, or closure via privacy@osvan.africa
Contact: support@osvan.africa | legal@osvan.africa
''';

const String _termsText = '''
OSVAN TERMS OF USE
Last updated: December 2025

1. ELIGIBILITY
Users must be 18+ and provide accurate information.

2. ACCOUNT RESPONSIBILITY
You are responsible for your login credentials and activity.

3. TRANSACTIONS
Transactions may be irreversible. Fees and rates are shown before confirmation.

4. FINANCIAL SERVICES
Transactions may be subject to partner availability, compliance checks, and network processing times.

5. ACCOUNT FREEZE
Accounts may be frozen for fraud or compliance review.

6. PROHIBITED USE
Illegal activity, fraud, laundering, and sanctions violations are prohibited.

7. LIABILITY
Osvan is not liable for third-party service failures outside its reasonable control.

8. GOVERNING LAW
Governed by Nigerian law and applicable regulations.

Contact:
support@osvan.africa
legal@osvan.africa
''';
