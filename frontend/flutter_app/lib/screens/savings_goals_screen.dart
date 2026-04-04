import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme.dart';

class _Goal {
  _Goal({
    required this.name,
    required this.icon,
    required this.saved,
    required this.target,
    this.serverId,
  });

  final String name;
  final IconData icon;
  double saved;
  final double target;
  final int? serverId;

  double get pct => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);
  double get remaining => (target - saved).clamp(0.0, target);

  Map<String, dynamic> toJson() => {
        'name': name,
        'iconCodePoint': icon.codePoint,
        'saved': saved,
        'target': target,
        if (serverId != null) 'serverId': serverId,
      };

  static _Goal? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final name = json['name'] as String?;
    final iconCode = json['iconCodePoint'];
    final sid = json['serverId'] as int? ?? (json['serverId'] as num?)?.toInt();
    final savedRaw = json['saved'];
    final targetRaw = json['target'];
    final saved = savedRaw is num ? savedRaw.toDouble() : double.tryParse('$savedRaw');
    final target = targetRaw is num ? targetRaw.toDouble() : double.tryParse('$targetRaw');
    if (name == null || name.isEmpty || saved == null || target == null) return null;
    final code = iconCode is int ? iconCode : (iconCode as num?)?.toInt();
    if (code == null) return null;
    return _Goal(
      name: name,
      icon: IconData(code, fontFamily: 'MaterialIcons'),
      saved: saved,
      target: target,
      serverId: sid,
    );
  }

  static _Goal? fromApi(Map<String, dynamic> m) {
    final name = m['name'] as String? ?? '';
    if (name.isEmpty) return null;
    final target = (m['target_amount'] as num?)?.toDouble() ?? 0;
    final saved = (m['saved_amount'] as num?)?.toDouble() ?? 0;
    final id = m['id'] as int? ?? (m['id'] as num?)?.toInt();
    final iconCode = m['icon_code_point'] as int? ?? (m['icon_code_point'] as num?)?.toInt();
    final icon = iconCode != null ? IconData(iconCode, fontFamily: 'MaterialIcons') : Icons.savings_rounded;
    return _Goal(name: name, icon: icon, saved: saved, target: target, serverId: id);
  }
}

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  static final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static const _prefsKey = 'savings_goals_state_v1';

  double _smartWalletCredits = 223.99;
  List<_Goal> _goals = _defaultGoals();
  bool _loaded = false;
  bool _apiMode = false;

  static List<_Goal> _defaultGoals() => [
        _Goal(name: 'Vacation Fund', icon: Icons.flight_takeoff_rounded, saved: 347, target: 2000),
        _Goal(name: 'Emergency Fund', icon: Icons.savings_rounded, saved: 1250, target: 5000),
        _Goal(name: 'New Laptop', icon: Icons.laptop_mac_rounded, saved: 480, target: 1500),
      ];

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_prefsKey);
    if (!mounted) return;
    if (raw == null || raw.isEmpty) {
      setState(() => _loaded = true);
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        setState(() => _loaded = true);
        return;
      }
      final map = Map<String, dynamic>.from(decoded);
      final creditsRaw = map['smartWalletCredits'] ?? map['frictionCredits'];
      final credits = creditsRaw is num ? creditsRaw.toDouble() : double.tryParse('$creditsRaw');
      final listRaw = map['goals'];
      if (credits == null || listRaw is! List) {
        setState(() => _loaded = true);
        return;
      }
      final list = listRaw;
      final goals = <_Goal>[];
      for (final item in list) {
        final g = _Goal.fromJson(item);
        if (g != null) goals.add(g);
      }
      setState(() {
        _smartWalletCredits = credits;
        _goals = goals;
        _loaded = true;
      });
    } catch (_) {
      setState(() => _loaded = true);
    }
  }

  Future<void> _persist() async {
    if (_apiMode) return;
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'smartWalletCredits': _smartWalletCredits,
      'goals': _goals.map((g) => g.toJson()).toList(),
    };
    await prefs.setString(_prefsKey, jsonEncode(payload));
  }

  Future<void> _fundGoal(int index) async {
    final g = _goals[index];
    if (g.remaining <= 0 || _smartWalletCredits <= 0) return;
    final add = _smartWalletCredits.clamp(0.0, g.remaining);
    if (_apiMode && g.serverId != null) {
      final ok = await ApiService.updateSavingsGoal(g.serverId!, savedAmount: g.saved + add);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update goal'), behavior: SnackBarBehavior.floating),
        );
        return;
      }
      setState(() {
        _smartWalletCredits -= add;
        g.saved += add;
      });
      return;
    }
    setState(() {
      _smartWalletCredits -= add;
      g.saved += add;
    });
    await _persist();
    if (!mounted) return;
    final pl = context.palette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${_currency.format(add)} in SmartWallet credits to ${g.name}.'),
        backgroundColor: pl.surfaceAlt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteGoal(int index) async {
    if (index < 0 || index >= _goals.length) return;
    final g = _goals[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final pl = ctx.palette;
        return AlertDialog(
          backgroundColor: pl.surfaceAlt,
          title: Text('Delete goal?', style: TextStyle(color: pl.textPrimary)),
          content: Text(
            'Remove "${g.name}"? Saved progress (${_currency.format(g.saved)}) returns to available SmartWallet credits.',
            style: TextStyle(color: pl.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: pl.danger, foregroundColor: pl.textPrimary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    if (_apiMode && g.serverId != null) {
      final del = await ApiService.deleteSavingsGoal(g.serverId!);
      if (!mounted) return;
      if (!del) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete'), behavior: SnackBarBehavior.floating),
        );
        return;
      }
    }
    setState(() {
      if (!_apiMode) _smartWalletCredits += g.saved;
      _goals.removeAt(index);
    });
    await _persist();
    if (!mounted) return;
    final pl2 = context.palette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${g.name} removed.'),
        backgroundColor: pl2.surfaceAlt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _newGoal() async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final pl = ctx.palette;
        return AlertDialog(
          backgroundColor: pl.surfaceAlt,
          title: Text('New savings goal', style: TextStyle(color: pl.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: pl.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Goal name',
                  labelStyle: TextStyle(color: pl.textMuted),
                ),
              ),
              TextField(
                controller: targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: TextStyle(color: pl.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Target (\$)',
                  labelStyle: TextStyle(color: pl.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: pl.emerald, foregroundColor: pl.onEmerald),
              onPressed: () async {
              final name = nameCtrl.text.trim();
              final t = double.tryParse(targetCtrl.text);
              if (name.isEmpty || t == null || t <= 0) return;
              if (_apiMode) {
                final created = await ApiService.createSavingsGoal(name: name, target: t, iconCodePoint: Icons.flag_rounded.codePoint);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                if (created != null) {
                  final g = _Goal.fromApi(created);
                  if (g != null) setState(() => _goals.insert(0, g));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not create goal'), behavior: SnackBarBehavior.floating),
                  );
                }
                return;
              }
              setState(() {
                _goals.add(_Goal(name: name, icon: Icons.flag_rounded, saved: 0, target: t));
              });
              Navigator.pop(ctx);
              await _persist();
            },
            child: const Text('Add'),
          ),
          ],
        );
      },
    );
    nameCtrl.dispose();
    targetCtrl.dispose();
  }

  Future<void> _addSmartWalletCredits() async {
    final amountCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final pl = ctx.palette;
        return AlertDialog(
          backgroundColor: pl.surfaceAlt,
          title: Text('Add money', style: TextStyle(color: pl.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Top up SmartWallet credits so you can fund goals. (Local demo — not a real payment.)',
                style: TextStyle(color: pl.textSecondary, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                autofocus: true,
                style: TextStyle(color: pl.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Amount (\$)',
                  labelStyle: TextStyle(color: pl.textMuted),
                  prefixText: '\$ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: pl.emerald, foregroundColor: pl.onEmerald),
              onPressed: () async {
                final a = double.tryParse(amountCtrl.text);
                if (a == null || a <= 0) return;
                Navigator.pop(ctx);
                setState(() => _smartWalletCredits += a);
                await _persist();
                if (!mounted) return;
                final pal = context.palette;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added ${_currency.format(a)} to SmartWallet credits.'),
                    backgroundColor: pal.surfaceAlt,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    amountCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    if (!_loaded) {
      return Center(child: CircularProgressIndicator(color: pl.emerald));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Savings Goals',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: pl.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fund your goals with SmartWallet credits',
                    style: TextStyle(color: pl.textSecondary.withValues(alpha: 0.95), fontSize: 14),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: pl.emerald,
                foregroundColor: pl.onEmerald,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _newGoal,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('New Goal', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                pl.surfaceAlt,
                pl.surfaceAlt.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: pl.emerald.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: pl.emerald.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: pl.emeraldDim,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bolt_rounded, color: pl.emerald, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AVAILABLE SMARTWALLET CREDITS',
                      style: TextStyle(
                        color: pl.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      _currency.format(_smartWalletCredits),
                      style: TextStyle(
                        color: pl.emerald,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: pl.emeraldDim,
                      foregroundColor: pl.emerald,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _addSmartWalletCredits,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add money', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        ..._goals.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _GoalCard(
                goal: e.value,
                currency: _currency,
                onFund: () => _fundGoal(e.key),
                onDelete: () => _deleteGoal(e.key),
                canFund: _smartWalletCredits > 0 && e.value.remaining > 0,
              ),
            )),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.currency,
    required this.onFund,
    required this.onDelete,
    required this.canFund,
  });

  final _Goal goal;
  final NumberFormat currency;
  final VoidCallback onFund;
  final VoidCallback onDelete;
  final bool canFund;

  @override
  Widget build(BuildContext context) {
    final pl = context.palette;
    final pctInt = (goal.pct * 100).round().clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pl.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pl.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pl.emeraldDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(goal.icon, color: pl.emerald, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  goal.name,
                  style: TextStyle(
                    color: pl.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              Text(
                '$pctInt%',
                style: TextStyle(color: pl.emerald, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              IconButton(
                tooltip: 'Delete goal',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(Icons.delete_outline_rounded, color: pl.danger, size: 22),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${currency.format(goal.saved)} of ${currency.format(goal.target)}',
            style: TextStyle(color: pl.textSecondary.withValues(alpha: 0.95), fontSize: 14),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal.pct,
              minHeight: 8,
              backgroundColor: pl.border,
              color: pl.emerald,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${currency.format(goal.remaining)} remaining',
            style: TextStyle(color: pl.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: pl.textPrimary,
                side: BorderSide(color: pl.textSecondary, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: canFund ? onFund : null,
              child: const Text('Fund with SmartWallet credits', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
