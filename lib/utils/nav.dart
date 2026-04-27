import 'package:get/get.dart';
import 'package:osvan_app/routes/app_routes.dart';

void safeBack({dynamic result}) {
  if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
    Get.back(result: result);
    return;
  }

  final canPop = Get.key.currentState?.canPop() ?? false;
  if (canPop) {
    Get.back(result: result);
    return;
  }

  final route = Get.currentRoute;
  const authRoutes = {
    AppRoutes.welcome,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
    AppRoutes.resetPassword,
    AppRoutes.verifyEmail,
  };

  if (authRoutes.contains(route)) {
    Get.offAllNamed(AppRoutes.welcome);
    return;
  }

  Get.offAllNamed(AppRoutes.main);
}
