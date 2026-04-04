import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/category_grouping.dart';
import '../widgets/common.dart';
import '../widgets/spending_category_overview.dart';

/// Category rollup from all transactions, plus AI subscription scan
/// (recurring badges, savings tips, cancel flags).
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  int _segment = 0;
  List<String> _categories = [];
  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _dateFmt = DateFormat.MMMd();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().refreshAll();
    });
    _preloadCategories();
  }

  Future<void> _preloadCategories() async {
    final cats = await ApiService.fetchExpenseCategories();
    if (mounted) setState(() => _categories = cats);
  }

  Widget _segmentBar(BuildContext context) {
    final pl = context.palette;
    Widget chip(String label, int index) {
      final on = _segment == index;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Center(child: Text(label)),
            labelStyle: TextStyle(
              color: on ? pl.onEmerald : pl.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            selected: on,
            selectedColor: pl.emerald,
            backgroundColor: pl.surfaceAlt,
            side: BorderSide(color: on ? pl.emerald : pl.border),
            onSelected: (_) => setState(() => _segment = index),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [chip('By category', 0), chip('All activity', 1)]),
    );
  }

  Future<void> _addManual() async {
    final amountCtrl = TextEditingController();
    final merchantCtrl = TextEditingController();
    String? picked;
    final pl0 = context.palette;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: pl0.surface,
      isScrollControlled: true,
      builder: (ctx) {
        final pl = ctx.palette;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add expense',
                      style: TextStyle(color: pl.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: pl.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      labelStyle: TextStyle(color: pl.textMuted),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: merchantCtrl,
                    style: TextStyle(color: pl.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Merchant / description',
                      labelStyle: TextStyle(color: pl.textMuted),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: picked,
                    dropdownColor: pl.surfaceAlt,
                    hint: Text('Category (optional)', style: TextStyle(color: pl.textMuted)),
                    style: TextStyle(color: pl.textPrimary),
                    items: _categories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: pl.textPrimary))))
                        .toList(),
                    onChanged: (v) => setModal(() => picked = v),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: pl.emerald, foregroundColor: pl.onEmerald),
                    onPressed: () async {
                      final amt = double.tryParse(amountCtrl.text);
                      final m = merchantCtrl.text.trim();
                      if (amt == null || amt <= 0 || m.isEmpty) return;
                      final res = await ApiService.addManualExpense(amount: amt, merchant: m, category: picked);
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      if (res == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not save expense'), behavior: SnackBarBehavior.floating),
                        );
                        return;
                      }
                      await context.read<SubscriptionProvider>().refreshAll();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expense added'), behavior: SnackBarBehavior.floating),
                        );
                      }
                    },
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    amountCtrl.dispose();
    merchantCtrl.dispose();
  }

  Future<void> _pickCategory(Map<String, dynamic> row) async {
    final id = int.tryParse('${row['id']}');
    if (id == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final pl = ctx.palette;
        String? sel = row['category']?.toString();
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            backgroundColor: pl.surfaceAlt,
            title: Text('Category', style: TextStyle(color: pl.textPrimary)),
            content: DropdownButtonFormField<String>(
              initialValue: sel,
              dropdownColor: pl.surface,
              style: TextStyle(color: pl.textPrimary),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setD(() => sel = v),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (sel == null || sel!.isEmpty) return;
                  final ok = await ApiService.updateTransactionCategory(id, sel!);
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  await context.read<SubscriptionProvider>().refreshAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'Updated' : 'Failed'), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    return Consumer<SubscriptionProvider>(builder: (_, p, __) {
      if (p.loading && p.transactions.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: pl.emerald),
                const SizedBox(height: 14),
                Text('Loading transactions & scanning…', style: TextStyle(color: pl.textMuted)),
              ],
            ),
          ),
        );
      }

      final groups = groupTransactionsByCategory(p.transactions);
      final hints = p.scan == null
          ? <String>{}
          : subscriptionMerchantHints(p.scan!.subscriptions.map((s) => s.merchant));

      final leading = p.scan == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryRow(scan: p.scan!),
                if (p.scan!.cancelCandidates.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _CancelAlert(candidates: p.scan!.cancelCandidates, insight: p.scan!.insight),
                ],
              ],
            );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subscriptions & spending',
                        style: TextStyle(color: pl.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All charges grouped by category; AI highlights subscriptions and savings.',
                        style: TextStyle(color: pl.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: p.loading ? null : _addManual,
                      child: const Text('Add expense', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 4),
                    EmeraldButton(label: 'Refresh', loading: p.loading, onTap: () => p.refreshAll()),
                  ],
                ),
              ],
            ),
          ),
          _segmentBar(context),
          Expanded(
            child: RefreshIndicator(
              color: pl.emerald,
              onRefresh: p.refreshAll,
              child: _segment == 0
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      children: [
                        SpendingCategoryOverview(
                          groups: groups,
                          subscriptionMerchantHints: hints,
                          showPieChart: true,
                          periodLabel: 'Last 90 days · ${p.transactions.length} transactions',
                          leadingBanner: leading,
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      itemCount: p.transactions.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Text(
                            'Tap a row to change category. Use the flag on the right to track a cancellation.',
                            style: TextStyle(
                              color: pl.textMuted.withValues(alpha: 0.95),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          );
                        }
                        final t = p.transactions[i - 1];
                        final amt = (t['amount'] as num?)?.toDouble() ?? 0;
                        final mer = t['merchant']?.toString() ?? '';
                        final cat = t['category']?.toString() ?? '';
                        final ds = t['date']?.toString() ?? '';
                        DateTime? d;
                        try {
                          d = DateTime.tryParse(ds);
                        } catch (_) {}
                        final subMatch = p.scan?.subscriptions.any(
                              (s) => s.merchant.toLowerCase() == mer.toLowerCase(),
                            ) ??
                            false;
                        return Material(
                          color: pl.surface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _pickCategory(t),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(mer,
                                            style: TextStyle(
                                                color: pl.textPrimary, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${d != null ? _dateFmt.format(d) : ds} · $cat${subMatch ? ' · Detected sub' : ''}',
                                          style: TextStyle(color: pl.textMuted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(_currency.format(amt),
                                      style:
                                          TextStyle(color: pl.emerald, fontWeight: FontWeight.w800)),
                                  if (subMatch)
                                    IconButton(
                                      tooltip: 'Mark cancelling — alert if charged again',
                                      icon: Icon(Icons.flag_outlined, color: pl.warning, size: 20),
                                      onPressed: () async {
                                        final ok = await ApiService.markCancelIntent(mer, amt);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(ok ? 'Tracking cancellation for $mer' : 'Could not save'),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      );
    });
  }
}

class _SummaryRow extends StatelessWidget {
  final dynamic scan;
  const _SummaryRow({required this.scan});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
            child: StatCard(label: 'Est. monthly (AI)', value: fmt(scan.totalMonthlyCost), accent: p.danger)),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: 'Wasted', value: fmt(scan.wastedMonthly), accent: p.warning)),
        const SizedBox(width: 12),
        Expanded(
            child: StatCard(
                label: 'Services', value: '${scan.subscriptions.length}', accent: p.blue)),
      ],
    );
  }
}

class _CancelAlert extends StatelessWidget {
  final List<dynamic> candidates;
  final String insight;
  const _CancelAlert({required this.candidates, required this.insight});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.dangerDim,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.danger.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: p.danger, size: 18),
                const SizedBox(width: 8),
                Text('Worth reviewing',
                    style: TextStyle(color: p.danger, fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            ...candidates.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                      Expanded(
                          child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          Text(c.merchant,
                              style: TextStyle(
                                  color: p.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(c.reason, style: TextStyle(color: p.textMuted, fontSize: 12)),
                    ],
                  )),
                  const SizedBox(width: 8),
                      Text('Save ${fmt(c.savings)}/mo',
                          style: TextStyle(color: p.emerald, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            )),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(color: p.surface.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
              child: Text(insight, style: TextStyle(color: p.textSecondary, fontSize: 12, height: 1.5)),
            ),
          ],
        ),
      );
  }
}
