import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/screen/auth/forgot_password_view.dart';
import 'package:osvan_app/screen/auth/login_view.dart';
import 'package:osvan_app/screen/auth/register_view.dart';
import 'package:osvan_app/screen/auth/reset_password_view.dart';
// ✅ cards
import 'package:osvan_app/screen/cards/create_card_view.dart';
import 'package:osvan_app/screen/cards/view/cards_view.dart';
import 'package:osvan_app/screen/main_nav/main_nav_view.dart';
import 'package:osvan_app/screen/notifications/view/notifications_view.dart';
import 'package:osvan_app/screen/settings/view/change_password_view.dart';
import 'package:osvan_app/screen/settings/view/change_pin_view.dart';
import 'package:osvan_app/screen/settings/view/close_account_view.dart';
import 'package:osvan_app/screen/settings/view/set_pin_view.dart';
import 'package:osvan_app/screen/settings/view/transaction_limit_view.dart';
import 'package:osvan_app/screen/transaction/transaction_history_screen.dart';
import 'package:osvan_app/screen/transfer/view/transfer_receipt_view.dart';
import 'package:osvan_app/screen/wallet/services/config_service.dart';
import 'package:osvan_app/screen/welcome/view/welcome_view.dart';
// ✅ Control API (ensures service is present before card routes)


class AppRoutes {
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String main = '/main';
  static const String notifications = '/notifications';

  // Settings
  static const String setPin = '/set-pin';
  static const String changePin = '/change-pin';
  static const String changePassword = '/change-password';
  static const String transactionLimit = '/transaction-limit';
  static const String closeAccount = '/close-account';

  // Transfer
  static const String transferReceipt = '/transfer-receipt';

  // Wallet
  static const String transactionHistory = '/transaction-history';

  // ✅ Cards
  static const String cards = '/cards';
  static const String createCard = '/cards/create';

  static final List<GetPage> pages = [
    GetPage(name: welcome, page: () => const WelcomeView()),
    GetPage(name: login, page: () => const LoginView()),
    GetPage(name: register, page: () => const RegisterView()),
    GetPage(name: forgotPassword, page: () => const ForgotPasswordView()),
    GetPage(name: resetPassword, page: () => const ResetPasswordView()),
    GetPage(name: main, page: () => const MainNavView()),
    GetPage(name: notifications, page: () => const NotificationsView()),

    // Settings
    GetPage(name: setPin, page: () => const SetPinView()),
    GetPage(name: changePin, page: () => const ChangePinView()),
    GetPage(name: changePassword, page: () => const ChangePasswordView()),
    GetPage(name: transactionLimit, page: () => const TransactionLimitView()),
    GetPage(name: closeAccount, page: () => const CloseAccountView()),

    // Transfer
    GetPage(
      name: transferReceipt,
      page: () => const TransferReceiptView(transferData: {}),
    ),

    // Wallet
    GetPage(
        name: transactionHistory, page: () => const TransactionHistoryView()),

    // ✅ Cards (ensure Control API service is available)
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
  ];
}

/// Minimal guard to ensure ConfigService exists before entering guarded routes.
/// (ConfigService.init() is already called in main(); this is just a safety net.)
class EnsureConfigAvailable extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<ConfigService>()) {
      // Register a bare instance if somehow missing. We don't load here because
      // main() already did. Screens read current flags from the service.
      Get.put(ConfigService(), permanent: true);
    }
    return null;
  }
}
