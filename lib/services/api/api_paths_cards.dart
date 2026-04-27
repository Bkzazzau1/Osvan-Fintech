/// Safer Cards endpoints (schema-first, one place).
library;

class ApiPathsCards {
  // Fixed
  static String get registerUser => '/api/cards/register-user/';
  static String get uploadPhoto => '/api/cards/kyc/upload-photo/';
  static String get list => '/api/cards/';
  static String get request => '/api/cards/request/';
  static String get withdrawSimple => '/api/cards/withdraw/';
  static String get transactionsAll => '/api/cards/transactions/';

  // Dynamic builders
  static String fetch(String cardId) => '/api/cards/$cardId/';
  static String freeze(String cardId) => '/api/cards/$cardId/freeze/';
  static String unfreeze(String cardId) => '/api/cards/$cardId/unfreeze/';
  static String terminate(String cardId) => '/api/cards/$cardId/terminate/';
  static String adminTerminate(String cardId) =>
      '/api/admin/cards/$cardId/terminate/';
  static String deduct(String pk) => '/api/cards/$pk/deduct/';
  static String withdraw(String cardId) => '/api/cards/$cardId/withdraw/';
  static String transactions(String cardId) =>
      '/api/cards/$cardId/transactions/';
  static String statementPdf(String cardId) =>
      '/api/cards/$cardId/statement.pdf';
}
