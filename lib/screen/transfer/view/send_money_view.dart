import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
import 'package:osvan_app/screen/transfer/view/transfer_receipt_view.dart';
import 'package:osvan_app/services/biometric_service.dart'; // ✅ Add this

class SendMoneyView extends StatefulWidget {
  const SendMoneyView({super.key});

  @override
  State<SendMoneyView> createState() => _SendMoneyViewState();
}

class _SendMoneyViewState extends State<SendMoneyView> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  String selectedCountry = 'Nigeria';
  String selectedMethod = 'Bank Transfer';
  String accountName = '';
  String accountNumber = '';
  String bankName = '';
  String mobileNumber = '';
  String fullName = '';
  String provider = '';
  String amount = '';

  final countries = [
    'Nigeria',
    'Kenya',
    'Ghana',
    'Uganda',
    'Tanzania',
    'Zambia',
    'Malawi',
    'Senegal',
    'Ivory Coast',
    'Cameroon',
    'Guinea',
    'Burkina Faso',
    'Mali',
    'Togo',
    'Benin',
    'Niger Republic',
    'United States',
    'United Kingdom',
    'France',
    'Spain',
    'Italy',
    'Australia',
    'Singapore',
    'UAE',
    'China',
    'DR Congo',
  ];

  final mobileMoneyCountries = {
    'Kenya',
    'Ghana',
    'Uganda',
    'Tanzania',
    'Zambia',
    'Malawi',
    'Senegal',
    'Ivory Coast',
    'Cameroon',
    'Guinea',
    'Burkina Faso',
    'Mali',
    'Togo',
    'Benin',
    'Niger Republic',
  };

  bool supportsBoth(String country) => mobileMoneyCountries.contains(country);

  void _showConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[500],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                'Confirm Transfer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Country: $selectedCountry',
                style: TextStyle(color: textColor),
              ),
              Text(
                'Method: $selectedMethod',
                style: TextStyle(color: textColor),
              ),
              if (selectedMethod == 'Mobile Money') ...[
                Text(
                  'Mobile Number: $mobileNumber',
                  style: TextStyle(color: textColor),
                ),
                Text(
                  'Full Name: $fullName',
                  style: TextStyle(color: textColor),
                ),
                Text('Provider: $provider', style: TextStyle(color: textColor)),
              ] else ...[
                Text(
                  'Account Number: $accountNumber',
                  style: TextStyle(color: textColor),
                ),
                Text(
                  'Account Name: $accountName',
                  style: TextStyle(color: textColor),
                ),
                Text(
                  'Bank Name: $bankName',
                  style: TextStyle(color: textColor),
                ),
              ],
              Text('Amount: $amount', style: TextStyle(color: textColor)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  Get.back(); // close sheet
                  Get.defaultDialog(
                    title: 'Authentication Required',
                    middleText: 'Choose how to authorize the transfer:',
                    backgroundColor: bgColor,
                    titleStyle: TextStyle(color: textColor),
                    middleTextStyle: TextStyle(color: textColor),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          Get.back();
                          bool authenticated =
                              await BiometricService.authenticateUser();
                          if (authenticated) {
                            _showPinEntry();
                          } else {
                            Get.snackbar(
                              'Blocked',
                              'Fingerprint authentication failed',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                          }
                        },
                        child: const Text('Use Fingerprint'),
                      ),
                      TextButton(
                        onPressed: () {
                          Get.back();
                          _showPinEntry();
                        },
                        child: const Text('Use PIN'),
                      ),
                    ],
                  );
                },
                child: const Text('Confirm'),
              ),
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.purple[300]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPinEntry() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    _otpController.clear();
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[500],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                'Enter 4-Digit PIN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  counterText: '',
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                ),
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_otpController.text == '1234') {
                    Get.back(); // close modal
                    final data = {
                      'country': selectedCountry,
                      'method': selectedMethod,
                      'amount': amount,
                      'accountNumber': accountNumber,
                      'accountName': accountName,
                      'bankName': bankName,
                      'mobileNumber': mobileNumber,
                      'fullName': fullName,
                      'provider': provider,
                    };
                    Get.off(() => TransferReceiptView(transferData: data));
                  } else {
                    Get.snackbar(
                      'Invalid PIN',
                      'Please try again.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Money'),
        backgroundColor: osvanGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: selectedCountry,
            decoration: const InputDecoration(labelText: 'Select Country'),
            items: countries.map((country) {
              return DropdownMenuItem(value: country, child: Text(country));
            }).toList(),
            onChanged: (val) {
              setState(() {
                selectedCountry = val!;
                selectedMethod = 'Bank Transfer';
              });
            },
          ),
          if (supportsBoth(selectedCountry)) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedMethod,
              decoration: const InputDecoration(
                labelText: 'Select Send Method',
              ),
              items: [
                'Bank Transfer',
                'Mobile Money',
              ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) => setState(() => selectedMethod = val!),
            ),
          ],
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (selectedMethod == 'Mobile Money') ...[
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                    ),
                    onChanged: (val) => mobileNumber = val,
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    onChanged: (val) => fullName = val,
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Provider'),
                    onChanged: (val) => provider = val,
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                  ),
                ] else ...[
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                    ),
                    onChanged: (val) => accountNumber = val,
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Account Name',
                    ),
                    onChanged: (val) => accountName = val,
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Bank Name'),
                    onChanged: (val) => bankName = val,
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => amount = val,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    final num? parsed = num.tryParse(val);
                    return parsed == null ? 'Enter a valid number' : null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _showConfirmation();
                    }
                  },
                  child: const Text("Continue"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
