import 'package:get/get.dart';
import 'package:osvan_app/api/security/security_api.dart';
import 'package:osvan_app/controller/security_controller.dart';
import 'package:osvan_app/services/api/core_client.dart';

class SecurityBinding extends Bindings {
  @override
  void dependencies() {
    // ✅ Always use the main authenticated Dio (has Authorization interceptor)
    final dio = CoreClient.I.dio;

    Get.lazyPut<SecurityApi>(() => SecurityApi(dio: dio));
    Get.put<SecurityController>(
      SecurityController(api: Get.find<SecurityApi>()),
    );
  }
}
