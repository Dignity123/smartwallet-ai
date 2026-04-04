import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'dart:async';

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
  StreamSubscription<LinkSuccess>? _plaidSuccess;
  StreamSubscription<LinkExit>? _plaidExit;
  StreamSubscription<LinkEvent>? _plaidEvent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanProvider>().refresh();
    });
    _plaidSuccess = PlaidLink.onSuccess.listen((s) async {
      if (!mounted) return;
      final p = context.read<PlanProvider>();
      final ok = await p.linkPlaidViaPublicToken(s.publicToken);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Bank linked' : 'Bank link failed'), behavior: SnackBarBehavior.floating),
      );
    });
    _plaidExit = PlaidLink.onExit.listen((e) {
      if (!mounted) return;
      if (e.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.error?.displayMessage ?? 'Plaid exited'), behavior: SnackBarBehavior.floating),
        );
      }
    });
    _plaidEvent = PlaidLink.onEvent.listen((_) {});
  }

  @override
  void dispose() {
    _plaidSuccess?.cancel();
    _plaidExit?.cancel();
    _plaidEvent?.cancel();
    super.dispose();
  }

  Future<void> _openPlaidLink(PlanProvider p) async {
    final token = await p.requestPlaidLink();
    if (!mounted) return;
    if (token == null || token.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plaid not configured on server'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    await PlaidLink.create(configuration: LinkTokenConfiguration(token: token));
    await PlaidLink.open();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanProvider>(builder: (_, p, __) {
      final pl = context.palette;
      return RefreshIndicator(
        color: pl.emerald,
        backgroundColor: pl.surface,
        onRefresh: () => p.refresh(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Plan & protect 💡',
                style: TextStyle(color: pl.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Bank link, cash-flow outlook, and smart alerts.',
                style: TextStyle(color: pl.textMuted, fontSize: 13)),
            const SizedBox(height: 22),

            const _SectionTitle('Bank connection (Plaid)'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pl.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pl.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      p.plaidLinked ? Icons.check_circle : Icons.link_off,
                      color: p.plaidLinked ? pl.emerald : pl.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.plaidLinked ? 'Linked — transactions sync + webhooks' : 'Mock data until you link',
                        style: TextStyle(color: pl.textSecondary, fontSize: 13),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      EmeraldButton(
                        label: 'Connect bank',
                        small: true,
                        loading: p.loading,
                        onTap: () => _openPlaidLink(p),
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
                ],
              ),
            ),
            const SizedBox(height: 22),

            const _SectionTitle('Predictive cash flow'),
            if (p.cashflow != null)
              _CashFlowCard(f: p.cashflow!)
            else
              Text('Loading…', style: TextStyle(color: pl.textMuted)),
            const SizedBox(height: 22),

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
              Text('No alerts yet. Link Plaid and tap Run checks.',
                  style: TextStyle(color: pl.textMuted, fontSize: 12)),
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
  Widget build(BuildContext context) {
    final pl = context.palette;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(color: pl.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      );
  }
}

class _CashFlowCard extends StatelessWidget {
  final CashFlowForecast f;
  const _CashFlowCard({required this.f});

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    final riskColor = f.risk == 'high'
        ? pl.danger
        : f.risk == 'medium'
            ? pl.warning
            : pl.emerald;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pl.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pl.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next-month spend (est.)  ${fmt(f.projectedSpend)}',
              style: TextStyle(color: pl.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Recurring ~${fmt(f.recurring)}  ·  Variable ~${fmt(f.variable)}',
              style: TextStyle(color: pl.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          Text('Available now ${fmt(f.available)}  →  ~${fmt(f.projectedBalance30d)} in 30d',
              style: TextStyle(color: pl.textSecondary, fontSize: 13)),
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

class _AlertTile extends StatelessWidget {
  final SmartAlert a;
  final VoidCallback onDismiss;
  const _AlertTile(this.a, {required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: pl.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: pl.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: TextStyle(color: pl.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(a.body, style: TextStyle(color: pl.textSecondary, fontSize: 12, height: 1.4)),
                  const SizedBox(height: 4),
                  Text(a.type, style: TextStyle(color: pl.textMuted, fontSize: 10)),
                ],
              ),
            ),
            if (!a.isRead)
              TextButton(onPressed: onDismiss, child: const Text('Got it', style: TextStyle(fontSize: 11))),
          ],
        ),
      );
  }
}
