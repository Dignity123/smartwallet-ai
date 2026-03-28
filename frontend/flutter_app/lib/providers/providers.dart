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