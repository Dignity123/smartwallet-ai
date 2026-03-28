import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Backend base URL. Android emulator cannot reach host `localhost`; use 10.0.2.2.
String get _apiRoot {
  if (kIsWeb) return 'http://localhost:8000';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8000';
    default:
      return 'http://localhost:8000';
  }
}

class ApiService {
  static String get _base => '$_apiRoot/api';
  static const _userId = 1;

  // ── Transactions + Summary ───────────────────────────────────────────────
  static Future<SpendingSummary> fetchSummary() async {
    try {
      final uri = Uri.parse('$_base/transactions/summary/$_userId');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return SpendingSummary.demo();

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final summary = data['summary'] as Map<String, dynamic>?;
      final balance = data['balance'] as Map<String, dynamic>?;
      if (summary == null || balance == null) return SpendingSummary.demo();

      final categories = (summary['by_category'] as List)
          .map((c) => CategorySpend.fromJson(c as Map<String, dynamic>))
          .toList();
      return SpendingSummary(
        totalSpend: (summary['total_spend'] as num).toDouble(),
        savingsRate: (summary['savings_rate'] as num).toDouble(),
        byCategory: categories,
        balance: AccountBalance.fromJson(balance),
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
            Uri.parse('$_base/impulse/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': _userId,
              'income': 3000.0,
              'item': item,
              'price': price,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        return ImpulseAnalysis.fromMessage(
          ImpulseAnalysis.demo(item, price),
          'Request failed (${res.statusCode}).',
        );
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final analysis = data['analysis'];
      if (analysis is Map<String, dynamic>) {
        return ImpulseAnalysis.fromJson(analysis);
      }
      final message = data['message'] as String? ?? '';
      final demo = ImpulseAnalysis.demo(item, price);
      return ImpulseAnalysis.fromMessage(demo, message);
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
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return SubscriptionScan.demo();

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final subs = (data['subscriptions'] as List)
          .map((s) => Subscription.fromJson(s as Map<String, dynamic>))
          .toList();

      final aiRaw = data['ai_analysis'];
      String insight = '';
      List<CancelCandidate> candidates = [];
      double wasted = 0;
      if (aiRaw is Map<String, dynamic>) {
        insight = aiRaw['insight'] as String? ?? '';
        final cc = aiRaw['cancel_candidates'] as List?;
        if (cc != null) {
          candidates = cc.map((e) => CancelCandidate.fromJson(e as Map<String, dynamic>)).toList();
        }
        wasted = (aiRaw['wasted_monthly'] as num?)?.toDouble() ?? 0;
      } else if (aiRaw is String) {
        insight = aiRaw;
      }
      final duplicates = (data['duplicates'] as List?) ?? [];
      if (candidates.isEmpty) {
        candidates = _duplicatesToCandidates(duplicates, subs);
      }
      if (wasted <= 0) {
        wasted = _estimateWastedFromDuplicates(duplicates, subs);
      }

      return SubscriptionScan(
        subscriptions: subs,
        totalMonthlyCost: (data['total_monthly_cost'] as num).toDouble(),
        wastedMonthly: wasted,
        insight: insight.isNotEmpty ? insight : 'Review overlapping services in the same category.',
        cancelCandidates: candidates,
      );
    } catch (_) {
      return SubscriptionScan.demo();
    }
  }

  static List<CancelCandidate> _duplicatesToCandidates(
    List<dynamic> duplicates,
    List<Subscription> subs,
  ) {
    final byMerchant = {for (final s in subs) s.merchant: s};
    final out = <CancelCandidate>[];
    for (final raw in duplicates) {
      final d = raw as Map<String, dynamic>;
      final merchants = (d['merchants'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final note = d['note'] as String? ?? 'Overlapping services';
      if (merchants.length < 2) continue;
      double savings = 0;
      for (var i = 1; i < merchants.length; i++) {
        final m = merchants[i];
        savings += byMerchant[m]?.amount ?? 0;
      }
      out.add(CancelCandidate(
        merchant: merchants.join(', '),
        reason: note,
        savings: savings > 0 ? savings : merchants.skip(1).fold<double>(
              0,
              (a, m) => a + (byMerchant[m]?.amount ?? 0),
            ),
      ));
    }
    return out;
  }

  static double _estimateWastedFromDuplicates(
    List<dynamic> duplicates,
    List<Subscription> subs,
  ) {
    final byMerchant = {for (final s in subs) s.merchant: s.amount};
    var total = 0.0;
    for (final raw in duplicates) {
      final d = raw as Map<String, dynamic>;
      final merchants = (d['merchants'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (merchants.length < 2) continue;
      for (var i = 1; i < merchants.length; i++) {
        total += byMerchant[merchants[i]] ?? 0;
      }
    }
    return total;
  }

  // ── Recommendations ──────────────────────────────────────────────────────
  static Future<List<Recommendation>> fetchRecommendations() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/recommendations/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': _userId}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return _fallbackRecommendations();

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rawRecs = data['recommendations'] as List?;
      if (rawRecs != null && rawRecs.isNotEmpty) {
        return rawRecs.map((e) => Recommendation.fromJson(e as Map<String, dynamic>)).toList();
      }
      final tips = data['tips'] as String? ?? '';
      final summary = data['summary'] as Map<String, dynamic>?;
      final totalSpend = (summary?['total_spend'] as num?)?.toDouble() ?? 0;

      if (tips.trim().isEmpty) return _fallbackRecommendations();

      return _tipsToRecommendations(tips, totalSpend);
    } catch (_) {
      return _fallbackRecommendations();
    }
  }

  static List<Recommendation> _tipsToRecommendations(String tips, double totalSpend) {
    final rough = (totalSpend * 0.05).clamp(15, 120).toDouble();
    final blocks = tips
        .split(RegExp(r'\n\s*\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (blocks.length <= 1) {
      final sentences = tips.split(RegExp(r'(?<=[.!?])\s+')).where((s) => s.trim().isNotEmpty).toList();
      if (sentences.length >= 2) {
        return List.generate(sentences.length.clamp(1, 4), (i) {
          final chunk = sentences[i].trim();
          return Recommendation(
            title: i == 0 ? 'AI insights' : 'Tip ${i + 1}',
            description: chunk,
            monthlyImpact: (rough / sentences.length.clamp(1, 4)).clamp(5, rough),
            difficulty: 'easy',
            category: i.isEven ? 'budgeting' : 'savings',
          );
        });
      }
      return [
        Recommendation(
          title: 'AI insights',
          description: tips.trim(),
          monthlyImpact: rough,
          difficulty: 'easy',
          category: 'budgeting',
        ),
      ];
    }
    return List.generate(blocks.length.clamp(1, 5), (i) {
      return Recommendation(
        title: 'Insight ${i + 1}',
        description: blocks[i],
        monthlyImpact: (rough / blocks.length).clamp(5, rough),
        difficulty: 'easy',
        category: 'budgeting',
      );
    });
  }

  static List<Recommendation> _fallbackRecommendations() => [
        Recommendation(
          title: 'Cut to One Streaming Service',
          description:
              'You have several streaming subscriptions. Dropping one you rarely use can add up over the year.',
          monthlyImpact: 18.98,
          difficulty: 'easy',
          category: 'subscriptions',
        ),
        Recommendation(
          title: 'Skip One Coffee Run per Week',
          description: 'Small recurring spends compound. Try one fewer discretionary purchase weekly.',
          monthlyImpact: 24.0,
          difficulty: 'easy',
          category: 'impulse',
        ),
        Recommendation(
          title: 'Route Savings to Emergency Fund',
          description: 'Redirect freed-up cash to savings before it gets spent elsewhere.',
          monthlyImpact: 43.0,
          difficulty: 'medium',
          category: 'savings',
        ),
      ];

  // ── Budgets & alerts & Plaid & cash flow ────────────────────────────────
  static Future<List<BudgetGoalProgress>> fetchBudgets() async {
    try {
      final res = await http.get(Uri.parse('$_base/budgets/$_userId')).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final goals = data['goals'] as List? ?? [];
      return goals.map((e) => BudgetGoalProgress.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> addBudgetGoal(String category, double limit) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/budgets/$_userId/single'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'category': category,
              'monthly_limit': limit,
              'alert_threshold_pct': 0.8,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<SmartAlert>> fetchAlerts({bool unreadOnly = false}) async {
    try {
      final uri = Uri.parse('$_base/alerts/$_userId')
          .replace(queryParameters: {'unread_only': unreadOnly.toString()});
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = data['alerts'] as List? ?? [];
      return list.map((e) => SmartAlert.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> evaluateAlerts() async {
    try {
      await http.post(Uri.parse('$_base/alerts/$_userId/evaluate')).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  static Future<void> markAlertRead(int id) async {
    try {
      await http
          .patch(Uri.parse('$_base/alerts/$_userId/$id/read'))
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  static Future<CashFlowForecast?> fetchCashFlow() async {
    try {
      final res = await http.get(Uri.parse('$_base/cashflow/$_userId')).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return CashFlowForecast.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> fetchPlaidLinked() async {
    try {
      final res = await http.get(Uri.parse('$_base/plaid/status/$_userId')).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['linked'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> createPlaidLinkToken() async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/plaid/link-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': _userId}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      return (jsonDecode(res.body) as Map<String, dynamic>)['link_token'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> exchangePlaidPublicToken(String publicToken) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/plaid/exchange'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': _userId, 'public_token': publicToken}),
          )
          .timeout(const Duration(seconds: 30));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> syncPlaid() async {
    try {
      final res = await http.post(Uri.parse('$_base/plaid/sync/$_userId')).timeout(const Duration(seconds: 60));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> markCancelIntent(String merchant, double amount) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/subscriptions/cancel-intent'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': _userId,
              'merchant': merchant,
              'amount_snapshot': amount,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
