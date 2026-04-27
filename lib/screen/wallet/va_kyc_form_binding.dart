// lib/screen/wallet/va_kyc_form_binding.dart
import 'package:get/get.dart';

import 'controllers/va_kyc_form_controller.dart';

class VAKycFormBinding extends Bindings {
  @override
  void dependencies() {
    // Lazy with fenix: if disposed by GetX, it will be recreated on next find()
    Get.lazyPut<VAKycFormController>(() => VAKycFormController(), fenix: true);
  }
}
