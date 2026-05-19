// lib/routes/app_routes.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/config/env.dart'; // for CryptoView(baseUrl: ...)
import 'package:osvan_app/config/feature_flags.dart';
// Auth
import 'package:osvan_app/screen/auth/forgot_password_view.dart';
import 'package:osvan_app/screen/auth/login_view.dart';
import 'package:osvan_app/screen/auth/register_view.dart';
import 'package:osvan_app/screen/auth/reset_password_view.dart';
import 'package:osvan_app/screen/auth/verify_email_view.dart';
// Cards
import 'package:osvan_app/screen/cards/create_card_view.dart';
import 'package:osvan_app/screen/cards/register_card_user_view.dart'; // <-- KYC form
import 'package:osvan_app/screen/cards/view/cards_view.dart';
import 'package:osvan_app/screen/conversion/conversion_view.dart';
// Crypto
import 'package:osvan_app/screen/crypto/view/crypto_view.dart';
// Main shell / dashboard & misc
import 'package:osvan_app/screen/main_nav/main_nav_view.dart';
import 'package:osvan_app/screen/notifications/view/notifications_view.dart';
import 'package:osvan_app/screen/security/change_pin_view.dart' as pin_change;
// ✅ FIX (ONLY what we need now): alias imports for PIN screens (no prefix collision)
import 'package:osvan_app/screen/security/set_pin_view.dart' as pin_set;
// ✅ Real non-stub settings pages
import 'package:osvan_app/screen/settings/view/change_password_view.dart';
import 'package:osvan_app/screen/settings/view/close_account_view.dart';
import 'package:osvan_app/screen/settings/view/transaction_limit_view.dart';
import 'package:osvan_app/screen/transaction/transaction_history_screen.dart';
import 'package:osvan_app/screen/transaction/transaction_detail_view.dart';
// ✅ Transaction history screen

// Transfers binding
import 'package:osvan_app/screen/transfer/bindings/payout_wizard_binding.dart';
import 'package:osvan_app/screen/transfer/view/send_money_confirm_view.dart';
// Transfers & receipts (NEW split files)
import 'package:osvan_app/screen/transfer/view/send_money_destination_view.dart';
import 'package:osvan_app/screen/transfer/view/send_money_details_view.dart';
import 'package:osvan_app/screen/transfer/view/transfer_receipt_view.dart';
// Wallet module (services, views, bindings)
import 'package:osvan_app/screen/wallet/services/config_service.dart';
import 'package:osvan_app/screen/wallet/va_kyc_form_binding.dart';
import 'package:osvan_app/screen/wallet/view/add_money_view.dart';
import 'package:osvan_app/screen/wallet/view/va_kyc_form_view.dart';
// Welcome
import 'package:osvan_app/screen/welcome/view/welcome_view.dart';

class AppRoutes {
  // Core
  static const String welcome = '/welcome';
  static const String main = '/main'; // bottom-nav shell (Home/Cards/Settings)

  // Cards
  static const String cards = '/cards';
  static const String createCard = '/cards/create';
  static const String cardsRegisterUser = '/cards/register-user'; // <-- NEW

  static const String settings = '/settings'; // (tab inside main)

  // Features
  static const String notifications = '/notifications';
  static const String addMoney = '/add-money';
  static const String send = '/send';
  static const String crypto = '/crypto';
  static const String conversion = '/conversion';

  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String verifyEmail = '/verify-email';

  // Settings subpages
  static const String setPin = '/set-pin';
  static const String changePin = '/change-pin';
  static const String changePassword = '/change-password';
  static const String transactionLimit = '/transaction-limit';
  static const String closeAccount = '/close-account';

  // Transfers & history
  static const String transferReceipt = '/transfer-receipt';
  static const String transactionHistory = '/transaction-history';
  static const String transactionDetail = '/transaction-detail';

  // Virtual Account KYC
  static const String vaKyc = '/va-kyc';

  static final List<GetPage> pages = [
    GetPage(name: welcome, page: () => const WelcomeView()),

    // Auth
    GetPage(name: login, page: () => const LoginView()),
    GetPage(name: register, page: () => const RegisterView()),
    GetPage(name: forgotPassword, page: () => const ForgotPasswordView()),
    GetPage(name: resetPassword, page: () => const ResetPasswordView()),
    GetPage(name: verifyEmail, page: () => const VerifyEmailView()),

    // Shell
    GetPage(name: main, page: () => const MainNavView()),

    // Notifications
    GetPage(name: notifications, page: () => const NotificationsView()),

    // Wallet / Money
    GetPage(name: addMoney, page: () => const AddMoneyView()),
    GetPage(name: conversion, page: () => const ConversionView()),

    // ✅ Transaction history
    GetPage(
        name: transactionHistory, page: () => const TransactionHistoryView()),
    GetPage(name: transactionDetail, page: () => const TransactionDetailView()),

    // VA KYC with binding (ensures controller exists)
    GetPage(
      name: vaKyc,
      page: () => const VAKycFormView(),
      binding: VAKycFormBinding(),
    ),

    // Transfer (entry to wizard)
    GetPage(
      name: send,
      page: () => const SendMoneyDestinationView(),
      binding: PayoutWizardBinding(),
    ),
    GetPage(
      name: transferReceipt,
      page: () => const TransferReceiptView(transferData: {}),
    ),

    // Wizard inner steps (each guarded by same binding)
    GetPage(
      name: '/send/destination',
      page: () => const SendMoneyDestinationView(),
      binding: PayoutWizardBinding(),
    ),
    GetPage(
      name: '/send/details',
      page: () => const SendMoneyDetailsView(),
      binding: PayoutWizardBinding(),
    ),
    GetPage(
      name: '/send/confirm',
      page: () => const SendMoneyConfirmView(),
      binding: PayoutWizardBinding(),
    ),

    // Crypto is omitted from iOS UI builds for Apple review.
    if (FeatureFlags.cryptoUiEnabled)
      GetPage(
        name: crypto,
        page: () => CryptoView(baseUrl: Env.apiBaseUrl),
      ),

    // Cards (guarded to ensure ConfigService is present)
    GetPage(
      name: cards,
      page: () => const CardsView(),
      middlewares: [EnsureConfigAvailable()],
    ),
    GetPage(
      name: createCard,
      page: () => const CreateCardView(),
      middlewares: [EnsureConfigAvailable()],
    ),
    // NEW: Card KYC / Register User screen
    GetPage(
      name: cardsRegisterUser,
      page: () => const RegisterCardUserView(),
      middlewares: [EnsureConfigAvailable()],
    ),

    // ✅ Settings subpages
    // ✅ FIX: Use real Set/Change PIN screens (ONLY change we need now)
    GetPage(name: setPin, page: () => pin_set.SetPinView()),
    GetPage(name: changePin, page: () => pin_change.ChangePinView()),

    // Keep these as real views (already provided)
    GetPage(name: changePassword, page: () => const ChangePasswordView()),
    GetPage(name: transactionLimit, page: () => const TransactionLimitView()),
    GetPage(name: closeAccount, page: () => const CloseAccountView()),
  ];
}

class EnsureConfigAvailable extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<ConfigService>()) {
      Get.put(ConfigService(), permanent: true);
    }
    return null;
  }
}
