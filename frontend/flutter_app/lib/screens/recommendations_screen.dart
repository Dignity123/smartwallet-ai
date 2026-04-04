import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

Color _recCategoryColor(String? category, AppPalette pl) {
  switch (category) {
    case 'subscriptions':
      return pl.blue;
    case 'impulse':
      return pl.warning;
    case 'budgeting':
      return const Color(0xFFC77DFF);
    case 'savings':
      return pl.emerald;
    default:
      return pl.blue;
  }
}

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});
  @override State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<RecommendationsProvider>().recommendations.isEmpty) {
        context.read<RecommendationsProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecommendationsProvider>(builder: (_, p, __) {
      final pl = context.palette;
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AI Recommendations 🤖',
                        style: TextStyle(color: pl.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Personalized actions to save money now.',
                        style: TextStyle(color: pl.textMuted, fontSize: 13)),
                  ]),
                  EmeraldButton(label: 'Refresh', loading: p.loading, onTap: () => p.load(), small: true),
                ],
              ),
              const SizedBox(height: 24),

              if (p.loading)
                Center(child: Padding(
                  padding: const EdgeInsets.all(60),
                  child: Column(children: [
                    CircularProgressIndicator(color: pl.emerald),
                    const SizedBox(height: 14),
                    Text('AI is generating your plan…', style: TextStyle(color: pl.textMuted)),
                  ]),
                ))
              else if (p.recommendations.isEmpty)
                Center(child: Text('Pull down to load recommendations.',
                    style: TextStyle(color: pl.textMuted)))
              else ...[
                _TotalSavingsCard(recommendations: p.recommendations),
                const SizedBox(height: 20),
                ...p.recommendations.asMap().entries.map((e) =>
                  _RecommendationCard(rec: e.value, index: e.key)),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _TotalSavingsCard extends StatelessWidget {
  final List<dynamic> recommendations;
  const _TotalSavingsCard({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    final total = recommendations.fold<double>(0, (acc, r) => acc + r.monthlyImpact);
    final yearly = total * 12;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pl.emerald.withValues(alpha: 0.15), pl.emerald.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pl.emerald.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('POTENTIAL TOTAL SAVINGS',
            style: TextStyle(color: pl.textMuted, fontSize: 10, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Text(fmt(total),
            style: TextStyle(color: pl.emerald, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
        Text('per month  ·  ${fmt(yearly)} per year',
            style: TextStyle(color: pl.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        const _ProgressRing(),
      ]),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing();
  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    return Row(children: [
      Icon(Icons.trending_up, color: pl.emerald, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text('Follow all 3 tips to reach your savings goal faster.',
            style: TextStyle(color: pl.textSecondary, fontSize: 12)),
      ),
    ]);
  }
}

class _RecommendationCard extends StatefulWidget {
  final dynamic rec;
  final int index;
  const _RecommendationCard({required this.rec, required this.index});
  @override State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  bool _expanded = false;
  bool _done     = false;

  static const _catIcons = {
    'subscriptions': Icons.subscriptions_outlined,
    'impulse':       Icons.shopping_bag_outlined,
    'budgeting':     Icons.account_balance_wallet_outlined,
    'savings':       Icons.savings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    final rec    = widget.rec;
    final color  = _recCategoryColor(rec.category, pl);
    final icon   = _catIcons[rec.category]  ?? Icons.lightbulb_outline;

    return AnimatedOpacity(
      opacity: _done ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: pl.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _done ? pl.border : color.withValues(alpha: 0.25)),
          ),
          child: Column(children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rec.title,
                      style: TextStyle(color: pl.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(children: [
                    DifficultyBadge(rec.difficulty),
                    const SizedBox(width: 6),
                    CategoryTag(rec.category),
                  ]),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('+${fmt(rec.monthlyImpact)}',
                      style: TextStyle(color: pl.emerald, fontWeight: FontWeight.w800, fontSize: 14)),
                  Text('/month', style: TextStyle(color: pl.textMuted, fontSize: 10)),
                ]),
              ]),
            ),

            // ── Expanded Detail ──────────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: pl.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(rec.description,
                        style: TextStyle(color: pl.textSecondary, fontSize: 13, height: 1.6)),
                  ),
                  const SizedBox(height: 12),
                  _AnnualImpactBar(monthlyImpact: rec.monthlyImpact, color: color),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _done = !_done),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _done ? pl.emeraldDim : pl.emerald,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(child: Text(
                          _done ? '✓ Done!' : 'Mark as Done',
                          style: TextStyle(
                            color: _done ? pl.emerald : pl.onEmerald,
                            fontWeight: FontWeight.w700, fontSize: 13,
                          ),
                        )),
                      ),
                    )),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AnnualImpactBar extends StatelessWidget {
  final double monthlyImpact;
  final Color color;
  const _AnnualImpactBar({required this.monthlyImpact, required this.color});

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    final yearly = monthlyImpact * 12;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Annual Impact', style: TextStyle(color: pl.textMuted, fontSize: 11)),
        Text(fmt(yearly), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value:            (yearly / 1000).clamp(0.05, 1.0),
          minHeight:        6,
          backgroundColor:  pl.border,
          valueColor:       AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }
}