import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/colors.dart';
import '../../../services/limit_service.dart';

class TransactionLimitView extends StatefulWidget {
  const TransactionLimitView({super.key});

  @override
  State<TransactionLimitView> createState() => _TransactionLimitViewState();
}

class _TransactionLimitViewState extends State<TransactionLimitView> {
  final _formKey = GlobalKey<FormState>();
  final _dailyCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _editable = true;

  int? _minDaily, _maxDaily, _minMonthly, _maxMonthly;
  int? _initialDaily, _initialMonthly;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final data = await LimitService.getLimits();
      final daily = (data['daily_limit'] ?? 10000).toInt();
      final monthly = (data['monthly_limit'] ?? 30000).toInt();

      _minDaily = (data['min_daily'] ?? 1).toInt();
      _maxDaily = (data['max_daily'] ?? 100000000).toInt();
      _minMonthly = (data['min_monthly'] ?? 1).toInt();
      _maxMonthly = (data['max_monthly'] ?? 1000000000).toInt();

      _editable = (data['editable'] ?? true) == true;

      _initialDaily = daily;
      _initialMonthly = monthly;

      _dailyCtrl.text = daily.toString();
      _monthlyCtrl.text = monthly.toString();
    } on LimitServiceError catch (e) {
      if (e.code == 'unauthorized') {
        Get.snackbar('Session expired', 'Please log in again.',
            backgroundColor: Colors.red, colorText: Colors.white);
        Get.offAllNamed('/login');
        return;
      }
      Get.snackbar('Error', 'Could not load limits',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _numberValidator(String? value,
      {required int min, required int max, required String label}) {
    if (value == null || value.trim().isEmpty) return 'Enter $label';
    final v = int.tryParse(value.replaceAll(',', ''));
    if (v == null) return 'Invalid $label';
    if (v < min) return '$label cannot be less than $min';
    if (v > max) return '$label cannot be more than $max';
    return null;
  }

  bool get _changed {
    final d = int.tryParse(_dailyCtrl.text.replaceAll(',', ''));
    final m = int.tryParse(_monthlyCtrl.text.replaceAll(',', ''));
    return d != _initialDaily || m != _initialMonthly;
  }

  Future<void> _save() async {
    if (!_editable) return;
    if (!_formKey.currentState!.validate()) return;

    final daily = int.parse(_dailyCtrl.text.replaceAll(',', ''));
    final monthly = int.parse(_monthlyCtrl.text.replaceAll(',', ''));

    setState(() => _saving = true);
    try {
      await LimitService.updateLimits(daily: daily, monthly: monthly);
      _initialDaily = daily;
      _initialMonthly = monthly;

      Get.snackbar('Saved', 'Your transaction limits have been updated.',
          backgroundColor: Colors.green, colorText: Colors.white);
      Get.back(); // close the page
    } on LimitServiceError catch (e) {
      if (e.code == 'unauthorized') {
        Get.offAllNamed('/login');
        return;
      }
      final msg = e.details ?? 'Failed to update limits';
      Get.snackbar('Update failed', msg,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 4));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _dailyCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _loading || _saving || !_editable;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Limits'),
        backgroundColor: osvanGreen,
        foregroundColor: Colors.white,
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                  child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        _editable
                            ? 'View or edit your send limits below.'
                            : 'Your limits are set by admin and cannot be changed.',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),

                      // Daily
                      TextFormField(
                        controller: _dailyCtrl,
                        enabled: _editable,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: 'Daily Limit (₦)',
                          border: const OutlineInputBorder(),
                          helperText: (_minDaily != null && _maxDaily != null)
                              ? 'Min: $_minDaily  •  Max: $_maxDaily'
                              : null,
                        ),
                        validator: (v) => _numberValidator(
                          v,
                          min: _minDaily ?? 1,
                          max: _maxDaily ?? 1000000000,
                          label: 'daily limit',
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Monthly
                      TextFormField(
                        controller: _monthlyCtrl,
                        enabled: _editable,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: 'Monthly Limit (₦)',
                          border: const OutlineInputBorder(),
                          helperText:
                              (_minMonthly != null && _maxMonthly != null)
                                  ? 'Min: $_minMonthly  •  Max: $_maxMonthly'
                                  : null,
                        ),
                        validator: (v) => _numberValidator(
                          v,
                          min: _minMonthly ?? 1,
                          max: _maxMonthly ?? 1000000000,
                          label: 'monthly limit',
                        ),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (disabled || !_changed) ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: osvanGreen,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 60, vertical: 14),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Save Limits',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),

                      if (!_editable) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Contact support to request an increase.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
