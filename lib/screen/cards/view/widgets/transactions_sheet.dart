// lib/screen/cards/widgets/transactions_sheet.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:osvan_app/screen/cards/services/card_service.dart';

class TransactionsSheet extends StatefulWidget {
  const TransactionsSheet({super.key, required this.cardId});
  final String cardId;

  @override
  State<TransactionsSheet> createState() => _TransactionsSheetState();
}

class _TransactionsSheetState extends State<TransactionsSheet> {
  final _txns = <Map<String, dynamic>>[].obs;
  final _loading = false.obs;
  final _hasMore = true.obs;
  int _page = 1;
  static const _take = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool paging = false}) async {
    if (_loading.value || (!_hasMore.value && paging)) return;
    _loading.value = true;
    try {
      final list = await CardService.getCardTransactions(
        widget.cardId,
        page: _page,
        take: _take,
      );
      if (list.isEmpty) {
        _hasMore.value = false;
      } else {
        _txns.addAll(list);
        if (list.length < _take) _hasMore.value = false;
        _page++;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load transactions: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM);
      _hasMore.value = false;
    } finally {
      _loading.value = false;
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollEndNotification &&
        n.metrics.extentAfter == 0 &&
        _hasMore.isTrue) {
      _load(paging: true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    String s(dynamic v) => (v ?? '').toString();
    String amt(Map<String, dynamic> m) =>
        s(m['amountFormatted'] ?? m['amount'] ?? '');
    String desc(Map<String, dynamic> m) => s(
          m['description'] ??
              m['narration'] ??
              m['merchant'] ??
              'Card transaction',
        );
    String time(Map<String, dynamic> m) =>
        s(m['createdAt'] ?? m['timestamp'] ?? m['date'] ?? '');

    return Obx(() {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Card Transactions",
                    style: th.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: "Load more",
                  onPressed: _hasMore.isTrue ? () => _load(paging: true) : null,
                  icon: const Icon(Icons.download_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (_txns.isEmpty && _loading.isTrue) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_txns.isEmpty && _hasMore.isFalse) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'No card transactions yet',
                        style: th.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.70),
                        ),
                      ),
                    ),
                  );
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _txns.length + (_hasMore.value ? 1 : 0),
                    separatorBuilder: (_, __) => Divider(
                        height: 14, color: Colors.white.withValues(alpha: 0.06)),
                    itemBuilder: (_, i) {
                      if (i == _txns.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: _loading.isTrue
                                ? const CircularProgressIndicator()
                                : TextButton(
                                    onPressed: () => _load(paging: true),
                                    child: const Text('Load More'),
                                  ),
                          ),
                        );
                      }

                      final m = _txns[i];
                      final negative =
                          s(m['direction']).toLowerCase() == 'debit' ||
                              s(m['type']).toLowerCase() == 'debit' ||
                              s(m['amount']).startsWith('-');

                      final tint = negative ? Colors.redAccent : Colors.green;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: tint.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                negative
                                    ? Icons.call_made_rounded
                                    : Icons.call_received_rounded,
                                color: tint,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(desc(m),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Text(
                                    time(m),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.65),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              amt(m),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: tint,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}
