// lib/screen/transfer/view/transfer_receipt_view.dart
// BANK-STYLE RECEIPT (simple + professional) — logic unchanged
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:osvan_app/routes/app_routes.dart';
import 'package:osvan_app/services/api/core_client.dart';
import 'package:osvan_app/services/api/payouts_api.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const kDarkBg = Color(0xFF070B14);
const kPaperDark = Color(0xFF0F172A);
const kPaperBorder = Color(0xFF1F2A44);
const kReceiptPaper = Color(0xFFF8FAFC);
const kReceiptInk = Color(0xFF0F172A);
const kReceiptMuted = Color(0xFF64748B);

class TransferReceiptView extends StatefulWidget {
  final Map<String, dynamic> transferData;

  const TransferReceiptView({super.key, required this.transferData});

  @override
  State<TransferReceiptView> createState() => _TransferReceiptViewState();
}

class _TransferReceiptViewState extends State<TransferReceiptView> {
  Timer? _timer;
  bool _loading = false;
  final GlobalKey _captureKey = GlobalKey();
  String? _fetchError;

  // live tx data from /api/payout/tx/<id>/
  Map<String, dynamic>? _tx;

  String get _txId =>
      (widget.transferData['transactionId'] ?? '').toString().trim();

  String get _method =>
      (widget.transferData['method'] ?? '').toString().toUpperCase().trim();

  String get _status {
    final live =
        (_tx?['status'] ?? _tx?['data']?['status'] ?? '').toString().trim();
    if (live.isNotEmpty) return live.toUpperCase();

    final passed = (widget.transferData['status'] ?? '').toString().trim();
    if (passed.isNotEmpty) return passed.toUpperCase();

    return 'PENDING';
  }

  bool get _isTerminal =>
      _status == 'SUCCESS' || _status == 'FAILED' || _status == 'REVERSED';

  String get _reference {
    final live = (_tx?['reference'] ?? _tx?['data']?['reference'] ?? '')
        .toString()
        .trim();
    if (live.isNotEmpty) return live;

    final passed = (widget.transferData['reference'] ?? '').toString().trim();
    if (passed.isNotEmpty) return passed;

    return _txId.isNotEmpty ? _txId : 'N/A';
  }

  String get _timestamp {
    final updatedAt = (_tx?['updatedAt'] ?? _tx?['data']?['updatedAt'] ?? '')
        .toString()
        .trim();
    if (updatedAt.isNotEmpty) {
      final dt = DateTime.tryParse(updatedAt);
      if (dt != null) {
        return DateFormat('yyyy-MM-dd hh:mm a').format(dt.toLocal());
      }
    }
    return DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now());
  }

  String get _country =>
      (widget.transferData['country'] ?? '').toString().trim();
  String get _currency =>
      (widget.transferData['currency'] ?? '').toString().trim();
  String get _amount => (widget.transferData['amount'] ?? '').toString().trim();

  String get _beneficiary {
    final v = (widget.transferData['beneficiary'] ?? '').toString().trim();
    return v.isEmpty ? '—' : v;
  }

  String get _providerOrBank {
    final candidates = [
      widget.transferData['bankName'],
      widget.transferData['providerName'],
      widget.transferData['bank'],
      widget.transferData['provider'],
      widget.transferData['providerOrBank'],
    ];
    final v = candidates
        .map((e) => (e ?? '').toString().trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    return v.isEmpty ? '-' : v;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _fetchTxOnce();
      _startPollingIfNeeded();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPollingIfNeeded() {
    if (_txId.isEmpty) return;
    if (_isTerminal) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _fetchTxOnce();
      if (!mounted) return;
      if (_isTerminal) _timer?.cancel();
    });
  }

  Future<void> _fetchTxOnce() async {
    if (_txId.isEmpty) return;
    if (_loading) return;

    setState(() => _loading = true);
    try {
      await PayoutsApi.ensureInitialized();
      await CoreClient.ensure();

      final r = await CoreClient.I.dio.get('/api/payout/tx/$_txId/');
      final raw = CoreClient.I.unwrap(r.data);

      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);

        if (m['data'] is Map) {
          final data = Map<String, dynamic>.from(m['data'] as Map);

          _tx = {
            ...data,
            'data': data,
            'status': (data['status'] ?? m['status'] ?? '').toString(),
            'reference': data['reference'] ??
                data['providerReference'] ??
                m['reference'],
            'updatedAt':
                data['updatedAt'] ?? data['updated_at'] ?? m['updatedAt'],
          };
        } else {
          _tx = m;
        }
      }
      _fetchError = null;
    } catch (e) {
      _fetchError = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor() {
    switch (_status) {
      case 'SUCCESS':
        return const Color(0xFF16A34A);
      case 'FAILED':
      case 'REVERSED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  IconData _statusIcon() {
    switch (_status) {
      case 'SUCCESS':
        return Icons.check_circle_rounded;
      case 'FAILED':
      case 'REVERSED':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_bottom_rounded;
    }
  }

  String _statusTitle() {
    switch (_status) {
      case 'SUCCESS':
        return 'Transfer Successful';
      case 'FAILED':
        return 'Transfer Failed';
      case 'REVERSED':
        return 'Transfer Reversed';
      default:
        return 'Transfer Pending';
    }
  }

  void _shareReceipt() {
    final details = '''
OSVAN TRANSFER RECEIPT

Status: $_status
Reference: $_reference
Timestamp: $_timestamp

Country: $_country
Method: $_method
Currency: ${_currency.isEmpty ? '-' : _currency}
Recipient: $_beneficiary
Bank/Provider: $_providerOrBank

Amount: ${_amount.isEmpty ? '—' : _amount}
''';

    Share.share(details);
  }

  Future<void> _exportReceipt({required bool share}) async {
    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Unable to capture receipt');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) throw Exception('Failed to encode image');

      final dir = await getTemporaryDirectory();
      final safeRef = _reference.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '_');
      final file = File('${dir.path}/osvan-receipt-$safeRef.png');
      await file.writeAsBytes(bytes, flush: true);

      if (share) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'OSVAN transfer receipt $_reference',
        );
      } else {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Save OSVAN transfer receipt $_reference',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Use the share sheet to save the receipt.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export receipt: $e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copy(String label, String value) async {
    if (value.isEmpty || value == 'N/A') return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _goHome() async {
    _timer?.cancel();
    try {
      Get.offAllNamed(AppRoutes.main);
      return;
    } catch (_) {}
    Get.offAllNamed('/main');
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kDarkBg,
        appBar: AppBar(
          backgroundColor: kDarkBg,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: const Text(
            'Transfer Receipt',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: kPaperDark,
              onSelected: (value) {
                switch (value) {
                  case 'refresh':
                    _fetchTxOnce();
                    break;
                  case 'share_text':
                    _shareReceipt();
                    break;
                  case 'save_image':
                    _exportReceipt(share: false);
                    break;
                  case 'share_image':
                    _exportReceipt(share: true);
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'refresh',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.refresh, color: Colors.white),
                    title: Text('Refresh status',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                PopupMenuItem(
                  value: 'share_text',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.ios_share_rounded, color: Colors.white),
                    title: Text('Share text receipt',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                PopupMenuItem(
                  value: 'save_image',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.download_rounded, color: Colors.white),
                    title: Text('Save as image',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                PopupMenuItem(
                  value: 'share_image',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.image_outlined, color: Colors.white),
                    title: Text('Share image',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            children: [
              // capture only the paper receipt (best for exports)
              RepaintBoundary(
                key: _captureKey,
                child: _PaperReceipt(
                  brandTitle: 'OSVAN',
                  subtitle: 'Transfer Receipt',
                  statusTitle: _statusTitle(),
                  status: _status,
                  statusColor: statusColor,
                  statusIcon: _statusIcon(),
                  loading: _loading,
                  warning: _fetchError != null
                      ? 'Could not refresh status. Showing last known data.'
                      : null,
                  amount: _amount,
                  currency: _currency,
                  timestamp: _timestamp,
                  reference: _reference,
                  onCopyRef: () => _copy('Reference', _reference),
                  rows: [
                    _RowKV('Recipient', _beneficiary),
                    _RowKV('Bank/Provider', _providerOrBank),
                    _RowKV('Country', _country.isEmpty ? '-' : _country),
                    _RowKV('Method', _method.isEmpty ? '-' : _method),
                    if (_currency.isNotEmpty) _RowKV('Currency', _currency),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // actions (not inside screenshot)
              _ActionRow(
                onCopy: () => _copy('Reference', _reference),
                onShareText: _shareReceipt,
                onShareImage: () => _exportReceipt(share: true),
                onSaveImage: () => _exportReceipt(share: false),
              ),
              const SizedBox(height: 12),

              _PrimaryCTA(
                label: 'Return to Home',
                onTap: _goHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Simple Bank Receipt UI (Paper style)
// ─────────────────────────────────────────────────────────────

class _RowKV {
  final String k;
  final String v;
  const _RowKV(this.k, this.v);
}

class _PaperReceipt extends StatelessWidget {
  final String brandTitle;
  final String subtitle;

  final String statusTitle;
  final String status;
  final Color statusColor;
  final IconData statusIcon;
  final bool loading;
  final String? warning;

  final String amount;
  final String currency;
  final String timestamp;
  final String reference;
  final VoidCallback onCopyRef;
  final List<_RowKV> rows;

  const _PaperReceipt({
    required this.brandTitle,
    required this.subtitle,
    required this.statusTitle,
    required this.status,
    required this.statusColor,
    required this.statusIcon,
    required this.loading,
    required this.warning,
    required this.amount,
    required this.currency,
    required this.timestamp,
    required this.reference,
    required this.onCopyRef,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kReceiptPaper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -42,
              top: -42,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withOpacity(0.08),
                  border: Border.all(color: statusColor.withOpacity(0.08)),
                ),
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0F172A),
                        Color(0xFF111C33),
                        Color(0xFF08111F),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.10),
                              ),
                            ),
                            child: const Icon(Icons.account_balance_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  brandTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.68),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: statusColor.withOpacity(0.36),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  status,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              statusTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (loading)
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(statusColor),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    children: [
                      if ((warning ?? '').isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFD97706).withOpacity(0.22),
                            ),
                          ),
                          child: Text(
                            warning!,
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Amount paid',
                              style: TextStyle(
                                color: kReceiptMuted,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: FittedBox(
                                    alignment: Alignment.centerLeft,
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      amount.isEmpty ? '-' : amount,
                                      style: const TextStyle(
                                        color: kReceiptInk,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 34,
                                      ),
                                    ),
                                  ),
                                ),
                                if (currency.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      currency,
                                      style: const TextStyle(
                                        color: kReceiptMuted,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ReceiptSection(
                        title: 'Transaction details',
                        children: [
                          _KVLine(
                            label: 'Reference',
                            value: reference,
                            strong: true,
                            trailing: TextButton.icon(
                              onPressed: onCopyRef,
                              icon: const Icon(Icons.copy_rounded, size: 15),
                              label: const Text('Copy'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 34),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                          _KVLine(label: 'Timestamp', value: timestamp),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ReceiptSection(
                        title: 'Recipient details',
                        children: [
                          for (final r in rows) _KVLine(label: r.k, value: r.v),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor.withOpacity(0.12),
                              ),
                              child: Icon(
                                Icons.verified_user_rounded,
                                color: statusColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This receipt was generated by Osvan. Keep the reference for support and reconciliation.',
                                style: TextStyle(
                                  color: kReceiptInk.withOpacity(0.72),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Thank you for using Osvan',
                        style: TextStyle(
                          color: kReceiptInk.withOpacity(0.60),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ReceiptSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kReceiptInk,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _KVLine extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final Widget? trailing;

  const _KVLine({
    required this.label,
    required this.value,
    this.strong = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.isEmpty ? '-' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: kReceiptMuted,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    v,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: kReceiptInk,
                      fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
                      fontSize: 12.8,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  trailing!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final VoidCallback onCopy;
  final VoidCallback onShareText;
  final VoidCallback onSaveImage;
  final VoidCallback onShareImage;

  const _ActionRow({
    required this.onCopy,
    required this.onShareText,
    required this.onSaveImage,
    required this.onShareImage,
  });

  Widget _btn(
      BuildContext context, IconData icon, String label, VoidCallback cb) {
    return OutlinedButton.icon(
      onPressed: cb,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(0.14)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final buttons = [
          _btn(context, Icons.copy_rounded, 'Copy', onCopy),
          _btn(context, Icons.share_rounded, 'Share', onShareText),
          _btn(context, Icons.download_rounded, 'Save', onSaveImage),
          _btn(context, Icons.image_outlined, 'Image', onShareImage),
        ];

        if (compact) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: buttons
                .map(
                  (button) => SizedBox(
                    width: (constraints.maxWidth - 10) / 2,
                    child: button,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              Expanded(child: buttons[i]),
              if (i != buttons.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}

class _PrimaryCTA extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryCTA({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF60A5FA),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
