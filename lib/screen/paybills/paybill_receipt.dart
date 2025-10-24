// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showPayBillReceipt({
  required String biller,
  required String category,
  required String reference,
  required String amount,
  required String phone,
}) {
  final timestamp = DateTime.now();
  final formattedDate =
      "${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";

  final context = Get.context!;
  final theme = Theme.of(context);

  Get.bottomSheet(
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.dialogBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Payment Receipt',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text('Reference: $reference', style: theme.textTheme.bodyMedium),
          Text('Date: $formattedDate', style: theme.textTheme.bodyMedium),
          Text('Category: $category', style: theme.textTheme.bodyMedium),
          Text('Biller: $biller', style: theme.textTheme.bodyMedium),
          Text('Amount: ₦$amount', style: theme.textTheme.bodyMedium),
          Text('Phone: $phone', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.share),
              label: const Text('Share Receipt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
