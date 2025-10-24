// lib/screen/analytics/dashboard_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:osvan_app/screen/analytics/models/reliability.dart';
import 'package:osvan_app/screen/analytics/models/summary_kpis.dart';
import 'package:osvan_app/screen/analytics/models/timeseries.dart';
import 'package:osvan_app/screen/analytics/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    final volume = ref.watch(volumeSeriesProvider);
    final breakdown = ref.watch(providersBreakdownProvider);
    final rel = ref.watch(walletsReliabilityProvider);
    final risk = ref.watch(riskTopProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Osvan Analytics')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(summaryProvider);
          ref.invalidate(volumeSeriesProvider);
          ref.invalidate(providersBreakdownProvider);
          ref.invalidate(walletsReliabilityProvider);
          ref.invalidate(riskTopProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary row
            summary.when(
              data: (SummaryKpis k) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _KpiCard(
                      title: 'New verified', value: '${k.newVerifiedUsers}'),
                  _KpiCard(
                      title: 'Active wallets', value: '${k.activeWallets}'),
                  _KpiCard(
                    title: 'Total volume',
                    value:
                        '${k.totalVolume.amount.toStringAsFixed(2)} ${k.totalVolume.currency}',
                  ),
                  _KpiCard(title: 'Net revenue', value: k.netRevenue),
                  _KpiCard(
                    title: 'KYC pass',
                    value: '${(k.kycPassRate * 100).toStringAsFixed(1)}%',
                  ),
                  _KpiCard(
                      title: 'P95 latency',
                      value: '${k.walletConnectP95Ms} ms'),
                  _KpiCard(
                    title: '5xx rate',
                    value: '${(k.errors5xxRate * 100).toStringAsFixed(2)}%',
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorTile(msg: e.toString()),
            ),

            const SizedBox(height: 16),

            // Volume chart
            volume.when(
              data: (TimeseriesResponse ts) => _TimeseriesChart(ts: ts),
              loading: () => const _LoadingCard(title: 'Volume'),
              error: (e, _) => _ErrorTile(msg: e.toString()),
            ),

            const SizedBox(height: 16),

            // Reliability mini
            rel.when(
              data: (Reliability r) =>
                  _KpiCard(title: 'Wallets p95', value: '${r.p95Ms} ms'),
              loading: () => const _LoadingCard(title: 'Reliability'),
              error: (e, _) => _ErrorTile(msg: e.toString()),
            ),

            const SizedBox(height: 16),

            // Breakdown & Risk lightweight tiles
            breakdown.when(
              data: (b) => _KpiCard(
                title: 'Top provider',
                // BreakdownItem has `key` (not `label`)
                value: (b.items.isEmpty ? '-' : b.items.first.key),
              ),
              loading: () => const _LoadingCard(title: 'Breakdown'),
              error: (e, _) => _ErrorTile(msg: e.toString()),
            ),

            risk.when(
              data: (items) =>
                  _KpiCard(title: 'High-risk events', value: '${items.length}'),
              loading: () => const _LoadingCard(title: 'Risk'),
              error: (e, _) => _ErrorTile(msg: e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  const _KpiCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String title;
  const _LoadingCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 140,
        child: Center(child: Text('Loading $title…')),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String msg;
  const _ErrorTile({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $msg'),
      ),
    );
  }
}

class _TimeseriesChart extends StatelessWidget {
  final TimeseriesResponse ts;
  const _TimeseriesChart({required this.ts});

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = <FlSpot>[];

    // New plain model: prefer series if present, else use the first group
    final series = ts.series;
    final grouped = ts.grouped;

    if (series != null) {
      for (var i = 0; i < series.length; i++) {
        spots.add(FlSpot(i.toDouble(), series[i].y));
      }
    } else if (grouped != null && grouped.isNotEmpty) {
      final first = grouped.values.first;
      for (var i = 0; i < first.length; i++) {
        spots.add(FlSpot(i.toDouble(), first[i].y));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: true),
              gridData: const FlGridData(show: false),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  spots: spots,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
