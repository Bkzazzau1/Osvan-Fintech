// lib/screen/transfer/bindings/payout_wizard_binding.dart
import 'package:get/get.dart';
import 'package:osvan_app/screen/transfer/controllers/payout_wizard_controller.dart';

class PayoutWizardBinding extends Bindings {
  @override
  void dependencies() {
    // Keep ONE instance for the whole payout wizard flow
    Get.put<PayoutWizardController>(PayoutWizardController(), permanent: true);
  }
}
