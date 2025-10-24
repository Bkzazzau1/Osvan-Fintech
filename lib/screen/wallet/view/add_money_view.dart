// lib/screen/wallet/views/add_money_view.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:osvan_app/core/colors.dart';
// NGN VA (GetX)
import 'package:osvan_app/screen/wallet/controllers/add_money_controller.dart';
// KES/UGX Collections service
import 'package:osvan_app/screen/wallet/services/collections_service.dart';

class AddMoneyView extends StatefulWidget {
  const AddMoneyView({super.key});

  @override
  State<AddMoneyView> createState() => _AddMoneyViewState();
}

class _AddMoneyViewState extends State<AddMoneyView> {
  // Controllers/Services
  late final AddMoneyController addMoneyCtrl;
  late final CollectionsService collectionsSvc;

  // UI State
  String selectedCountry = 'Nigeria';
  String selectedMethod = 'Bank Transfer';

  Map<String, String> collectionDetails = {};
  bool isLoading = false;
  String? errorMessage;

  final ScrollController _scrollCtrl = ScrollController();

  // Countries displayed in the selector — now NG, KE, UG
  final countries = const [
    'Nigeria',
    'Kenya',
    'Uganda',
  ];

  // Countries where Mobile Money may be supported
  final mobileMoneyCountries = const {
    'Kenya',
    'Uganda',
  };

  bool supportsBoth(String country) => mobileMoneyCountries.contains(country);

  @override
  void initState() {
    super.initState();

    // Wire GetX controller locally
    addMoneyCtrl = Get.put(AddMoneyController(), tag: 'inline-add-money');
    addMoneyCtrl.selectedCurrency.value = 'NGN';
    // Back-compat method present via controller shim
    addMoneyCtrl.loadVA();

    // Collections service
    collectionsSvc = CollectionsService();

    _loadFundingDetails();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    Get.delete<AddMoneyController>(tag: 'inline-add-money', force: true);
    super.dispose();
  }

  Future<void> _loadFundingDetails() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      collectionDetails.clear();
    });

    try {
      if (selectedCountry == 'Nigeria') {
        // NGN handled by GetX card (VA) – nothing to fetch here.
        // VA refresh button exists above; pull-to-refresh will also call loadVA().
        errorMessage = null;
      } else if (selectedCountry == 'Kenya' || selectedCountry == 'Uganda') {
        await _fetchCollectionDetails(); // uses current selectedMethod
      } else {
        errorMessage = 'Funding for $selectedCountry is coming soon.';
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchCollectionDetails() async {
    try {
      final method = (selectedMethod == 'Mobile Money') ? 'momo' : 'bank';
      final data = await collectionsSvc.getDetails(
        country: selectedCountry,
        method: method,
      );

      // Defensive normalization: accept any dynamic map, stringify values
      collectionDetails = {
        for (final entry in data.entries)
          entry.key.toString(): (entry.value).toString(),
      };

      errorMessage = null;
    } catch (e) {
      collectionDetails = {};
      errorMessage = e.toString();
    }
    if (mounted) setState(() {});
  }

  List<Map<String, String>> getCountryFields() {
    // Nigeria shows VA via GetX card
    if (selectedCountry == 'Nigeria') {
      return const [
        {'label': 'Info', 'value': 'Use the Virtual Account (NGN) card above.'},
      ];
    }

    // KE/UG details from Collections API
    if ((selectedCountry == 'Kenya' || selectedCountry == 'Uganda') &&
        collectionDetails.isNotEmpty) {
      return collectionDetails.entries
          .map((e) => {'label': e.key, 'value': e.value})
          .toList();
    }

    if (errorMessage != null) {
      return [
        {'label': 'Info', 'value': errorMessage!},
      ];
    }

    return const [
      {'label': 'Account/Paybill', 'value': 'Coming Soon'},
      {'label': 'Reference', 'value': '---'},
      {'label': 'Provider', 'value': '---'},
    ];
  }

  Future<void> copyToClipboard(String label, String value) async {
    final v = (value).trim();
    if (v.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: v));
    if (!mounted) return;
    Get.snackbar('Copied', '$label copied',
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> _onPullToRefresh() async {
    // Refresh VA and collections in one gesture for a smooth UX
    final isNigeria = selectedCountry == 'Nigeria';
    final isKEorUG = selectedCountry == 'Kenya' || selectedCountry == 'Uganda';

    setState(() {
      errorMessage = null;
    });

    // Parallel-ish refresh; order is not critical
    if (isNigeria) {
      await addMoneyCtrl.loadVA();
    }
    if (isKEorUG) {
      await _fetchCollectionDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Money',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: osvanGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _onPullToRefresh,
        child: ListView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(16),
          children: [
            // --- Card funding (placeholder) ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? osvanGreen : osvanWhite.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💳 Add with Card (Coming Soon)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Only credit or prepaid dollar cards will be supported.',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? osvanGreen.withOpacity(0.8)
                          : Colors.grey.shade400,
                    ),
                    child: const Text('Coming Soon'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- NGN Virtual Account (GetX) ---
            Obx(() {
              final show = (selectedCountry == 'Nigeria');
              if (!show) return const SizedBox.shrink();

              final va = addMoneyCtrl.va.value;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Virtual Account (NGN)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (addMoneyCtrl.isLoadingVA.value)
                        const LinearProgressIndicator(),
                      if (addMoneyCtrl.vaError.value != null) ...[
                        Text(
                          addMoneyCtrl.vaError.value!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (va == null) ...[
                        const Text(
                          'Create your virtual account to fund NGN wallet via bank transfer.',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: addMoneyCtrl.createVA,
                              child: const Text('Get Virtual Account'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: addMoneyCtrl.loadVA,
                              child: const Text('Refresh'),
                            ),
                          ],
                        ),
                      ] else ...[
                        _kv('Bank',
                            '${va['bank_name'] ?? va['provider'] ?? '-'}'),
                        _kv('Account Name', '${va['account_name'] ?? '-'}'),
                        _kv('Account Number', '${va['account_number'] ?? '-'}'),
                        if ((va['bank_code'] ?? '').toString().isNotEmpty)
                          _kv('Bank Code', '${va['bank_code']}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: addMoneyCtrl.loadVA,
                              child: const Text('Refresh'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () {
                                final acct =
                                    (va['account_number'] ?? '').toString();
                                if (acct.isNotEmpty) {
                                  copyToClipboard('Account Number', acct);
                                }
                              },
                              child: const Text('Copy Account Number'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Send NGN to this account number. Your wallet will update automatically after deposit.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // --- Country selector (NG | KE | UG) ---
            DropdownButtonFormField<String>(
              value: selectedCountry,
              decoration: const InputDecoration(labelText: 'Select Country'),
              items: countries
                  .map((country) => DropdownMenuItem<String>(
                      value: country, child: Text(country)))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  selectedCountry = val;
                  // Reset method on country switch; KE/UG default to bank
                  selectedMethod = 'Bank Transfer';
                  collectionDetails.clear();
                  errorMessage = null;
                });
                _loadFundingDetails();
              },
            ),

            // --- Method selector (only where supported: KE/UG) ---
            if (supportsBoth(selectedCountry)) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                decoration:
                    const InputDecoration(labelText: 'Select Payment Method'),
                items: const ['Bank Transfer', 'Mobile Money']
                    .map((method) => DropdownMenuItem<String>(
                        value: method, child: Text(method)))
                    .toList(),
                onChanged: (val) async {
                  if (val == null) return;
                  setState(() => selectedMethod = val);
                  if (selectedCountry == 'Kenya' ||
                      selectedCountry == 'Uganda') {
                    await _fetchCollectionDetails();
                  }
                },
              ),
            ],

            const SizedBox(height: 24),

            // --- Details box (KE/UG collections; NG shows info note) ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? osvanGreen : osvanGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (selectedCountry == 'Kenya' ||
                                  selectedCountry == 'Uganda')
                              ? (selectedMethod == 'Mobile Money'
                                  ? 'Mobile Money Details'
                                  : 'Bank Transfer Details')
                              : 'Funding Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...getCountryFields().map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item['label']}: ${item['value']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.copy,
                                    size: 18,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  onPressed: () => copyToClipboard(
                                    item['label'] ?? 'Field',
                                    item['value'] ?? '',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (selectedCountry == 'Nigeria')
                          const Text(
                            'Use the Virtual Account (NGN) card above.',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Flexible(child: Text(v, textAlign: TextAlign.right)),
        ],
      ),
    );
