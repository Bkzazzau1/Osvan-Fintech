import '../../../core/network/api_client.dart';
import '../models/breakdown.dart';
import '../models/reliability.dart';
import '../models/risk_event.dart';
import '../models/summary_kpis.dart';
import '../models/timeseries.dart';

class AnalyticsApi {
  final ApiClient _client;
  AnalyticsApi(this._client);

  Future<SummaryKpis> getSummary({
    required String from, // "YYYY-MM-DD"
    required String to,
    String? country,
    String? currency,
  }) async {
    final res =
        await _client.raw.get('/api/v1/analytics/summary', queryParameters: {
      'from': from,
      'to': to,
      if (country != null) 'country': country,
      if (currency != null) 'currency': currency
    });
    return SummaryKpis.fromJson(
      Map<String, dynamic>.from((res.data as Map)['kpis'] as Map),
    );
  }

  Future<TimeseriesResponse> getTimeseries({
    required String metric, // volume|revenue|latency
    String interval = 'day',
    String? groupBy, // channel|provider|currency|country|module
    String? from,
    String? to,
  }) async {
    final res =
        await _client.raw.get('/api/v1/analytics/timeseries', queryParameters: {
      'metric': metric,
      'interval': interval,
      if (groupBy != null) 'group_by': groupBy,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return TimeseriesResponse.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  // 🔧 Return Breakdown (not BreakdownResponse)
  Future<Breakdown> getBreakdown({
    required String metric, // volume|revenue
    required String groupBy, // provider|currency|channel|country
    String? from,
    String? to,
    int limit = 20,
  }) async {
    final res =
        await _client.raw.get('/api/v1/analytics/breakdown', queryParameters: {
      'metric': metric,
      'group_by': groupBy,
      'limit': limit,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return Breakdown.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<Reliability> getReliability({
    required String module, // wallets|cards|...
    String? from,
    String? to,
  }) async {
    final res = await _client.raw
        .get('/api/v1/analytics/reliability', queryParameters: {
      'module': module,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return Reliability.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<List<RiskEvent>> getRiskTop({
    String? from,
    String? to,
    int limit = 50,
  }) async {
    final res =
        await _client.raw.get('/api/v1/analytics/risk/top', queryParameters: {
      'limit': limit,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    final list = (res.data as List)
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return list.map(RiskEvent.fromJson).toList();
  }
}
