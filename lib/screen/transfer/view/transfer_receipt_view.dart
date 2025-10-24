// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; // ✅ For sharing

class TransferReceiptView extends StatelessWidget {
  final Map<String, dynamic> transferData;

  const TransferReceiptView({super.key, required this.transferData});

  String get _timestamp {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd hh:mm a').format(now);
  }

  String get _referenceId {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'TX-${timestamp.toString().substring(4)}';
  }

  void _shareReceipt() {
    final String details = '''
OSVAN TRANSFER RECEIPT

Reference ID: $_referenceId
Timestamp: $_timestamp

Country: ${transferData['country']}
Method: ${transferData['method']}
${transferData['method'] == 'Mobile Money' ? '''
Mobile Number: ${transferData['mobileNumber']}
Full Name: ${transferData['fullName']}
Provider: ${transferData['provider']}
''' : '''
Account Number: ${transferData['accountNumber']}
Account Name: ${transferData['accountName']}
Bank Name: ${transferData['bankName']}
'''}
Amount Sent: ${transferData['amount']}
''';

    Share.share(details);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transfer Receipt"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReceipt, // ✅ Share button
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Transfer Successful!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 30),
            Text("Reference ID: $_referenceId"),
            Text("Timestamp: $_timestamp"),
            const SizedBox(height: 20),
            Text("Country: ${transferData['country']}"),
            Text("Method: ${transferData['method']}"),
            if (transferData['method'] == 'Mobile Money') ...[
              Text("Mobile Number: ${transferData['mobileNumber']}"),
              Text("Full Name: ${transferData['fullName']}"),
              Text("Provider: ${transferData['provider']}"),
            ] else ...[
              Text("Account Number: ${transferData['accountNumber']}"),
              Text("Account Name: ${transferData['accountName']}"),
              Text("Bank Name: ${transferData['bankName']}"),
            ],
            Text("Amount Sent: ${transferData['amount']}"),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () => Get.offAllNamed('/dashboard'),
                child: const Text("Return to Dashboard"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
