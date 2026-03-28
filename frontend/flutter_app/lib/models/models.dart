class AccountBalance {
  final double available;
  final double current;
  final String currency;

  AccountBalance({required this.available, required this.current, required this.currency});

  factory AccountBalance.fromJson(Map<String, dynamic> j) => AccountBalance(
    available: (j['available'] as num).toDouble(),
    current:   (j['current']   as num).toDouble(),
    currency:  j['currency'] ?? 'USD',
  );

  factory AccountBalance.demo() =>
      AccountBalance(available: 2340.50, current: 2890.00, currency: 'USD');
}

class CategorySpend {
  final String category;
  final double spent;
  final double benchmark;
  final bool overBudget;
  final double percentOfIncome;

  CategorySpend({
    required this.category, required this.spent, required this.benchmark,
    required this.overBudget, required this.percentOfIncome,
  });

  factory CategorySpend.fromJson(Map<String, dynamic> j) => CategorySpend(
    category:       j['category'],
    spent:          (j['spent']            as num).toDouble(),
    benchmark:      (j['benchmark']        as num).toDouble(),
    overBudget:     j['over_budget'] ?? false,
    percentOfIncome:(j['percent_of_income'] as num?)?.toDouble()
        ?? (j['percent_of_budget'] as num?)?.toDouble()
        ?? 0.0,
  );
}

class BudgetGoalProgress {
  final int id;
  final String category;
  final double monthlyLimit;
  final double spentThisMonth;
  final double percentUsed;
  final bool isOver;
  final bool isNearLimit;

  BudgetGoalProgress({
    required this.id,
    required this.category,
    required this.monthlyLimit,
    required this.spentThisMonth,
    required this.percentUsed,
    required this.isOver,
    required this.isNearLimit,
  });

  factory BudgetGoalProgress.fromJson(Map<String, dynamic> j) => BudgetGoalProgress(
    id: j['id'] as int,
    category: j['category'] as String,
    monthlyLimit: (j['monthly_limit'] as num).toDouble(),
    spentThisMonth: (j['spent_this_month'] as num).toDouble(),
    percentUsed: (j['percent_used'] as num).toDouble(),
    isOver: j['is_over'] as bool? ?? false,
    isNearLimit: j['is_near_limit'] as bool? ?? false,
  );
}

class SmartAlert {
  final int id;
  final String type;
  final String title;
  final String body;
  final bool isRead;

  SmartAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
  });

  factory SmartAlert.fromJson(Map<String, dynamic> j) => SmartAlert(
    id: j['id'] as int,
    type: j['type'] as String? ?? '',
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    isRead: j['is_read'] as bool? ?? false,
  );
}

class CashFlowForecast {
  final double recurring;
  final double variable;
  final double projectedSpend;
  final double available;
  final double projectedBalance30d;
  final String risk;

  CashFlowForecast({
    required this.recurring,
    required this.variable,
    required this.projectedSpend,
    required this.available,
    required this.projectedBalance30d,
    required this.risk,
  });

  factory CashFlowForecast.fromJson(Map<String, dynamic> j) => CashFlowForecast(
    recurring: (j['recurring_monthly_estimate'] as num).toDouble(),
    variable: (j['variable_monthly_estimate'] as num).toDouble(),
    projectedSpend: (j['projected_next_month_spend'] as num).toDouble(),
    available: (j['current_available_balance'] as num).toDouble(),
    projectedBalance30d: (j['projected_balance_in_30d'] as num).toDouble(),
    risk: j['overdraft_risk'] as String? ?? 'low',
  );
}

class SpendingSummary {
  final double totalSpend;
  final double savingsRate;
  final List<CategorySpend> byCategory;
  final AccountBalance balance;

  SpendingSummary({
    required this.totalSpend, required this.savingsRate,
    required this.byCategory, required this.balance,
  });

  factory SpendingSummary.demo() => SpendingSummary(
    totalSpend:  542.71,
    savingsRate: 81.9,
    balance:     AccountBalance.demo(),
    byCategory: [
      CategorySpend(category: 'Food & Drink', spent: 62.60,  benchmark: 450,  overBudget: false, percentOfIncome: 2.1),
      CategorySpend(category: 'Groceries',    spent: 87.34,  benchmark: 300,  overBudget: false, percentOfIncome: 2.9),
      CategorySpend(category: 'Entertainment',spent: 139.94, benchmark: 150,  overBudget: false, percentOfIncome: 4.7),
      CategorySpend(category: 'Shopping',     spent: 129.00, benchmark: 300,  overBudget: false, percentOfIncome: 4.3),
      CategorySpend(category: 'Software',     spent: 94.98,  benchmark: 90,   overBudget: true,  percentOfIncome: 3.2),
    ],
  );
}

class ImpulseAnalysis {
  final int regretScore;
  final String verdict;
  final String comparison;
  final String emotionalInsight;
  final String alternative;
  final String percentOfMonthly;
  /// Recent spending pattern summary from the API (e.g. shopping this week).
  final String? spendingSnapshot;

  ImpulseAnalysis({
    required this.regretScore, required this.verdict, required this.comparison,
    required this.emotionalInsight, required this.alternative, required this.percentOfMonthly,
    this.spendingSnapshot,
  });

  factory ImpulseAnalysis.fromJson(Map<String, dynamic> j) => ImpulseAnalysis(
    regretScore:      j['regret_score'] ?? 0,
    verdict:          j['verdict']          ?? 'wait',
    comparison:       j['comparison']       ?? '',
    emotionalInsight: j['emotional_insight']?? '',
    alternative:      j['alternative']      ?? '',
    percentOfMonthly: j['percentage_of_monthly']?.toString() ?? '0',
    spendingSnapshot: j['spending_snapshot'] as String?,
  );

  /// Full `/api/impulse/` payload: structured analysis + optional `spending_context`.
  factory ImpulseAnalysis.fromApiResponse(Map<String, dynamic> data, String item, double price) {
    final raw = data['analysis'];
    final Map<String, dynamic> aj = raw is Map<String, dynamic>
        ? raw
        : ImpulseAnalysis.demo(item, price).toJson();
    final base = ImpulseAnalysis.fromJson(aj);
    final ctx = data['spending_context'];
    String? snap;
    if (ctx is Map<String, dynamic>) {
      final parts = <String>[];
      final nar = (ctx['pattern_narrative'] as String?)?.trim();
      if (nar != null && nar.isNotEmpty) parts.add(nar);
      final shop = ctx['shopping_last_7_days'];
      final dine = ctx['dining_last_7_days'];
      if (shop is num && shop > 0) {
        parts.add('Shopping (last 7 days): \$${shop.toStringAsFixed(0)}');
      }
      if (dine is num && dine > 0) {
        parts.add('Dining (last 7 days): \$${dine.toStringAsFixed(0)}');
      }
      snap = parts.isEmpty ? null : parts.join(' · ');
    }
    return ImpulseAnalysis(
      regretScore: base.regretScore,
      verdict: base.verdict,
      comparison: base.comparison,
      emotionalInsight: base.emotionalInsight,
      alternative: base.alternative,
      percentOfMonthly: base.percentOfMonthly,
      spendingSnapshot: snap,
    );
  }

  Map<String, dynamic> toJson() => {
    'regret_score': regretScore,
    'verdict': verdict,
    'comparison': comparison,
    'emotional_insight': emotionalInsight,
    'alternative': alternative,
    'percentage_of_monthly': percentOfMonthly,
    'spending_snapshot': spendingSnapshot,
  };

  /// Map plain-text API response (`/api/impulse/`) onto the structured UI model.
  factory ImpulseAnalysis.fromMessage(ImpulseAnalysis demo, String message) {
    final trimmed = message.trim();
    final firstLine = trimmed.split('\n').map((s) => s.trim()).firstWhere(
          (s) => s.isNotEmpty,
          orElse: () => 'Financial perspective',
        );
    final pct = demo.percentOfMonthly;
    return ImpulseAnalysis(
      regretScore: 55,
      verdict: 'wait',
      comparison: firstLine.length > 120 ? '${firstLine.substring(0, 117)}…' : firstLine,
      emotionalInsight: trimmed,
      alternative: demo.alternative,
      percentOfMonthly: pct,
      spendingSnapshot: demo.spendingSnapshot,
    );
  }

  factory ImpulseAnalysis.demo(String item, double price) {
    const income = 3000.0;
    final pct = income > 0 ? (price / income * 100).toStringAsFixed(1) : '0';
    return ImpulseAnalysis(
      regretScore: 72,
      verdict: 'wait',
      comparison: 'About $pct% of your monthly income',
      emotionalInsight: 'Purchases made under excitement often lose appeal within 48 hours.',
      alternative: 'Wait 72 hours. If you still want it, buy guilt-free.',
      percentOfMonthly: pct,
      spendingSnapshot: null,
    );
  }
}

class ChatMessageRow {
  final int? id;
  final String role;
  final String content;

  ChatMessageRow({this.id, required this.role, required this.content});

  factory ChatMessageRow.fromJson(Map<String, dynamic> j) => ChatMessageRow(
    id: j['id'] as int?,
    role: j['role'] as String? ?? 'user',
    content: j['content'] as String? ?? '',
  );
}

class Subscription {
  final String merchant;
  final double amount;
  final String category;
  final String frequency;
  final bool isActive;

  Subscription({
    required this.merchant, required this.amount, required this.category,
    required this.frequency, required this.isActive,
  });

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
    merchant:  j['merchant'],
    amount:    (j['amount'] as num).toDouble(),
    category:  j['category'] ?? 'Other',
    frequency: j['frequency'] ?? 'monthly',
    isActive:  j['is_active'] ?? true,
  );
}

class CancelCandidate {
  final String merchant;
  final String reason;
  final double savings;

  CancelCandidate({required this.merchant, required this.reason, required this.savings});

  factory CancelCandidate.fromJson(Map<String, dynamic> j) => CancelCandidate(
    merchant: j['merchant'],
    reason:   j['reason'],
    savings:  (j['savings'] as num).toDouble(),
  );
}

class SubscriptionScan {
  final List<Subscription> subscriptions;
  final double totalMonthlyCost;
  final double wastedMonthly;
  final String insight;
  final List<CancelCandidate> cancelCandidates;

  SubscriptionScan({
    required this.subscriptions, required this.totalMonthlyCost,
    required this.wastedMonthly, required this.insight,
    required this.cancelCandidates,
  });

  factory SubscriptionScan.demo() => SubscriptionScan(
    totalMonthlyCost: 139.94,
    wastedMonthly:    18.98,
    insight:          "You're paying for 3 streaming services. Netflix alone covers 90% of your viewing.",
    subscriptions: [
      Subscription(merchant: 'Netflix',              amount: 15.99, category: 'Streaming',     frequency: 'monthly', isActive: true),
      Subscription(merchant: 'Hulu',                 amount: 12.99, category: 'Streaming',     frequency: 'monthly', isActive: true),
      Subscription(merchant: 'Peacock',              amount: 5.99,  category: 'Streaming',     frequency: 'monthly', isActive: true),
      Subscription(merchant: 'Spotify',              amount: 9.99,  category: 'Music',         frequency: 'monthly', isActive: true),
      Subscription(merchant: 'Adobe Creative Cloud', amount: 54.99, category: 'Software',      frequency: 'monthly', isActive: true),
      Subscription(merchant: 'LinkedIn Premium',     amount: 39.99, category: 'Professional',  frequency: 'monthly', isActive: true),
    ],
    cancelCandidates: [
      CancelCandidate(merchant: 'Peacock', reason: 'Rarely used, content available on Netflix', savings: 5.99),
      CancelCandidate(merchant: 'Hulu',   reason: 'Overlaps heavily with Netflix',              savings: 12.99),
    ],
  );
}

class Recommendation {
  final String title;
  final String description;
  final double monthlyImpact;
  final String difficulty;
  final String category;

  Recommendation({
    required this.title, required this.description, required this.monthlyImpact,
    required this.difficulty, required this.category,
  });

  factory Recommendation.fromJson(Map<String, dynamic> j) => Recommendation(
    title:         j['title'],
    description:   j['description'],
    monthlyImpact: (j['monthly_impact'] as num).toDouble(),
    difficulty:    j['difficulty'] ?? 'medium',
    category:      j['category']   ?? 'budgeting',
  );
}