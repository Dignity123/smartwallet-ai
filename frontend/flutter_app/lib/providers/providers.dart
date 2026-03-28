import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

// ── Dashboard Provider ───────────────────────────────────────────────────────
class DashboardProvider extends ChangeNotifier {
  SpendingSummary? summary;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error   = null;
    notifyListeners();
    try {
      summary = await ApiService.fetchSummary();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

// ── Impulse Provider ─────────────────────────────────────────────────────────
class ImpulseProvider extends ChangeNotifier {
  ImpulseAnalysis? analysis;
  bool loading = false;

  Future<void> check(String item, double price) async {
    loading  = true;
    analysis = null;
    notifyListeners();
    analysis = await ApiService.checkImpulse(item, price);
    loading  = false;
    notifyListeners();
  }

  void reset() {
    analysis = null;
    notifyListeners();
  }
}

// ── Subscription Provider ────────────────────────────────────────────────────
class SubscriptionProvider extends ChangeNotifier {
  SubscriptionScan? scan;
  bool loading = false;

  Future<void> scanNow() async {
    loading = true;
    scan    = null;
    notifyListeners();
    scan    = await ApiService.scanSubscriptions();
    loading = false;
    notifyListeners();
  }
}

// ── Recommendations Provider ─────────────────────────────────────────────────
class RecommendationsProvider extends ChangeNotifier {
  List<Recommendation> recommendations = [];
  bool loading = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    recommendations = await ApiService.fetchRecommendations();
    loading = false;
    notifyListeners();
  }
}

// ── Plan (budgets, alerts, Plaid, cash flow) ────────────────────────────────
class PlanProvider extends ChangeNotifier {
  List<BudgetGoalProgress> budgets = [];
  List<SmartAlert> alerts = [];
  CashFlowForecast? cashflow;
  bool plaidLinked = false;
  String? lastLinkToken;
  bool loading = false;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    budgets = await ApiService.fetchBudgets();
    alerts = await ApiService.fetchAlerts();
    cashflow = await ApiService.fetchCashFlow();
    plaidLinked = await ApiService.fetchPlaidLinked();
    loading = false;
    notifyListeners();
  }

  Future<void> runAlertChecks() async {
    await ApiService.evaluateAlerts();
    alerts = await ApiService.fetchAlerts();
    notifyListeners();
  }

  Future<bool> addBudget(String category, double limit) async {
    final ok = await ApiService.addBudgetGoal(category, limit);
    if (ok) await refresh();
    return ok;
  }

  Future<String?> requestPlaidLink() async {
    lastLinkToken = await ApiService.createPlaidLinkToken();
    notifyListeners();
    return lastLinkToken;
  }

  Future<bool> submitPlaidToken(String token) async {
    final ok = await ApiService.exchangePlaidPublicToken(token.trim());
    if (ok) {
      plaidLinked = true;
      await ApiService.syncPlaid();
      await refresh();
    }
    notifyListeners();
    return ok;
  }

  Future<void> dismissAlert(int id) async {
    await ApiService.markAlertRead(id);
    alerts = await ApiService.fetchAlerts();
    notifyListeners();
  }
}