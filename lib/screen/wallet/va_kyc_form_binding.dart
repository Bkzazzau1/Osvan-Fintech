// lib/screen/wallet/va_kyc_form_binding.dart
import 'package:get/get.dart';

import 'controllers/va_kyc_form_controller.dart';

class VAKycFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(VAKycFormController());
  }
}
