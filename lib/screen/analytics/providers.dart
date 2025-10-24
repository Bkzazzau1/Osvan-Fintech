import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:osvan_app/screen/analytics/models/breakdown.dart';

import '../../core/network/api_client.dart';
import 'data/analytics_api.dart';
// stays
import 'models/reliability.dart';
import 'models/risk_event.dart';
import 'models/summary_kpis.dart';
import 'models/timeseries.dart';

final baseUrlProvider = Provider<String>(
  (_) => 'https://fintech.osvan.africa/api', // adjust per env
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final base = ref.watch(baseUrlProvider);
  return ApiClient(baseUrl: base);
});

final analyticsApiProvider = Provider<AnalyticsApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return AnalyticsApi(client);
});

String _d(int minusDays) {
  final now = DateTime.now();
  final d = now.subtract(Duration(days: minusDays));
  return DateFormat('yyyy-MM-dd').format(d);
}

// Summary
final summaryProvider = FutureProvider<SummaryKpis>((ref) async {
  final api = ref.watch(analyticsApiProvider);
  return api.getSummary(
      from: _d(30), to: _d(0), country: 'NG', currency: 'USD');
});

// Timeseries (volume)
final volumeSeriesProvider = FutureProvider<TimeseriesResponse>((ref) async {
  final api = ref.watch(analyticsApiProvider);
  return api.getTimeseries(metric: 'volume', interval: 'day');
});

// Breakdown (top providers)
final providersBreakdownProvider = FutureProvider<Breakdown>((ref) async {
  // ✅ Change 1
  final api = ref.watch(analyticsApiProvider);
  return api.getBreakdown(
      metric: 'volume',
      groupBy: 'provider',
      limit: 6); // ✅ same method, but returns Breakdown
}); // ✅ Change 2

// Reliability
final walletsReliabilityProvider = FutureProvider<Reliability>((ref) async {
  final api = ref.watch(analyticsApiProvider);
  return api.getReliability(module: 'wallets');
});

// Risk
final riskTopProvider = FutureProvider<List<RiskEvent>>((ref) async {
  final api = ref.watch(analyticsApiProvider);
  return api.getRiskTop(limit: 20);
});
