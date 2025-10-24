import 'package:get/get.dart';

class DashboardController extends GetxController {
  // Reactive wallet balance
  var walletBalance = 0.00.obs;

  // Selected tab/index state
  var selectedIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchWalletBalance(); // Load balance on init
  }

  // Simulated API call to fetch wallet balance
  void fetchWalletBalance() {
    walletBalance.value = 15000.00; // Example balance
  }

  // Manual update of wallet balance
  void updateBalance(double newBalance) {
    walletBalance.value = newBalance;
  }

  // Navigation helpers
  void incrementIndex() {
    if (selectedIndex.value < 4) {
      selectedIndex.value++;
    }
  }

  void resetIndex() {
    selectedIndex.value = 0;
  }

  void changeTab(int index) {
    selectedIndex.value = index;
  }
}
