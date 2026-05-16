import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:osvan_app/controller/theme_controller.dart';
import 'package:osvan_app/main.dart';
import 'package:osvan_app/routes/app_routes.dart';
import 'package:osvan_app/screen/dashboard/widgets/wallet_balance_section.dart';
import 'package:osvan_app/screen/wallet/controllers/wallets_controller.dart';
import 'package:osvan_app/screen/wallet/models/wallet.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('app boots to welcome screen', (WidgetTester tester) async {
    Get.put<ThemeController>(ThemeController());

    await tester.pumpWidget(const MyApp(initialRoute: AppRoutes.welcome));
    await tester.pump();

    expect(find.text('Send & receive\nwith confidence'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('wallet card renders a loaded primary balance', (tester) async {
    Get.put<WalletsController>(_TestWalletsController(), permanent: true);
    final wc = Get.find<WalletsController>();
    wc.wallets.assignAll(const [
      Wallet(id: 1, currencyCode: 'NGN', balance: 1250),
      Wallet(id: 2, currencyCode: 'USD', balance: 10),
    ]);
    wc.primaryCurrency.value = 'NGN';
    wc.primaryBalance.value = 1250;
    wc.primaryBalanceText.value = '1250.00';

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: WalletBalanceSection()),
      ),
    );
    await tester.pump();

    expect(find.text('Wallet Balance'), findsOneWidget);
    expect(find.text('₦1250.00'), findsOneWidget);
    expect(find.textContaining('not found', findRichText: true), findsNothing);
  });

  test('review-facing route table excludes unfinished pay bills route', () {
    final names = AppRoutes.pages.map((page) => page.name).toSet();

    expect(names, contains(AppRoutes.send));
    expect(names, contains(AppRoutes.createCard));
    expect(names, isNot(contains('/pay-bills')));
  });
}

class _TestWalletsController extends WalletsController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> load({bool silent = false}) async {}

  @override
  Future<void> startAutoRefresh({
    Duration? interval,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {}
}
