import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';

/// Weekly/monthly trends and category breakdown.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await ApiService.fetchSpendingAnalytics(days: 90);
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    if (_loading) {
      return Scaffold(
        backgroundColor: pl.background,
        body: Center(child: CircularProgressIndicator(color: pl.emerald)),
      );
    }
    final trends = _data?['trends'] as Map<String, dynamic>? ?? {};
    final weeklyRaw = (trends['weekly'] as List?) ?? [];
    final weekly = weeklyRaw.reversed.toList();
    final cats = (trends['category_this_month'] as List?) ?? [];

    return Scaffold(
      backgroundColor: pl.background,
      appBar: AppBar(
        backgroundColor: pl.surface,
        title: const Text('Spending analytics'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: RefreshIndicator(
        color: pl.emerald,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Recent weeks (spend)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: pl.textPrimary, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (weekly.isEmpty)
              Text('Not enough data yet — link a bank or add expenses.', style: TextStyle(color: pl.textMuted.withValues(alpha: 0.9)))
            else
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (v, m) {
                            final i = v.toInt();
                            if (i < 0 || i >= weekly.length) return const SizedBox.shrink();
                            final p = (weekly[i] as Map)['period']?.toString() ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(p.length > 8 ? p.substring(p.length - 5) : p,
                                  style: TextStyle(color: pl.textMuted, fontSize: 10)),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, m) => Text('${v.toInt()}', style: TextStyle(color: pl.textMuted, fontSize: 10)),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: [
                      for (var i = 0; i < weekly.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: ((weekly[i] as Map)['total'] as num?)?.toDouble() ?? 0,
                              color: pl.emerald,
                              width: 14,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 28),
            Text(
              'This month by category',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: pl.textPrimary, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...cats.map((raw) {
              final m = Map<String, dynamic>.from(raw as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(m['category']?.toString() ?? '', style: TextStyle(color: pl.textSecondary))),
                    Text('\$${(m['spent'] as num?)?.toStringAsFixed(2) ?? '0'}',
                        style: TextStyle(color: pl.textPrimary, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
