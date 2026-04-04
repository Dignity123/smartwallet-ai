import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/category_grouping.dart';
import 'common.dart';

/// Visual breakdown: pie by category + expandable sections with merchant rollups
/// (Groceries → Whole Foods; Entertainment → Netflix, Spotify; etc.).
class SpendingCategoryOverview extends StatelessWidget {
  const SpendingCategoryOverview({
    super.key,
    required this.groups,
    this.subscriptionMerchantHints = const {},
    this.showPieChart = true,
    this.periodLabel = 'Last 90 days',
    this.leadingBanner,
  });

  final List<CategorySpendGroup> groups;
  final Set<String> subscriptionMerchantHints;
  final bool showPieChart;
  final String periodLabel;
  final Widget? leadingBanner;

  static List<Color> _sliceColors(AppPalette p) =>
      [p.emerald, p.blue, p.warning, p.danger, const Color(0xFFC77DFF), const Color(0xFFFF9F6B)];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chartColors = _sliceColors(p);
    final grandTotal = groups.fold<double>(0, (s, g) => s + g.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (leadingBanner != null) ...[
          leadingBanner!,
          const SizedBox(height: 16),
        ],
        Text(
          periodLabel,
          style: TextStyle(color: p.textMuted.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total spend',
              style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              fmt(grandTotal),
              style: TextStyle(color: p.emerald, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Grouped from every synced transaction. Expand a category to see merchants (subscriptions and bills show as recurring when detected).',
          style: TextStyle(color: p.textMuted.withValues(alpha: 0.9), fontSize: 12, height: 1.35),
        ),
        if (showPieChart && groups.isNotEmpty) ...[
          const SizedBox(height: 18),
          _CategoryPie(groups: groups, chartColors: chartColors),
        ],
        const SizedBox(height: 12),
        Text(
          'By category',
          style: TextStyle(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No transactions yet. Link a bank or add a manual expense.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted.withValues(alpha: 0.95)),
            ),
          )
        else
          ...groups.map((g) => _CategoryCard(
                group: g,
                subscriptionHints: subscriptionMerchantHints,
              )),
      ],
    );
  }
}

class _CategoryPie extends StatelessWidget {
  const _CategoryPie({required this.groups, required this.chartColors});

  final List<CategorySpendGroup> groups;
  final List<Color> chartColors;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sorted = List<CategorySpendGroup>.from(groups)..sort((a, b) => b.total.compareTo(a.total));
    const maxSlices = 6;
    double other = 0;
    final top = <CategorySpendGroup>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i < maxSlices) {
        top.add(sorted[i]);
      } else {
        other += sorted[i].total;
      }
    }
    final entries = <({String key, double value})>[
      ...top.map((g) => (key: g.category, value: g.total)),
      if (other > 0) (key: 'Other', value: other),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spend mix',
            style: TextStyle(color: p.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 32,
                      sections: entries.asMap().entries.map((e) {
                        final color = chartColors[e.key % chartColors.length];
                        return PieChartSectionData(
                          value: e.value.value,
                          color: color,
                          radius: 38,
                          showTitle: false,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: entries.asMap().entries.map((e) {
                      final color = chartColors[e.key % chartColors.length];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.value.key,
                                style: TextStyle(color: p.textSecondary, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              fmt(e.value.value),
                              style: TextStyle(color: p.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.group,
    required this.subscriptionHints,
  });

  final CategorySpendGroup group;
  final Set<String> subscriptionHints;

  bool _isRecurringMerchant(MerchantRollup r) {
    if (r.anyRecurring) return true;
    final m = r.merchant.trim().toLowerCase();
    return subscriptionHints.contains(m) ||
        subscriptionHints.any((h) => h.isNotEmpty && (m.contains(h) || h.contains(m)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        iconColor: p.textSecondary,
        collapsedIconColor: p.textMuted,
        title: Row(
          children: [
            Expanded(
              child: Text(
                group.category,
                style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            Text(
              fmt(group.total),
              style: TextStyle(color: p.emerald, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ],
        ),
        subtitle: Text(
          '${group.merchants.length} merchant${group.merchants.length == 1 ? '' : 's'}',
          style: TextStyle(color: p.textMuted, fontSize: 11),
        ),
        children: group.merchants
            .map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.merchant,
                            style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (r.count > 1)
                            Text(
                              '${r.count} charges',
                              style: TextStyle(color: p.textMuted, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    if (_isRecurringMerchant(r))
                      Container(
                        margin: const EdgeInsets.only(right: 8, top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Recurring',
                          style: TextStyle(color: p.blue, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    Text(
                      fmt(r.total),
                      style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
