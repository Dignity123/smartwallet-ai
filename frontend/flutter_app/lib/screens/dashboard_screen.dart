import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import '../utils/greeting.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(builder: (_, p, __) {
      final pl = context.palette;
      if (p.loading) return Center(child: CircularProgressIndicator(color: pl.emerald));

      final s = p.summary;
      if (s == null) {
        return Center(child: Text('No data', style: TextStyle(color: pl.textMuted)));
      }

      return RefreshIndicator(
        color: pl.emerald,
        backgroundColor: pl.surface,
        onRefresh: () => p.load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Greeting ──────────────────────────────────────────────────
              Text(
                timeBasedGreeting(name: context.watch<AuthProvider>().name),
                style: TextStyle(color: pl.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text("Here's your money pulse.",
                  style: TextStyle(color: pl.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),

              // ── Balance Hero Card ──────────────────────────────────────────
              _BalanceCard(balance: s.balance, savingsRate: s.savingsRate),
              const SizedBox(height: 16),

              // ── Stat Row ──────────────────────────────────────────────────
              Row(children: [
                Expanded(child: StatCard(label: 'Monthly Spend', value: fmt(s.totalSpend))),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Savings Rate', value: '${s.savingsRate.toStringAsFixed(1)}%', accent: pl.warning)),
              ]),
              const SizedBox(height: 28),

              // ── Spending Chart ─────────────────────────────────────────────
              const SectionHeader(title: 'Spending vs Budget', subtitle: 'Your spend against healthy benchmarks'),
              const SizedBox(height: 16),
              _SpendingChart(categories: s.byCategory),
              const SizedBox(height: 28),

              // ── Over Budget Alerts ─────────────────────────────────────────
              if (s.byCategory.any((c) => c.overBudget)) ...[
                const SectionHeader(title: 'Over Budget', subtitle: 'Categories that need attention'),
                const SizedBox(height: 12),
                ...s.byCategory.where((c) => c.overBudget).map((c) => _OverBudgetTile(c)),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _BalanceCard extends StatelessWidget {
  final AccountBalance balance;
  final double savingsRate;
  const _BalanceCard({required this.balance, required this.savingsRate});

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF1A2F1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pl.emerald.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available Balance',
              style: TextStyle(color: pl.textMuted, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(fmt(balance.available),
              style: TextStyle(color: pl.emerald, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 16),
          Row(children: [
            _BalancePill(label: 'Current', value: fmt(balance.current)),
            const SizedBox(width: 12),
            _BalancePill(label: 'Savings Rate', value: '${savingsRate.toStringAsFixed(1)}%', highlight: true),
          ]),
        ],
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _BalancePill({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: highlight ? pl.emeraldDim : pl.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Text('$label: ', style: TextStyle(color: pl.textMuted, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: highlight ? pl.emerald : pl.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      );
  }
}

class _SpendingChart extends StatelessWidget {
  final List<dynamic> categories;
  const _SpendingChart({required this.categories});

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    final items = categories.take(5).toList();
    if (items.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pl.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pl.border),
        ),
        child: Text('No category data yet', style: TextStyle(color: pl.textMuted)),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color: pl.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pl.border),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: items.map((c) => (c.benchmark as double) * 1.2).reduce((a, b) => a > b ? a : b),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => pl.surfaceAlt,
              getTooltipItem: (group, _, rod, rodIndex) {
                final label = rodIndex == 0 ? 'Spent' : 'Budget';
                final value = rod.toY;
                return BarTooltipItem(
                  '$label: ${fmt(value)}',
                  TextStyle(color: rodIndex == 0 ? pl.danger : pl.emerald, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final name = (items[v.toInt()].category as String).split(' ').first;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(name, style: TextStyle(color: pl.textMuted, fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text('\$${v.toInt()}',
                    style: TextStyle(color: pl.textMuted, fontSize: 9)),
              ),
            ),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: pl.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          barGroups: items.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY:       c.spent,
                color:     c.overBudget ? pl.danger : pl.blue,
                width:     10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY:       c.benchmark,
                color:     pl.emerald.withValues(alpha: 0.5),
                width:     10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _OverBudgetTile extends StatelessWidget {
  final dynamic category;
  const _OverBudgetTile(this.category);

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: pl.dangerDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: pl.danger.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: pl.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${category.category} — ${fmt(category.spent)} spent vs ${fmt(category.benchmark)} budget',
                style: TextStyle(color: pl.textPrimary, fontSize: 13)),
          ),
        ]),
      );
  }
}