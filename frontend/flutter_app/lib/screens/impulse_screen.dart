import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import 'settings_screen.dart';

/// Impulse Buy Analysis — layout matches product mockup (dark cards, amber analyze, regret ring, impact, cooldown).
class ImpulseScreen extends StatefulWidget {
  const ImpulseScreen({super.key});

  @override
  State<ImpulseScreen> createState() => _ImpulseScreenState();
}

class _ImpulseScreenState extends State<ImpulseScreen> {
  static const _analyzeAmber = Color(0xFFFFB347);
  static const _riskRed = Color(0xFFFF4D4D);
  static const _impactGold = Color(0xFFE8C547);
  static const _cooldownSeconds = 30;

  final _itemCtrl = TextEditingController(text: 'headphones');
  final _priceCtrl = TextEditingController(text: '90');
  final _merchantCtrl = TextEditingController(text: 'Amazon');
  Timer? _debounce;
  bool _debounceEnabled = false;
  ImpulseProvider? _impulseListenTarget;
  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;
  ImpulseAnalysis? _cooldownForAnalysis;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _debounceEnabled = true);
      });
    });
    _itemCtrl.addListener(_scheduleDebouncedCheck);
    _priceCtrl.addListener(_scheduleDebouncedCheck);
    _merchantCtrl.addListener(_scheduleDebouncedCheck);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final impulse = context.read<ImpulseProvider>();
    if (!identical(_impulseListenTarget, impulse)) {
      _impulseListenTarget?.removeListener(_onImpulseForCooldown);
      _impulseListenTarget = impulse;
      impulse.addListener(_onImpulseForCooldown);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onImpulseForCooldown();
      });
    }
  }

  void _onImpulseForCooldown() {
    final prov = _impulseListenTarget;
    if (prov == null || !mounted) return;
    if (prov.analysis == null) {
      _cancelCooldownTimer();
      if (_cooldownRemaining != 0 || _cooldownForAnalysis != null) {
        setState(() {
          _cooldownRemaining = 0;
          _cooldownForAnalysis = null;
        });
      }
      return;
    }
    if (prov.loading) return;
    if (identical(prov.analysis, _cooldownForAnalysis)) return;
    _startCooldown(prov.analysis!);
  }

  void _cancelCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }

  void _startCooldown(ImpulseAnalysis analysis) {
    _cancelCooldownTimer();
    setState(() {
      _cooldownForAnalysis = analysis;
      _cooldownRemaining = _cooldownSeconds;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining--;
        if (_cooldownRemaining <= 0) {
          _cooldownRemaining = 0;
          t.cancel();
          _cooldownTimer = null;
        }
      });
    });
  }

  void _scheduleDebouncedCheck() {
    if (!_debounceEnabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      final price = double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;
      if (price <= 0) return;
      _runCheck();
    });
  }

  @override
  void dispose() {
    _impulseListenTarget?.removeListener(_onImpulseForCooldown);
    _cancelCooldownTimer();
    _debounce?.cancel();
    for (final c in [_itemCtrl, _priceCtrl, _merchantCtrl]) {
      c.removeListener(_scheduleDebouncedCheck);
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _showImpulseLimitReached(BuildContext context) async {
    final pal = context.palette;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.surfaceAlt,
        title: Text('Monthly limit reached', style: TextStyle(color: pal.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(
          'Free accounts get ${EntitlementsNotifier.freeImpulseChecksPerMonth} “Can I afford this?” checks per month. '
          'SmartWallet Premium includes unlimited checks, purchase risk scores, budget-impact context, and the AI Financial Coach.',
          style: TextStyle(color: pal.textSecondary, height: 1.4, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: pal.emerald, foregroundColor: pal.onEmerald),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
            },
            child: const Text('View Premium'),
          ),
        ],
      ),
    );
  }

  Future<void> _runCheck() async {
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;
    if (price <= 0) return;
    final ent = context.read<EntitlementsNotifier>();
    if (!ent.canRunImpulseCheck) {
      if (!mounted) return;
      await _showImpulseLimitReached(context);
      return;
    }
    final item = _itemCtrl.text.trim().isEmpty ? 'this purchase' : _itemCtrl.text.trim();
    final merchant = _merchantCtrl.text.trim();
    final desc = merchant.isEmpty ? item : '$item · $merchant';
    await context.read<ImpulseProvider>().check(desc, price);
    if (!mounted) return;
    if (context.read<ImpulseProvider>().analysis != null) {
      await ent.recordImpulseCheckConsumed();
    }
  }

  double _priceValue() => double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;

  int _goalDelayDays(double price) {
    const monthlyIncome = 3000.0;
    final daily = monthlyIncome / 30.0;
    if (daily <= 0) return 1;
    return (price / daily).round().clamp(1, 30);
  }

  String _riskLabel(int score) {
    if (score >= 70) return 'High Risk';
    if (score >= 45) return 'Moderate Risk';
    return 'Lower Risk';
  }

  Color _riskColor(int score, AppPalette pal) {
    if (score >= 70) return _riskRed;
    if (score >= 45) return _impactGold;
    return pal.emerald;
  }

  String _aiAnalysisBody(ImpulseAnalysis a) {
    final merged = '${a.emotionalInsight} ${a.comparison}'.trim();
    if (merged.isNotEmpty) return merged;
    return a.alternative.trim();
  }

  /// Matches UI risk bands: moderate (45+) and high (70+) → stronger proceed warning.
  bool _isHighImpulseRisk(ImpulseAnalysis a) => a.regretScore >= 45;

  InputDecoration _fieldDeco(String label, AppPalette pal) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: pal.textMuted, fontSize: 13),
        floatingLabelStyle: TextStyle(color: pal.textSecondary),
        hintStyle: TextStyle(color: pal.textMuted),
        filled: true,
        fillColor: pal.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pal.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pal.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pal.emerald, width: 1.2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Consumer<ImpulseProvider>(builder: (_, prov, __) {
      final pal = context.palette;
      final wide = MediaQuery.sizeOf(context).width >= 720;
      final price = _priceValue();
      final delayDays = _goalDelayDays(price > 0 ? price : 90);
      final analysis = prov.analysis;
      final score = analysis?.regretScore ?? 0;
      final riskColor = _riskColor(score, pal);

      Widget purchaseCard() => _ImpulseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_moon_outlined, color: pal.emerald.withValues(alpha: 0.9), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Purchase Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _itemCtrl,
                  style: TextStyle(color: pal.textPrimary),
                  decoration: _fieldDeco('What are you buying?', pal),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: pal.textPrimary),
                  decoration: _fieldDeco('Price (\$)', pal),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _merchantCtrl,
                  style: TextStyle(color: pal.textPrimary),
                  decoration: _fieldDeco('Merchant', pal),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _analyzeAmber,
                      foregroundColor: const Color(0xFF1A1206),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: prov.loading || price <= 0 ? null : _runCheck,
                    icon: prov.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1206)),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: Text(
                      prov.loading ? 'Analyzing…' : 'Analyze Purchase',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          );

      Widget regretCard() => _ImpulseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'REGRET PROBABILITY',
                    style: TextStyle(
                      color: pal.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (prov.loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: pal.emerald),
                  )
                else if (analysis == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Run an analysis to see your regret probability.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: pal.textMuted.withValues(alpha: 0.9), fontSize: 14),
                    ),
                  )
                else
                  _RegretRing(
                    score: score,
                    riskColor: riskColor,
                    riskLabel: _riskLabel(score),
                  ),
              ],
            ),
          );

      Widget impactCard() => _ImpulseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Impact',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: pal.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 16),
                if (prov.loading)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: pal.emerald)),
                  )
                else if (analysis == null)
                  Text(
                    'Impact appears after you analyze a purchase.',
                    style: TextStyle(color: pal.textMuted.withValues(alpha: 0.9), fontSize: 13),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.trending_down_rounded,
                          iconColor: _riskRed,
                          value: '\$${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}',
                          valueColor: _riskRed,
                          caption: 'Immediate cost',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.calendar_month_rounded,
                          iconColor: _impactGold,
                          value: '$delayDays days',
                          valueColor: _impactGold,
                          caption: 'Goal delayed',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: pal.emeraldDim,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: pal.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.track_changes_rounded, color: pal.emerald, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(color: pal.textSecondary, fontSize: 13, height: 1.4),
                              children: [
                                TextSpan(text: 'Buying this delays your '),
                                TextSpan(
                                  text: 'Vacation Fund',
                                  style: TextStyle(color: pal.textPrimary, fontWeight: FontWeight.w800),
                                ),
                                TextSpan(text: ' goal by '),
                                TextSpan(
                                  text: '$delayDays days',
                                  style: TextStyle(color: pal.emerald, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'AI ANALYSIS',
                    style: TextStyle(
                      color: pal.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _aiAnalysisBody(analysis),
                    style: TextStyle(color: pal.textSecondary, fontSize: 14, height: 1.5),
                  ),
                ],
              ],
            ),
          );

      Widget cooldownCard() => _ImpulseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined, color: pal.textSecondary.withValues(alpha: 0.95), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Cooldown Timer',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (analysis == null && !prov.loading)
                  Text(
                    'Analyze a purchase to see your cooldown status.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: pal.textMuted.withValues(alpha: 0.9), fontSize: 13),
                  )
                else if (prov.loading)
                  const SizedBox.shrink()
                else if (_cooldownForAnalysis == analysis && _cooldownRemaining > 0) ...[
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 132,
                          height: 132,
                          child: CircularProgressIndicator(
                            value: (_cooldownSeconds - _cooldownRemaining) / _cooldownSeconds,
                            strokeWidth: 7,
                            backgroundColor: pal.border.withValues(alpha: 0.45),
                            color: pal.emerald,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_cooldownRemaining',
                              style: TextStyle(
                                color: pal.textPrimary,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            Text(
                              'sec left',
                              style: TextStyle(
                                color: pal.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Take a breath — cooldown before you buy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: pal.textSecondary.withValues(alpha: 0.95), fontSize: 14, height: 1.35),
                  ),
                ]
                else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: pal.emeraldDim,
                      shape: BoxShape.circle,
                      border: Border.all(color: pal.emerald.withValues(alpha: 0.35)),
                    ),
                    child: Icon(Icons.check_rounded, color: pal.emerald, size: 36),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Cooldown Complete',
                    style: TextStyle(color: pal.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Still want to proceed?',
                    style: TextStyle(color: pal.textMuted.withValues(alpha: 0.95), fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: pal.textPrimary,
                            side: BorderSide(color: pal.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            context.read<ImpulseProvider>().reset();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Congratulations, you are on track with your monthly plan!',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Color(0xFF1E2A24),
                              ),
                            );
                          },
                          child: const Text('Cancel Purchase', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: pal.emerald,
                            foregroundColor: pal.onEmerald,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            final high = _isHighImpulseRisk(analysis!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  high
                                      ? 'High regret risk—Do not say I did not warn you.'
                                      : 'Lower risk—still align with your monthly plan and archive those goals.',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF1E2A24),
                              ),
                            );
                          },
                          child: const Text('Proceed Anyway', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );

      final scroll = SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        purchaseCard(),
                        const SizedBox(height: 16),
                        cooldownCard(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        regretCard(),
                        const SizedBox(height: 16),
                        impactCard(),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  purchaseCard(),
                  const SizedBox(height: 16),
                  regretCard(),
                  const SizedBox(height: 16),
                  impactCard(),
                  const SizedBox(height: 16),
                  cooldownCard(),
                ],
              ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impulse Buy Analysis',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: pal.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Review regret risk, impact on goals, and take a beat before you buy.',
                  style: TextStyle(color: pal.textMuted.withValues(alpha: 0.95), fontSize: 13, height: 1.35),
                ),
                Consumer<EntitlementsNotifier>(
                  builder: (_, ent, __) {
                    if (ent.isPremium) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: pal.emeraldDim,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: pal.emerald.withValues(alpha: 0.28)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, color: pal.emerald, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${ent.remainingFreeImpulseChecks} of ${EntitlementsNotifier.freeImpulseChecksPerMonth} free '
                                '“Can I afford this?” checks left this month. Premium: unlimited analyses + AI Financial Coach.',
                                style: TextStyle(color: pal.textSecondary, fontSize: 12, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(child: scroll),
        ],
      );
    });
  }
}

class _ImpulseCard extends StatelessWidget {
  const _ImpulseCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.valueColor,
    required this.caption,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final Color valueColor;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(caption, style: TextStyle(color: p.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RegretRing extends StatelessWidget {
  const _RegretRing({
    required this.score,
    required this.riskColor,
    required this.riskLabel,
  });

  final int score;
  final Color riskColor;
  final String riskLabel;

  @override
  Widget build(BuildContext context) {
    final s = score.clamp(0, 100);
    final p = context.palette;
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(200, 200),
            painter: _RegretRingPainter(
              progress: s / 100.0,
              riskColor: riskColor,
              trackColor: p.border,
              accentBlue: p.blue,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$s%',
                style: TextStyle(
                  color: riskColor,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                riskLabel,
                style: TextStyle(
                  color: riskColor.withValues(alpha: 0.95),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ring: mostly track + risk-colored arc; small leading blue accent (mock style).
class _RegretRingPainter extends CustomPainter {
  _RegretRingPainter({
    required this.progress,
    required this.riskColor,
    required this.trackColor,
    required this.accentBlue,
  });

  final double progress;
  final Color riskColor;
  final Color trackColor;
  final Color accentBlue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const stroke = 14.0;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);

    final accentSweep = 0.07 * 2 * math.pi;
    final start = -math.pi / 2;
    final accentPaint = Paint()
      ..color = accentBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      accentSweep,
      false,
      accentPaint,
    );

    final sweep = math.max(
      0.0,
      (progress.clamp(0.0, 1.0)) * 2 * math.pi - accentSweep * 0.5,
    );
    if (sweep > 0) {
      final riskPaint = Paint()
        ..color = riskColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + accentSweep * 0.6,
        sweep,
        false,
        riskPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RegretRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.riskColor != riskColor;
  }
}
