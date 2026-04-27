/// Centralized API paths (exactly as your backend exposes them).
class ApiPaths {
  static const String base = 'https://fintech.osvan.africa';

  // ── Auth
  static const String tokenLogin = '/api/token/login/';
  static const String obtain =
      '/api/token/'; // keep (if any old flow still uses it)
  static const String refresh = '/api/token/refresh/';
  static const String resetPasswordRequest =
      '/api/auth/password/reset/request/';
  static const String resetPasswordConfirm =
      '/api/auth/password/reset/confirm/';
  static const String changePassword = '/api/auth/password/change/';
  static const String emailOtp = "/api/auth/email/otp/";
  static const String emailVerify = "/api/auth/email/verify/";

  // ── Health
  // Profile (existing backend)
  static const String profileMe = '/api/profile/me/';
  static const String profileUpdate = '/api/profile/update/';
  static const String profileLimits = '/api/profile/limits/';
  static const String profileCloseAccount =
      '/api/profile/close-account-request/';

  // KYC (new)
  static const String kycIdentifiers = '/api/profile/kyc/identifiers/';
  static const String kycDocumentUpload = '/api/profile/kyc/document/';

  // ÄÄ Health
  static const String health = '/api/health/';

  // ── User
  static const String userMe = '/api/user/me/';

  // ── Customers (✅ FIX: was being called as /v1/customers/ in logs; backend is /api/v1/customers/)
  static const String customers = '/api/v1/customers/';

  // ── Wallets
  static const String wallets = '/api/wallets/';
  static const String walletCreate = '/api/wallets/create/';

  // ── Virtual Accounts (extras)
  static const String virtualAccountList = '/api/wallets/virtual-accounts/';
  static const String virtualAccountTxPrefix =
      '/api/wallets/virtual-account'; // /<id>/transactions/
  static const String virtualAccountReconcile = '/api/v1/va/reconcile/';

  // ── Virtual Accounts
  static const String virtualAccount = '/api/wallets/virtual-account/';
  static const String virtualAccountMine = '/api/wallets/virtual-account/mine/';

  // ── Collections
  static const String collectionDetails = '/api/wallets/collection/';

  // ── Crypto (legacy + v1 wallets route for balances)
  static const String cryptoBalances =
      '/api/crypto/balances/'; // legacy (keep if still used)
  static const String cryptoBalancesV1Wallets =
      '/api/v1/wallets/crypto-balances'; // working curl path
  static const String cryptoAddress = '/api/crypto/address/';
  static const String cryptoTxs = '/api/crypto/transactions/';

  // ── Transfers (fiat façade if any + crypto)
  static const String cryptoTransfer = '/api/transfer/crypto/';
  static const String transferEstimate = '/api/transfer/estimate/';
  static const String transferSend = '/api/transfer/send/';

  // ── Test console / add money
  static const String addMoney = '/api/wallets/add-money/';

  // ── Payouts (bank/mobile money) ✅ FIX: add /api prefix to match backend
  static const String payoutSupportedCountries = '/api/payout/countries/';
  static const String payoutRequirements =
      '/api/payout/requirements/'; // you append <CC>/ in code
  static const String payoutBanks =
      '/api/payout/banks/'; // you use query params
  static const String payoutBeneficiaries = '/api/payout/beneficiaries/';
  static const String payoutInit = '/api/payout/init/';
  static const String payoutFinalize = '/api/payout/finalize/';
  static const String payoutAttachDocument =
      '/api/payout/attach/'; // if used; otherwise harmless

  // If you truly have /api/transactions/, set it here; otherwise leave as-is.
  // (Keeping name to avoid breaking imports; adjust later if needed.)
  static const String transactions = '/api/transactions/';

  // ── Conversion (new)
  static const String convertQuote =
      '/api/v1/convert/quote'; // no trailing slash (matches backend)
  static const String convertConfirm =
      '/api/v1/convert/confirm'; // no trailing slash (matches backend)

  // ── Security (PIN)
  static const String securitySetPin = '/api/security/pin/set/';
  static const String securityChangePin = '/api/security/pin/change/';
  static const String securityPinStatus =
      '/api/security/pin/status/'; // ✅ added
  static const String securityVerifyPin =
      '/api/security/pin/verify/'; // ✅ added

  // ── Payouts (TX status/history & docs) ✅ FIX: add /api prefix
  static const String payoutTxPrefix =
      '/api/payout/tx/'; // + <transactionId> + '/'
  static const String payoutHistory = '/api/payout/history/'; // ?limit=50
  static const String payoutTxDocumentPrefix =
      '/api/payout/transactions/'; // + <transactionId> + '/document/'

  // ÄÄ Notifications
  static const String notificationsRegister = '/notifications/device/register/';
  static const String notificationsUnregister =
      '/api/notifications/device/unregister/';
}
