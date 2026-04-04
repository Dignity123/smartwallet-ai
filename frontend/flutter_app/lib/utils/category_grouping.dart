/// One merchant’s rolled-up spend inside a category (e.g. all Netflix charges → one row).
class MerchantRollup {
  MerchantRollup({
    required this.merchant,
    required this.total,
    required this.count,
    required this.anyRecurring,
    required this.transactionIds,
  });

  final String merchant;
  final double total;
  final int count;
  final bool anyRecurring;
  final List<String> transactionIds;
}

/// Category block: Groceries $200, Rent, Netflix under Entertainment, etc.
class CategorySpendGroup {
  CategorySpendGroup({
    required this.category,
    required this.total,
    required this.merchants,
  });

  final String category;
  final double total;
  final List<MerchantRollup> merchants;
}

double _txnAmount(Map<String, dynamic> t) {
  final a = t['amount'];
  if (a is num) return a.abs().toDouble();
  return double.tryParse('$a')?.abs() ?? 0;
}

String _txnCategory(Map<String, dynamic> t) {
  final c = t['category']?.toString().trim();
  if (c == null || c.isEmpty) return 'Uncategorized';
  return c;
}

String _txnMerchant(Map<String, dynamic> t) {
  final m = t['merchant']?.toString().trim();
  if (m == null || m.isEmpty) return 'Unknown';
  return m;
}

bool _txnRecurring(Map<String, dynamic> t) {
  final r = t['is_recurring'];
  if (r is bool) return r;
  return r == true || r == 1 || r == 'true';
}

String _txnId(Map<String, dynamic> t) => '${t['id'] ?? ''}';

/// Groups all transactions by category, then rolls up merchants (sums + counts).
List<CategorySpendGroup> groupTransactionsByCategory(List<Map<String, dynamic>> transactions) {
  final byCat = <String, Map<String, _Agg>>{};

  for (final t in transactions) {
    final cat = _txnCategory(t);
    final mer = _txnMerchant(t);
    final amt = _txnAmount(t);
    final id = _txnId(t);
    final rec = _txnRecurring(t);

    byCat.putIfAbsent(cat, () => {});
    final m = byCat[cat]!.putIfAbsent(mer, () => _Agg());
    m.total += amt;
    m.count += 1;
    m.anyRecurring = m.anyRecurring || rec;
    if (id.isNotEmpty) m.ids.add(id);
  }

  final groups = <CategorySpendGroup>[];
  for (final e in byCat.entries) {
    final rollups = e.value.entries
        .map(
          (me) => MerchantRollup(
            merchant: me.key,
            total: me.value.total,
            count: me.value.count,
            anyRecurring: me.value.anyRecurring,
            transactionIds: me.value.ids.toList(),
          ),
        )
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final total = rollups.fold<double>(0, (s, r) => s + r.total);
    groups.add(CategorySpendGroup(category: e.key, total: total, merchants: rollups));
  }

  groups.sort((a, b) => b.total.compareTo(a.total));
  return groups;
}

/// Normalize merchant names from the subscription scan API for matching.
Set<String> subscriptionMerchantHints(Iterable<String> merchants) {
  return merchants.map((m) => m.trim().toLowerCase()).where((s) => s.isNotEmpty).toSet();
}

class _Agg {
  double total = 0;
  int count = 0;
  bool anyRecurring = false;
  final Set<String> ids = {};
}
