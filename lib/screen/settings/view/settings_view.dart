import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../controller/theme_controller.dart'; // ✅ Added
import '../../../core/colors.dart';
import '../../../services/biometric_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool isVerified = true;
  final storage = GetStorage();
  final phoneController = TextEditingController(text: "+2347012345678");
  final emailController = TextEditingController(text: "user@example.com");
  final addressController = TextEditingController();

  void openChangePinPage() {
    Get.toNamed('/change-pin');
  }

  void openSetPinPage() {
    Get.toNamed('/set-pin');
  }

  void openChangePasswordPage() {
    Get.toNamed('/change-password');
  }

  void openTransactionLimitPage() {
    Get.toNamed('/transaction-limit');
  }

  void openCloseAccountPage() {
    Get.toNamed('/close-account');
  }

  void uploadUserImage() {
    Get.snackbar("Upload", "Image upload flow not implemented yet");
  }

  void handleLogout() {
    Get.defaultDialog(
      title: 'Logout',
      middleText: 'Are you sure you want to log out?',
      textConfirm: 'Yes',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      onConfirm: () {
        storage.erase();
        Get.offAllNamed("/login");
      },
    );
  }

  Future<void> _handleBiometricAuth() async {
    bool success = await BiometricService.authenticateUser();
    if (success) {
      Get.snackbar(
        "Authenticated",
        "Biometric authentication successful",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        "Failed",
        "Authentication failed or canceled",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  bool get hasPin => storage.read('pin') != null;

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: osvanGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey,
                      backgroundImage: AssetImage(
                        'assets/images/profile_placeholder.png',
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: uploadUserImage,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: osvanGreen,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(5),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "John Doe",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isVerified ? "Verified User" : "Unverified",
                      style: TextStyle(
                        color: isVerified ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),

            const Text(
              "Profile",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "Phone Number"),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email Address"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: "Residential Address",
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Get.snackbar(
                "Upload",
                "Upload document flow not implemented yet",
              ),
              icon: const Icon(Icons.upload_file),
              label: const Text("Upload Supporting Document"),
              style: ElevatedButton.styleFrom(backgroundColor: osvanGreen),
            ),

            const Divider(height: 40),
            const Text(
              "Security",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            if (!hasPin)
              ListTile(
                leading: const Icon(Icons.lock_open),
                title: const Text("Set PIN"),
                trailing: const Icon(Icons.chevron_right),
                onTap: openSetPinPage,
              ),

            if (hasPin)
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text("Change PIN"),
                trailing: const Icon(Icons.chevron_right),
                onTap: openChangePinPage,
              ),

            ListTile(
              leading: const Icon(Icons.password),
              title: const Text("Change Password"),
              trailing: const Icon(Icons.chevron_right),
              onTap: openChangePasswordPage,
            ),

            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text("Transaction Limit"),
              trailing: const Icon(Icons.chevron_right),
              onTap: openTransactionLimitPage,
            ),

            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text("Close Account"),
              trailing: const Icon(Icons.chevron_right),
              onTap: openCloseAccountPage,
            ),

            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text("Login with Fingerprint"),
              trailing: const Icon(Icons.chevron_right),
              onTap: _handleBiometricAuth,
            ),

            // ✅ Theme toggle
            Obx(
              () => ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text("Dark Mode"),
                trailing: Switch(
                  value: themeController.isDarkMode,
                  onChanged: themeController.toggleTheme,
                ),
              ),
            ),

            const Divider(height: 40),
            const Text(
              "Support",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text("Contact Support"),
              onTap: () =>
                  Get.snackbar("Support", "Call or chat support coming soon"),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text("Privacy Policy"),
              onTap: () =>
                  Get.snackbar("Privacy", "Privacy Policy not available yet"),
            ),
            ListTile(
              leading: const Icon(Icons.article),
              title: const Text("Terms of Use"),
              onTap: () =>
                  Get.snackbar("Terms", "Terms of Use not available yet"),
            ),

            const SizedBox(height: 40),
            Center(
              child: ElevatedButton.icon(
                onPressed: handleLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text("Logout"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
