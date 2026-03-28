import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool loading = true;
  bool authenticated = false;
  String? errorMessage;

  Future<void> bootstrap() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('access_token');
      if (saved != null && saved.isNotEmpty) {
        ApiService.accessToken = saved;
      }
      final me = await ApiService.fetchMe();
      if (me != null) {
        authenticated = true;
        final t = ApiService.accessToken;
        if (t != null && t.isNotEmpty) {
          await prefs.setString('access_token', t);
        }
      } else {
        authenticated = false;
        await prefs.remove('access_token');
        ApiService.clearSession();
      }
    } catch (e) {
      errorMessage = e.toString();
      authenticated = false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    errorMessage = null;
    final ok = await ApiService.loginEmail(email, password);
    if (!ok) {
      errorMessage = 'Invalid email or password';
      notifyListeners();
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final t = ApiService.accessToken;
    if (t != null && t.isNotEmpty) await prefs.setString('access_token', t);
    authenticated = true;
    notifyListeners();
    return true;
  }

  Future<bool> register(String email, String password, String name) async {
    errorMessage = null;
    final ok = await ApiService.registerEmail(email, password, name: name.isEmpty ? 'Member' : name);
    if (!ok) {
      errorMessage = 'Could not register (email may be taken)';
      notifyListeners();
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final t = ApiService.accessToken;
    if (t != null && t.isNotEmpty) await prefs.setString('access_token', t);
    authenticated = true;
    notifyListeners();
    return true;
  }

  Future<bool> signInWithGoogleToken(String idToken) async {
    errorMessage = null;
    final ok = await ApiService.loginWithGoogleIdToken(idToken);
    if (!ok) {
      errorMessage = 'Google sign-in failed. Check GOOGLE_CLIENT_ID on the server.';
      notifyListeners();
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final t = ApiService.accessToken;
    if (t != null && t.isNotEmpty) await prefs.setString('access_token', t);
    authenticated = true;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    ApiService.clearSession();
    authenticated = false;
    await bootstrap();
  }
}
