import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:intl/intl.dart';

final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
String fmt(double v) => _currencyFmt.format(v);

// ── Stat Card ────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? accent;

  const StatCard({super.key, required this.label, required this.value, this.sub, this.accent});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent?.withValues(alpha: 0.3) ?? p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(color: p.textMuted, fontSize: 10, letterSpacing: 1.0)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(color: accent ?? p.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!, style: TextStyle(color: p.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(color: p.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              if (subtitle != null)
                Text(subtitle!, style: TextStyle(color: p.textMuted, fontSize: 13)),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

// ── Emerald Button ────────────────────────────────────────────────────────────
class EmeraldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool small;

  const EmeraldButton({super.key, required this.label, this.onTap, this.loading = false, this.small = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: small
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: loading ? p.emerald.withValues(alpha: 0.4) : p.emerald,
          borderRadius: BorderRadius.circular(10),
        ),
        child: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: p.onEmerald),
              )
            : Text(label,
                style: TextStyle(
                    color: p.onEmerald,
                    fontWeight: FontWeight.w700,
                    fontSize: small ? 12 : 14)),
      ),
    );
  }
}

// ── Verdict Badge ─────────────────────────────────────────────────────────────
class VerdictBadge extends StatelessWidget {
  final String verdict;
  const VerdictBadge(this.verdict, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = verdict == 'buy_now'
        ? p.emerald
        : verdict == 'wait'
            ? p.warning
            : p.danger;
    final label = verdict.replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
    );
  }
}

// ── Difficulty Badge ──────────────────────────────────────────────────────────
class DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const DifficultyBadge(this.difficulty, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = difficulty == 'easy'
        ? p.emerald
        : difficulty == 'medium'
            ? p.warning
            : p.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(difficulty.toUpperCase(),
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }
}

// ── Category Tag ──────────────────────────────────────────────────────────────
class CategoryTag extends StatelessWidget {
  final String label;
  const CategoryTag(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(color: p.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
