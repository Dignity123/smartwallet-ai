import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';

/// Persists dark vs light `ThemeMode` for [MaterialApp].
class ThemeModeNotifier extends ChangeNotifier {
  static const _kDark = 'smartwallet_dark_mode';
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get themeMode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool(_kDark) ?? true;
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setDarkMode(bool dark) async {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDark, dark);
  }
}

/// Free vs **SmartWallet Premium**: AI Financial Coach chat, unlimited “Can I afford this?” checks.
///
/// Persists premium flag and monthly impulse check usage for the free tier (resets each calendar month).
class EntitlementsNotifier extends ChangeNotifier {
  static const _kPremium = 'smartwallet_entitlement_premium';
  static const _kYm = 'smartwallet_impulse_checks_ym';
  static const _kCount = 'smartwallet_impulse_checks_count';

  /// Free tier: impulse analyses per calendar month.
  static const int freeImpulseChecksPerMonth = 5;

  bool isPremium = false;
  int _impulseChecksUsedThisMonth = 0;
  String _bucketYm = '';

  bool get canRunImpulseCheck =>
      isPremium || _impulseChecksUsedThisMonth < freeImpulseChecksPerMonth;

  /// `-1` means unlimited (premium).
  int get remainingFreeImpulseChecks =>
      isPremium ? -1 : (freeImpulseChecksPerMonth - _impulseChecksUsedThisMonth).clamp(0, freeImpulseChecksPerMonth);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isPremium = prefs.getBool(_kPremium) ?? false;
    final now = DateTime.now();
    final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final savedYm = prefs.getString(_kYm);
    if (savedYm != ym) {
      _impulseChecksUsedThisMonth = 0;
      _bucketYm = ym;
      await prefs.setString(_kYm, ym);
      await prefs.setInt(_kCount, 0);
    } else {
      _bucketYm = ym;
      _impulseChecksUsedThisMonth = prefs.getInt(_kCount) ?? 0;
    }
    notifyListeners();
  }

  Future<void> setPremium(bool value) async {
    isPremium = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPremium, value);
  }

  /// Call after a successful impulse analysis. No-op if already premium.
  Future<void> recordImpulseCheckConsumed() async {
    if (isPremium) return;
    final prefs = await SharedPreferences.getInstance();
    _impulseChecksUsedThisMonth++;
    await prefs.setInt(_kCount, _impulseChecksUsedThisMonth);
    await prefs.setString(_kYm, _bucketYm);
    notifyListeners();
  }
}

/// Profile hydrate for greeting/settings. No login UI — API uses demo user id 1 when
/// the backend has `ALLOW_ANONYMOUS_DEMO=true` (default) and no Bearer token.
class AuthProvider extends ChangeNotifier {
  bool bootstrapping = true;
  String? email;
  String? name;
  int? userId;
  String? error;

  Future<void> bootstrap() async {
    bootstrapping = true;
    notifyListeners();
    try {
      ApiService.setAccessToken(null);
      ApiService.userId = 1;
      await ApiService.fetchProfileWithRetry();
      email = ApiService.userEmail;
      name = ApiService.userName;
      userId = ApiService.userId;
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      bootstrapping = false;
      notifyListeners();
    }
  }
}

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
  /// Last loaded transaction rows for Subs / category overview.
  List<Map<String, dynamic>> transactions = [];
  bool loading = false;

  /// Loads transaction history and runs subscription / recurring scan for the Subs tab.
  Future<void> refreshAll() async {
    loading = true;
    notifyListeners();
    try {
      final tx = await ApiService.fetchTransactionHistory(days: 90, limit: 500);
      final s = await ApiService.scanSubscriptions();
      transactions = tx;
      scan = s;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> scanNow() => refreshAll();
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

// ── Plan (alerts, Plaid, cash flow) ─────────────────────────────────────────
class PlanProvider extends ChangeNotifier {
  List<SmartAlert> alerts = [];
  CashFlowForecast? cashflow;
  bool plaidLinked = false;
  String? lastLinkToken;
  bool loading = false;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
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

  Future<bool> linkPlaidViaPublicToken(String publicToken) async {
    loading = true;
    notifyListeners();
    final ok = await ApiService.exchangePlaidPublicToken(publicToken.trim());
    if (ok) {
      plaidLinked = true;
      await ApiService.syncPlaid();
      await refresh();
    }
    loading = false;
    notifyListeners();
    return ok;
  }

  Future<void> dismissAlert(int id) async {
    await ApiService.markAlertRead(id);
    alerts = await ApiService.fetchAlerts();
    notifyListeners();
  }
}