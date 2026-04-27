// lib/screen/transfer/controllers/payout/payout_base.dar

// Contracts shared by payout controller & mixins.

import 'package:get/get.dart';

abstract class PayoutWizardBase extends GetxController {
  // Loading / step
  RxBool get isLoading;
  RxInt get step;

  // Selections
  RxList<Map<String, String>> get countries; // [{code,name}]
  RxString get countryCode; // "NG"
  RxString get currency; // "NGN"
  RxString get destination; // BANK | MOBILEMONEY | SWIFT

  // Schema + lookups
  Rxn<Map<String, dynamic>> get requirement;
  RxList<Map<String, String>> get banks; // [{name,code,currency}]
  RxList<String> get methods;
  RxList<Map<String, dynamic>> get fields; // [{name/key,type,required,...}]

  // Form + amount
  RxMap<String, dynamic> get form;
  RxDouble get amountMajor;

  // Results
  RxnString get beneficiaryId;
  Rxn<Map<String, dynamic>> get initResponse;
  RxnString get transactionId;

  // Beneficiaries
  RxList<Map<String, dynamic>> get beneficiaries;
  Rxn<Map<String, dynamic>> get selectedBeneficiary;

  // Resolver state
  RxBool get resolvingName;
  RxnString get resolvedName;

  // Guards
  bool get canResolveAccount;
  bool get allowProceed;

  // Controller helpers (implemented in controller or via mixins)
  Future<void> loadCountries();
  Future<void> onSelectCountry(String iso2);
  Future<void> onSelectMethod(String method);

  // Core behaviors (implemented by mixins)
  Future<void> loadRequirement(); // schema fetch & method derivation
  void buildFieldsFor(String method); // build UI fields for method
  Future<void> loadBanksIfNeeded(); // BANK list (unless schema inlined)
  Future<void> loadBeneficiaries(); // list saved beneficiaries
  Future<void> resolveAccountName(); // NG/GH account name lookup

  // Build payout "destination" payload from current fields+form.
  // Concrete implementation is provided by PayoutBeneficiariesMixin.
  Map<String, dynamic> buildDestinationFromSchema();
}
