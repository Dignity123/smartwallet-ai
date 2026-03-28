import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(builder: (_, p, __) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Subscription Detective 🔍',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Find forgotten & duplicate charges.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ]),
                EmeraldButton(label: 'Scan', loading: p.loading, onTap: () => p.scanNow()),
              ],
            ),
            const SizedBox(height: 28),

            if (p.loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(60),
                child: Column(children: [
                  CircularProgressIndicator(color: AppColors.emerald),
                  SizedBox(height: 14),
                  Text('Scanning your bank history…', style: TextStyle(color: AppColors.textMuted)),
                ]),
              ))
            else if (p.scan == null)
              _ScanPrompt(onTap: () => p.scanNow())
            else ...[
              _SummaryRow(scan: p.scan!),
              const SizedBox(height: 20),
              if (p.scan!.cancelCandidates.isNotEmpty) ...[
                _CancelAlert(candidates: p.scan!.cancelCandidates, insight: p.scan!.insight),
                const SizedBox(height: 20),
              ],
              _CategoryPieChart(subscriptions: p.scan!.subscriptions),
              const SizedBox(height: 20),
              const Text('All Subscriptions',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...p.scan!.subscriptions.map((s) => _SubscriptionTile(s)),
            ],
          ],
        ),
      );
    });
  }
}

class _ScanPrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.emeraldDim, shape: BoxShape.circle),
              child: const Icon(Icons.radar, color: AppColors.emerald, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Tap to Scan', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('AI will scan your transactions for recurring charges and hidden waste.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]),
        ),
      );
}

class _SummaryRow extends StatelessWidget {
  final dynamic scan;
  const _SummaryRow({required this.scan});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: StatCard(label: 'Monthly Cost', value: fmt(scan.totalMonthlyCost), accent: AppColors.danger)),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: 'Wasted', value: fmt(scan.wastedMonthly), accent: AppColors.warning)),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: 'Services', value: '${scan.subscriptions.length}', accent: AppColors.blue)),
      ]);
}

class _CancelAlert extends StatelessWidget {
  final List<dynamic> candidates;
  final String insight;
  const _CancelAlert({required this.candidates, required this.insight});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.dangerDim,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
              SizedBox(width: 8),
              Text('AI Recommends Cancelling',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
            ...candidates.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.merchant,
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(c.reason, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  )),
                  const SizedBox(width: 8),
                  Text('Save ${fmt(c.savings)}/mo',
                      style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            )),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.6), borderRadius: BorderRadius.circular(10)),
              child: Text('💬 $insight', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
            ),
          ],
        ),
      );
}

class _CategoryPieChart extends StatelessWidget {
  final List<dynamic> subscriptions;
  const _CategoryPieChart({required this.subscriptions});

  static const _colors = [AppColors.emerald, AppColors.blue, AppColors.warning, AppColors.danger, Color(0xFFC77DFF)];

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final s in subscriptions) {
      totals[s.category] = (totals[s.category] ?? 0) + s.amount;
    }
    final entries = totals.entries.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spend by Category',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(children: [
              Expanded(
                child: PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 36,
                  sections: entries.asMap().entries.map((e) {
                    final color = _colors[e.key % _colors.length];
                    return PieChartSectionData(
                      value:     e.value.value,
                      color:     color,
                      radius:    40,
                      showTitle: false,
                    );
                  }).toList(),
                )),
              ),
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entries.asMap().entries.map((e) {
                  final color = _colors[e.key % _colors.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(e.value.key, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(fmt(e.value.value),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ]),
                  );
                }).toList(),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final dynamic sub;
  const _SubscriptionTile(this.sub);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.emeraldDim, borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(sub.merchant[0],
                  style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w800, fontSize: 16))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sub.merchant, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              Text(sub.category, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt(sub.amount), style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w700, fontSize: 14)),
              Text(sub.frequency, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ]),
            IconButton(
              tooltip: 'Mark cancelling — alert if charged again',
              icon: const Icon(Icons.flag_outlined, color: AppColors.warning, size: 20),
              onPressed: () async {
                final ok = await ApiService.markCancelIntent(sub.merchant as String, (sub.amount as num).toDouble());
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Tracking cancellation for ${sub.merchant}' : 'Could not save')),
                );
              },
            ),
          ],
        ),
      );
}