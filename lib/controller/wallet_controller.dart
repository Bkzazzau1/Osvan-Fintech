// lib/controllers/wallet_controller.dart
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:osvan_app/controller/mixins/auth_guard.dart';
import 'package:osvan_app/services/api_client.dart';

class WalletController extends GetxController with AuthGuard {
  late final ApiClient api;
  final isBusy = false.obs;
  final wallets = <dynamic>[].obs;

  @override
  void onInit() {
    super.onInit();
    ApiClient.create().then((c) => api = c);
  }

  Future<void> loadWallets() async {
    await guard(() async {
      isBusy.value = true;
      try {
        final data = await api.listWallets();
        wallets.assignAll(data);
      } on DioException {
        rethrow;
      } finally {
        isBusy.value = false;
      }
      return null;
    }, onUnauthorized: () {
      // e.g., Get.offAllNamed('/login');
    });
  }
}
