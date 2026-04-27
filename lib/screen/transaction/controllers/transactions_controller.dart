import 'package:get/get.dart';

import '../models/transaction.dart';
import '../services/transactions_service.dart';

class TransactionsController extends GetxController {
  final items = <Txn>[].obs;

  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final isLoadingMore = false.obs;
  final error = RxnString();

  int _page = 1;
  final int _pageSize = 20;
  bool _hasMore = true;

  @override
  void onInit() {
    super.onInit();
    load(reset: true);
  }

  Future<void> refreshNow() => load(reset: true);

  Future<void> load({bool reset = false}) async {
    final wasEmptyBefore = items.isEmpty;

    if (reset) {
      _page = 1;
      _hasMore = true;
      items.clear();
    }
    if (!_hasMore) return;

    // ✅ FIX: first load should show full-screen loader, not "refreshing"
    if (reset) {
      error.value = null;
      if (wasEmptyBefore) {
        isLoading.value = true;
      } else {
        isRefreshing.value = true;
      }
    } else if (items.isEmpty) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      final pageData = await TransactionsService.instance
          .fetchPage(page: _page, pageSize: _pageSize);

      items.addAll(pageData);

      _hasMore = pageData.length == _pageSize; // good enough for now
      if (_hasMore) _page += 1;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
      isLoadingMore.value = false;
    }
  }
}
