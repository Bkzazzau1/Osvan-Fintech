import 'package:get/get.dart';
import 'package:osvan_app/config/env.dart'; // ✅ add this
import 'package:osvan_app/screen/auth/forgot_password_view.dart';
import 'package:osvan_app/screen/auth/login_view.dart';
import 'package:osvan_app/screen/auth/register_view.dart';
import 'package:osvan_app/screen/auth/reset_password_view.dart';
import 'package:osvan_app/screen/conversion/conversion_view.dart';
import 'package:osvan_app/screen/crypto/view/crypto_view.dart';
import 'package:osvan_app/screen/notifications/view/notifications_view.dart';
import 'package:osvan_app/screen/paybills/paybills_view.dart';
import 'package:osvan_app/screen/settings/view/change_password_view.dart';
import 'package:osvan_app/screen/settings/view/change_pin_view.dart';
import 'package:osvan_app/screen/settings/view/close_account_view.dart';
import 'package:osvan_app/screen/settings/view/set_pin_view.dart';
import 'package:osvan_app/screen/settings/view/transaction_limit_view.dart';
import 'package:osvan_app/screen/transfer/view/send_money_view.dart';
import 'package:osvan_app/screen/wallet/view/add_money_view.dart';
import 'package:osvan_app/screen/welcome/view/welcome_view.dart';

class AppRoutes {
  // Core routes
  static const String welcome = '/welcome';
  static const String dashboard = '/dashboard';
  static const String cards = '/cards';
  static const String settings = '/settings';

  // Feature routes
  static const String notifications = '/notifications';
  static const String addMoney = '/add-money';
  static const String send = '/send';
  static const String crypto = '/crypto';
  static const String payBills = '/pay-bills';
  static const String conversion = '/conversion';

  // Auth routes
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // Settings routes
  static const String setPin = '/set-pin';
  static const String changePin = '/change-pin';
  static const String changePassword = '/change-password';
  static const String transactionLimit = '/transaction-limit';
  static const String closeAccount = '/close-account';

  static final pages = [
    GetPage(name: welcome, page: () => const WelcomeView()),
    GetPage(name: notifications, page: () => const NotificationsView()),
    GetPage(name: addMoney, page: () => const AddMoneyView()),
    GetPage(name: send, page: () => const SendMoneyView()),
    GetPage(
      name: crypto,
      page: () => CryptoView(baseUrl: Env.apiBaseUrl), // ❌ no const here
    ),
    GetPage(name: payBills, page: () => const PayBillsView()),
    GetPage(name: conversion, page: () => const ConversionView()),
    GetPage(name: login, page: () => const LoginView()),
    GetPage(name: register, page: () => const RegisterView()),
    GetPage(name: forgotPassword, page: () => const ForgotPasswordView()),
    GetPage(name: resetPassword, page: () => const ResetPasswordView()),
    GetPage(name: setPin, page: () => const SetPinView()),
    GetPage(name: changePin, page: () => const ChangePinView()),
    GetPage(name: changePassword, page: () => const ChangePasswordView()),
    GetPage(name: transactionLimit, page: () => const TransactionLimitView()),
    GetPage(name: closeAccount, page: () => const CloseAccountView()),
  ];
}
