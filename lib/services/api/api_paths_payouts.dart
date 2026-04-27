// lib/services/api/api_paths_payouts.dart

class ApiPathsPayoutExt {
  // ✅ Correct endpoint name (now under /api)
  static const String payoutSupportedCountries =
      '/api/payout/supported-countries/';

  static String payoutRequirementsFor(String country) =>
      '/api/payout/requirements/$country/';

  static String payoutBanksFor(String country, String currency) =>
      '/api/payout/banks/$country/$currency/';

  static const String transactions = '/api/transactions/';

  // Beneficiaries
  static const String payoutBeneficiaries = '/api/payout/beneficiaries/';
  static String payoutBeneficiaryDetail(String id) =>
      '/api/payout/beneficiaries/$id/';

  // Payout Flow
  static const String payoutInit = '/api/payout/init/';
  static const String payoutFinalize = '/api/payout/finalize/';
  static String payoutAttachDocumentFor(String txId) =>
      '/api/payout/$txId/attach-document/';
}
