import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/models.dart';

/// Backend base URL (no trailing slash).
/// Physical device / another PC: `flutter run --dart-define=SMARTWALLET_API_URL=http://192.168.x.x:8000`
/// Default uses 127.0.0.1 so it matches `uvicorn --host 127.0.0.1` on the same machine.
String get apiRoot {
  const fromEnv = String.fromEnvironment('SMARTWALLET_API_URL', defaultValue: '');
  if (fromEnv.isNotEmpty) {
    return fromEnv.endsWith('/') ? fromEnv.substring(0, fromEnv.length - 1) : fromEnv;
  }
  if (kIsWeb) return 'http://127.0.0.1:8000';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8000';
    default:
      return 'http://127.0.0.1:8000';
  }
}

class ApiService {
  static String get apiRootValue => apiRoot;
  static String get _base => '$apiRoot/api';
  static int userId = 1;
  static String? userEmail;
  static String? userName;
  static String? accessToken;

  static Map<String, String> _hdr({bool jsonBody = false}) {
    final h = <String, String>{};
    if (jsonBody) h['Content-Type'] = 'application/json';
    final t = accessToken;
    if (t != null && t.trim().isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  // For screens that need direct URLs + headers (settings/debug).
  static Map<String, String> debugHeaders() => _hdr();

  static void setAccessToken(String? token) {
    accessToken = token?.trim().isEmpty == true ? null : token?.trim();
  }

  static int _coerceInt(dynamic v, [int fallback = 1]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  /// Loads the current user from `/api/auth/me` (JWT required when AUTH_ENABLED=true).
  static Future<bool> fetchProfile({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/auth/me'), headers: _hdr())
          .timeout(timeout);
      if (res.statusCode != 200) return false;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      userId = _coerceInt(j['id'], userId);
      userEmail = j['email'] as String?;
      userName = j['name'] as String?;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Two quick attempts help flaky emulators / slow Wi‑Fi right after login.
  static Future<bool> fetchProfileWithRetry({int attempts = 2}) async {
    for (var i = 0; i < attempts; i++) {
      if (await fetchProfile()) return true;
      if (i < attempts - 1) await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return false;
  }

  static Future<void> logout() async {
    setAccessToken(null);
    userEmail = null;
    userName = null;
    userId = 1;
  }

  // ── Chat ─────────────────────────────────────────────────────────────────
  /// Returns `(conversationId, null)` on success, or `(null, errorMessage)` on failure.
  static Future<(int?, String?)> createChatConversation({String title = 'Financial assistant'}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/chat/conversations'),
            headers: _hdr(jsonBody: true),
            body: jsonEncode({'title': title}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final id = j['id'] as int?;
        if (id != null) return (id, null);
        return (null, 'Invalid response from server');
      }
      if (res.statusCode == 401) {
        return (
          null,
          'API rejected the request (401). Use AUTH_ENABLED=false, or set ALLOW_ANONYMOUS_DEMO=true on the server.',
        );
      }
      final detail = _tryDetail(res.body);
      return (null, 'Chat failed (HTTP ${res.statusCode})${detail != null ? ': $detail' : ''}');
    } catch (e) {
      return (
        null,
        'Cannot reach the API at $apiRoot.\n\n'
        '1) Start the backend (from smartwallet-ai/backend):\n'
        '   python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000\n\n'
        '2) On a real phone, use your PC\'s LAN IP:\n'
        '   flutter run --dart-define=SMARTWALLET_API_URL=http://192.168.x.x:8000\n\n'
        '3) Android: HTTP to the dev API needs a full restart after manifest changes — stop the app and run `flutter run` again (not just hot reload).\n\n'
        '($e)',
      );
    }
  }

  static String? _tryDetail(String body) {
    try {
      final j = jsonDecode(body);
      if (j is! Map) return null;
      final d = j['detail'];
      if (d == null) return null;
      if (d is String) return d;
      if (d is List) {
        final parts = <String>[];
        for (final item in d) {
          if (item is Map && item['msg'] != null) {
            final loc = item['loc'];
            final where = loc is List && loc.length > 1 ? '${loc.last}: ' : '';
            parts.add('$where${item['msg']}');
          } else {
            parts.add(item.toString());
          }
        }
        return parts.join('; ');
      }
      return d.toString();
    } catch (_) {}
    return null;
  }

  static Future<List<ChatMessageRow>> fetchChatMessages(int conversationId) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_base/chat/conversations/$conversationId/messages'),
            headers: _hdr(),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final list = j['messages'] as List? ?? [];
      return list.map((e) => ChatMessageRow.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Assistant reply text, or error message for the UI.
  static Future<(String?, String?)> sendChatMessage(int conversationId, String content) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/chat/conversations/$conversationId/messages'),
            headers: _hdr(jsonBody: true),
            body: jsonEncode({'content': content}),
          )
          .timeout(const Duration(seconds: 90));
      if (res.statusCode != 200) {
        return (
          null,
          _tryDetail(res.body) ?? 'Request failed (HTTP ${res.statusCode})',
        );
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final asst = j['assistant'] as Map<String, dynamic>?;
      final text = (asst?['content'] as String?)?.trim();
      if (text == null || text.isEmpty) {
        return (null, 'The server returned an empty reply.');
      }
      return (text, null);
    } catch (e) {
      return (null, 'Network error: $e');
    }
  }

  // ── Transactions + Summary ─────────────────────────────────────────────
  static Future<SpendingSummary> fetchSummary() async {
    try {
      final uri = Uri.parse('$_base/transactions/summary/$userId');
      final res = await http.get(uri, headers: _hdr()).timeout(const Duration(seconds: 8));
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
            headers: _hdr(jsonBody: true),
            body: jsonEncode({
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
        return ImpulseAnalysis.fromApiResponse(data, item, price);
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
            headers: _hdr(jsonBody: true),
            body: jsonEncode({}),
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
        savings: savings > 0
            ? savings
            : merchants.skip(1).fold<double>(
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
            headers: _hdr(jsonBody: true),
            body: jsonEncode({'user_id': userId}),
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
      final res =
          await http.get(Uri.parse('$_base/budgets/$userId'), headers: _hdr()).timeout(const Duration(seconds: 8));
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
            Uri.parse('$_base/budgets/$userId/single'),
            headers: _hdr(jsonBody: true),
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
      final uri = Uri.parse('$_base/alerts/$userId')
          .replace(queryParameters: {'unread_only': unreadOnly.toString()});
      final res = await http.get(uri, headers: _hdr()).timeout(const Duration(seconds: 8));
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
      await http
          .post(Uri.parse('$_base/alerts/$userId/evaluate'), headers: _hdr())
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  static Future<void> markAlertRead(int id) async {
    try {
      await http
          .patch(Uri.parse('$_base/alerts/$userId/$id/read'), headers: _hdr())
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  static Future<CashFlowForecast?> fetchCashFlow() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/cashflow/$userId'), headers: _hdr())
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return CashFlowForecast.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> fetchPlaidLinked() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/plaid/status/$userId'), headers: _hdr())
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['linked'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> createPlaidLinkToken() async {
    try {
      String? pkg;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          pkg = (await PackageInfo.fromPlatform()).packageName;
        } catch (_) {}
      }
      final res = await http
          .post(
            Uri.parse('$_base/plaid/link-token'),
            headers: _hdr(jsonBody: true),
            body: jsonEncode({
              if (pkg != null && pkg.trim().isNotEmpty) 'android_package_name': pkg.trim(),
            }),
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
            headers: _hdr(jsonBody: true),
            body: jsonEncode({'public_token': publicToken}),
          )
          .timeout(const Duration(seconds: 30));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> syncPlaid() async {
    try {
      final res = await http
          .post(Uri.parse('$_base/plaid/sync/$userId'), headers: _hdr())
          .timeout(const Duration(seconds: 60));
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
            headers: _hdr(jsonBody: true),
            body: jsonEncode({
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

  static Future<List<String>> fetchExpenseCategories() async {
    try {
      final res =
          await http.get(Uri.parse('$_base/transactions/categories'), headers: _hdr()).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final list = j['categories'] as List? ?? [];
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addManualExpense({
    required double amount,
    required String merchant,
    String? category,
    String? notes,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/transactions/$userId/manual'),
            headers: _hdr(jsonBody: true),
            body: jsonEncode({
              'amount': amount,
              'merchant': merchant,
              if (category != null && category.isNotEmpty) 'category': category,
              if (notes != null && notes.isNotEmpty) 'notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchTransactionHistory({int days = 90, int limit = 200}) async {
    try {
      final uri = Uri.parse('$_base/transactions/$userId/history').replace(
        queryParameters: {'days': '$days', 'limit': '$limit', 'offset': '0'},
      );
      final res = await http.get(uri, headers: _hdr()).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final list = j['transactions'] as List? ?? [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> updateTransactionCategory(int transactionId, String category) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_base/transactions/$userId/$transactionId/category'),
            headers: _hdr(jsonBody: true),
            body: jsonEncode({'category': category}),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> fetchSpendingAnalytics({int days = 90}) async {
    try {
      final uri = Uri.parse('$_base/transactions/$userId/analytics').replace(queryParameters: {'days': '$days'});
      final res = await http.get(uri, headers: _hdr()).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSavingsGoals() async {
    try {
      final res = await http.get(Uri.parse('$_base/savings-goals/$userId'), headers: _hdr()).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final list = j['goals'] as List? ?? [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> createSavingsGoal({
    required String name,
    required double target,
    double saved = 0,
    int? iconCodePoint,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/savings-goals/$userId'),
            headers: _hdr(jsonBody: true),
            body: jsonEncode({
              'name': name,
              'target_amount': target,
              'saved_amount': saved,
              if (iconCodePoint != null) 'icon_code_point': iconCodePoint,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> updateSavingsGoal(int goalId, {double? savedAmount, double? targetAmount, String? name}) async {
    try {
      final body = <String, dynamic>{};
      if (savedAmount != null) body['saved_amount'] = savedAmount;
      if (targetAmount != null) body['target_amount'] = targetAmount;
      if (name != null) body['name'] = name;
      final res = await http
          .patch(
            Uri.parse('$_base/savings-goals/$userId/$goalId'),
            headers: _hdr(jsonBody: true),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteSavingsGoal(int goalId) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base/savings-goals/$userId/$goalId'), headers: _hdr())
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
