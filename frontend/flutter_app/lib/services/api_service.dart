import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const _base = 'http://localhost:8000/api';
  static const _userId = 1;

  // ── Transactions + Summary ───────────────────────────────────────────────
  static Future<SpendingSummary> fetchSummary() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/transactions/$_userId'))
          .timeout(const Duration(seconds: 6));
      final data = jsonDecode(res.body);
      final categories = (data['summary']['by_category'] as List)
          .map((c) => CategorySpend.fromJson(c))
          .toList();
      return SpendingSummary(
        totalSpend:  (data['summary']['total_spend']  as num).toDouble(),
        savingsRate: (data['summary']['savings_rate'] as num).toDouble(),
        byCategory:  categories,
        balance:     AccountBalance.fromJson(data['balance']),
      );
    } catch (_) {
      return SpendingSummary.demo();
    }
  }

  // ── Impulse Guard ────────────────────────────────────────────────────────
  static Future<ImpulseAnalysis> checkImpulse(String item, double price) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/impulse/check'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id':        _userId,
              'item_name':      item,
              'price':          price,
              'monthly_income': 3000,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      return ImpulseAnalysis.fromJson(data['analysis']);
    } catch (_) {
      return ImpulseAnalysis.demo(item, price);
    }
  }

  // ── Subscriptions ────────────────────────────────────────────────────────
  static Future<SubscriptionScan> scanSubscriptions() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/subscriptions/scan'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': _userId}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      final subs = (data['subscriptions'] as List)
          .map((s) => Subscription.fromJson(s))
          .toList();
      final candidates = (data['ai_analysis']['cancel_candidates'] as List? ?? [])
          .map((c) => CancelCandidate.fromJson(c))
          .toList();
      return SubscriptionScan(
        subscriptions:    subs,
        totalMonthlyCost: (data['total_monthly_cost'] as num).toDouble(),
        wastedMonthly:    (data['ai_analysis']['wasted_monthly'] as num? ?? 0).toDouble(),
        insight:          data['ai_analysis']['insight'] ?? '',
        cancelCandidates: candidates,
      );
    } catch (_) {
      return SubscriptionScan.demo();
    }
  }

  // ── Recommendations ──────────────────────────────────────────────────────
  static Future<List<Recommendation>> fetchRecommendations() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/recommendations/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': _userId, 'monthly_income': 3000}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      return (data['recommendations'] as List)
          .map((r) => Recommendation.fromJson(r))
          .toList();
    } catch (_) {
      return [
        Recommendation(
          title:         'Cut to One Streaming Service',
          description:   'You have 3 streaming subscriptions. Cancel Hulu and Peacock — Netflix covers 90% of your viewing.',
          monthlyImpact: 18.98,
          difficulty:    'easy',
          category:      'subscriptions',
        ),
        Recommendation(
          title:         'Skip One Starbucks Day / Week',
          description:   'You spend \$60+/month at coffee shops. Cutting one visit per week saves \$24 with minimal sacrifice.',
          monthlyImpact: 24.00,
          difficulty:    'easy',
          category:      'impulse',
        ),
        Recommendation(
          title:         'Route Savings to Emergency Fund',
          description:   'With \$43/month freed up, you\'d build a \$516 emergency cushion over the next year.',
          monthlyImpact: 43.00,
          difficulty:    'medium',
          category:      'savings',
        ),
      ];
    }
  }
}