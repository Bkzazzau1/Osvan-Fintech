// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/screen/paybills/paybill_receipt.dart';
import 'package:osvan_app/services/biometric_service.dart';

import '../../../core/colors.dart';

class PayBillsView extends StatefulWidget {
  const PayBillsView({super.key});

  @override
  State<PayBillsView> createState() => _PayBillsViewState();
}

class _PayBillsViewState extends State<PayBillsView> {
  String? selectedCountry;
  String? selectedCategory;
  String? selectedProvider;
  final detailController = TextEditingController();
  final amountController = TextEditingController();

  final List<String> africanCountries = [
    'Nigeria',
    'Ghana',
    'Kenya',
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
    'South Africa',
    'Egypt',
    'Morocco',
    'Rwanda',
    'Algeria',
    'Tunisia',
    'Ethiopia',
    'DR Congo',
  ];

  final Map<String, List<String>> billCategories = {
    'Nigeria': ['Airtime', 'Data', 'Electricity', 'Internet', 'TV'],
  };

  final Map<String, List<String>> providers = {
    'Airtime': ['MTN', 'Glo', 'Airtel', '9Mobile'],
    'Electricity': ['Ikeja Electric', 'EEDC', 'AEDC'],
    'Internet': ['Smile', 'Spectranet'],
    'TV': ['DStv', 'GOtv', 'Startimes'],
    'Data': ['MTN', 'Glo', 'Airtel', '9Mobile'],
  };

  void showConfirmationModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Confirm Payment",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text("Country: $selectedCountry"),
              Text("Category: $selectedCategory"),
              Text("Provider: $selectedProvider"),
              Text("Details: ${detailController.text}"),
              Text("Amount: ${amountController.text}"),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final authenticated =
                          await BiometricService.authenticateUser();

                      if (authenticated) {
                        Get.back(); // close modal
                        showPayBillReceipt(
                          biller: selectedProvider ?? '',
                          category: selectedCategory ?? '',
                          reference:
                              'PB${DateTime.now().millisecondsSinceEpoch}',
                          amount: amountController.text,
                          phone: detailController.text,
                        );
                      } else {
                        Get.snackbar(
                          'Failed',
                          'Biometric authentication failed',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: osvanGreen,
                    ),
                    child: const Text("Confirm"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNigeria = selectedCountry == 'Nigeria';
    final categoryList = isNigeria ? billCategories['Nigeria'] ?? [] : [];
    final providerList = selectedCategory != null
        ? providers[selectedCategory!] ?? []
        : [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Bills"),
        backgroundColor: osvanGreen,
        foregroundColor: Colors.white,
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Select Country"),
              value: selectedCountry,
              items: africanCountries
                  .map<DropdownMenuItem<String>>(
                    (country) => DropdownMenuItem<String>(
                      value: country,
                      child: Text(country),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() {
                selectedCountry = val;
                selectedCategory = null;
                selectedProvider = null;
                detailController.clear();
                amountController.clear();
              }),
            ),
            const SizedBox(height: 16),
            if (selectedCountry == null) const Text("Please select a country."),
            if (selectedCountry != null && !isNigeria)
              const Text(
                "Bill payment not available in this country. Coming soon.",
                style: TextStyle(color: Colors.red),
              ),
            if (isNigeria) ...[
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Bill Category"),
                value: selectedCategory,
                items: categoryList
                    .map<DropdownMenuItem<String>>(
                      (cat) => DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() {
                  selectedCategory = val;
                  selectedProvider = null;
                  detailController.clear();
                  amountController.clear();
                }),
              ),
              const SizedBox(height: 12),
              if (selectedCategory != null)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Provider"),
                  value: providerList.contains(selectedProvider)
                      ? selectedProvider
                      : null,
                  items: providerList
                      .map<DropdownMenuItem<String>>(
                        (prov) => DropdownMenuItem<String>(
                          value: prov,
                          child: Text(prov),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() {
                    selectedProvider = val;
                    detailController.clear();
                    amountController.clear();
                  }),
                ),
              const SizedBox(height: 12),
              if (selectedProvider != null)
                TextField(
                  controller: detailController,
                  decoration: InputDecoration(
                    labelText: selectedCategory == 'Airtime'
                        ? 'Phone Number'
                        : selectedCategory == 'Electricity'
                        ? 'Meter Number'
                        : selectedCategory == 'Internet'
                        ? 'Customer ID'
                        : 'Smart Card Number',
                  ),
                ),
              const SizedBox(height: 12),
              if (selectedProvider != null)
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
              const SizedBox(height: 20),
              if (selectedProvider != null)
                ElevatedButton.icon(
                  onPressed: () {
                    if (detailController.text.isEmpty ||
                        amountController.text.isEmpty) {
                      Get.snackbar("Error", "Please fill in all fields");
                      return;
                    }
                    showConfirmationModal();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: osvanGreen),
                  icon: const Icon(Icons.payment),
                  label: const Text("Proceed to Pay"),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
