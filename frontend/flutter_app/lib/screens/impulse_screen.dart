import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ImpulseScreen extends StatefulWidget {
  const ImpulseScreen({super.key});

  @override
  State<ImpulseScreen> createState() => _ImpulseScreenState();
}

class _ImpulseScreenState extends State<ImpulseScreen> {
  final _itemCtrl = TextEditingController(text: 'Wireless earbuds');
  final _priceCtrl = TextEditingController(text: '79');

  @override
  void dispose() {
    _itemCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _runCheck() {
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;
    final item = _itemCtrl.text.trim().isEmpty ? 'this purchase' : _itemCtrl.text.trim();
    context.read<ImpulseProvider>().check(item, price);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ImpulseProvider>(builder: (_, p, __) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Impulse Guard 🛡️',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Pause before you buy — see the tradeoff in real terms.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            TextField(
              controller: _itemCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _fieldDeco('What do you want to buy?'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _fieldDeco('Price (USD)'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                EmeraldButton(label: 'Analyze', loading: p.loading, onTap: _runCheck),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: p.loading ? null : () => context.read<ImpulseProvider>().reset(),
                  child: const Text('Clear', style: TextStyle(color: AppColors.textMuted)),
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (p.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.emerald),
                      SizedBox(height: 14),
                      Text('Talking to your AI coach…', style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              )
            else if (p.analysis != null)
              _AnalysisCard(a: p.analysis!),
          ],
        ),
      );
    });
  }

  InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emerald),
        ),
      );
}

class _AnalysisCard extends StatelessWidget {
  final dynamic a;
  const _AnalysisCard({required this.a});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VerdictBadge(a.verdict as String),
              const SizedBox(width: 10),
              Text('~${a.percentOfMonthly}% of monthly income',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Text(a.comparison as String,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, height: 1.4)),
          const SizedBox(height: 14),
          const Text('Perspective', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(a.emotionalInsight as String,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.55)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.emeraldDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_outlined, color: AppColors.emerald, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(a.alternative as String,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
