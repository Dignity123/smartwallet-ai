import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _catCtrl = TextEditingController(text: 'Groceries');
  final _limitCtrl = TextEditingController(text: '400');
  final _plaidCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _catCtrl.dispose();
    _limitCtrl.dispose();
    _plaidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanProvider>(builder: (_, p, __) {
      return RefreshIndicator(
        color: AppColors.emerald,
        backgroundColor: AppColors.surface,
        onRefresh: () => p.refresh(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Plan & protect 💡',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Bank link, budgets, cash-flow risk, and smart alerts.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 22),

            const _SectionTitle('Bank connection (Plaid)'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      p.plaidLinked ? Icons.check_circle : Icons.link_off,
                      color: p.plaidLinked ? AppColors.emerald : AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.plaidLinked ? 'Linked — transactions sync + webhooks' : 'Mock data until you link',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      EmeraldButton(
                        label: 'Get link token',
                        small: true,
                        loading: p.loading,
                        onTap: () async {
                          final t = await p.requestPlaidLink();
                          if (!context.mounted) return;
                          if (t == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Plaid not configured on server')),
                            );
                            return;
                          }
                          await Clipboard.setData(ClipboardData(text: t));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link token copied — paste into Plaid Link')),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      EmeraldButton(
                        label: 'Sync now',
                        small: true,
                        onTap: () async {
                          final ok = await ApiService.syncPlaid();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'Sync complete' : 'Sync failed')),
                          );
                          await p.refresh();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _plaidCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Paste public_token from Plaid Link',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        final ok = await p.submitPlaidToken(_plaidCtrl.text);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Linked & synced' : 'Exchange failed')),
                        );
                        _plaidCtrl.clear();
                      },
                      child: const Text('Exchange public token'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            const _SectionTitle('Predictive cash flow'),
            if (p.cashflow != null)
              _CashFlowCard(f: p.cashflow!)
            else
              const Text('Loading…', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 22),

            const _SectionTitle('Category budgets'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _catCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _limitCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: '\$ / mo',
                      labelStyle: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  final lim = double.tryParse(_limitCtrl.text) ?? 0;
                  if (lim <= 0) return;
                  final ok = await p.addBudget(_catCtrl.text.trim(), lim);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Budget saved' : 'Failed')),
                  );
                },
                child: const Text('Add / update category budget'),
              ),
            ),
            ...p.budgets.map((g) => _BudgetTile(g)),
            if (p.budgets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No custom budgets — dashboard uses default benchmarks.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle('Smart alerts'),
                TextButton(
                  onPressed: () => p.runAlertChecks(),
                  child: const Text('Run checks'),
                ),
              ],
            ),
            ...p.alerts.take(12).map((a) => _AlertTile(a, onDismiss: () => p.dismissAlert(a.id))),
            if (p.alerts.isEmpty)
              const Text('No alerts yet. Link Plaid, set budgets, and tap Run checks.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    });
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      );
}

class _CashFlowCard extends StatelessWidget {
  final CashFlowForecast f;
  const _CashFlowCard({required this.f});

  @override
  Widget build(BuildContext context) {
    final riskColor = f.risk == 'high'
        ? AppColors.danger
        : f.risk == 'medium'
            ? AppColors.warning
            : AppColors.emerald;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next-month spend (est.)  ${fmt(f.projectedSpend)}',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Recurring ~${fmt(f.recurring)}  ·  Variable ~${fmt(f.variable)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          Text('Available now ${fmt(f.available)}  →  ~${fmt(f.projectedBalance30d)} in 30d',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Overdraft risk: ${f.risk}', style: TextStyle(color: riskColor, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final BudgetGoalProgress g;
  const _BudgetTile(this.g);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: g.isOver ? AppColors.danger.withOpacity(0.4) : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.category, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${fmt(g.spentThisMonth)} / ${fmt(g.monthlyLimit)}  (${g.percentUsed.toStringAsFixed(0)}%)',
                style: TextStyle(
                    color: g.isOver ? AppColors.danger : AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
}

class _AlertTile extends StatelessWidget {
  final SmartAlert a;
  final VoidCallback onDismiss;
  const _AlertTile(this.a, {required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(a.body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                  const SizedBox(height: 4),
                  Text(a.type, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ),
            if (!a.isRead)
              TextButton(onPressed: onDismiss, child: const Text('Got it', style: TextStyle(fontSize: 11))),
          ],
        ),
      );
}
