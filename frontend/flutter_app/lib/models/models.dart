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
    percentOfIncome:(j['percent_of_income']as num).toDouble(),
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

  ImpulseAnalysis({
    required this.regretScore, required this.verdict, required this.comparison,
    required this.emotionalInsight, required this.alternative, required this.percentOfMonthly,
  });

  factory ImpulseAnalysis.fromJson(Map<String, dynamic> j) => ImpulseAnalysis(
    regretScore:      j['regret_score'] ?? 0,
    verdict:          j['verdict']          ?? 'wait',
    comparison:       j['comparison']       ?? '',
    emotionalInsight: j['emotional_insight']?? '',
    alternative:      j['alternative']      ?? '',
    percentOfMonthly: j['percentage_of_monthly']?.toString() ?? '0',
  );

  factory ImpulseAnalysis.demo(String item, double price) => ImpulseAnalysis(
    regretScore:      72,
    verdict:          'wait',
    comparison:       '3 weeks of groceries',
    emotionalInsight: 'Purchases made under excitement often lose appeal within 48 hours.',
    alternative:      'Wait 72 hours. If you still want it, buy guilt-free.',
    percentOfMonthly: '4.3',
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