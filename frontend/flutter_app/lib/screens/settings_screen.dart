import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../services/api_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = false;
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _plaid;
  String? _err;

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final meRes =
          await http.get(Uri.parse('${ApiService.apiRootValue}/api/auth/me'), headers: ApiService.debugHeaders());
      if (meRes.statusCode == 200) {
        _me = jsonDecode(meRes.body) as Map<String, dynamic>;
      }
      final uid = ApiService.userId;
      final plaidRes = await http.get(
        Uri.parse('${ApiService.apiRootValue}/api/plaid/status/$uid'),
        headers: ApiService.debugHeaders(),
      );
      if (plaidRes.statusCode == 200) {
        _plaid = jsonDecode(plaidRes.body) as Map<String, dynamic>;
      }
    } catch (e) {
      _err = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: p.surface,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: p.emerald,
        backgroundColor: p.surface,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _Card(
              title: 'Appearance',
              children: [
                Consumer<ThemeModeNotifier>(
                  builder: (_, theme, __) {
                    final p = context.palette;
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Dark mode', style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        theme.isDark ? 'Dark theme' : 'Light theme',
                        style: TextStyle(color: p.textMuted, fontSize: 12),
                      ),
                      value: theme.isDark,
                      activeThumbColor: p.emerald,
                      activeTrackColor: p.emerald.withValues(alpha: 0.35),
                      onChanged: (v) => theme.setDarkMode(v),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Card(
              title: 'SmartWallet Premium',
              children: [
                Text(
                  'Paid features that go beyond the free monthly “Can I afford this?” allowance.',
                  style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 14),
                _PremiumBullet(
                  icon: Icons.auto_awesome_rounded,
                  title: 'AI Financial Coach',
                  lines: const [
                    'Personalized spending advice',
                    'Detects patterns that hurt your plan',
                    'Weekly improvement tips',
                  ],
                  example:
                      '“You spend about 25% more on food on weekends. Try a simple weekend spending limit.”',
                  palette: p,
                ),
                const SizedBox(height: 12),
                _PremiumBullet(
                  icon: Icons.shield_moon_outlined,
                  title: 'Unlimited “Can I Afford This?” checks',
                  lines: const [
                    'Free: limited checks per month · Premium: unlimited',
                    'Purchase risk (regret) score',
                    'Budget impact & cash-flow style warnings',
                  ],
                  example:
                      '“Buying this today may increase overdraft risk in the next week or two — review timing.”',
                  palette: p,
                ),
                const SizedBox(height: 16),
                Consumer<EntitlementsNotifier>(
                  builder: (_, ent, __) {
                    final pl = context.palette;
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Premium unlocked (demo)',
                        style: TextStyle(color: pl.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        ent.isPremium
                            ? 'AI coach chat + unlimited impulse checks. Turn off to try the free tier.'
                            : 'Turn on to simulate a subscriber (persists on device).',
                        style: TextStyle(color: pl.textMuted, fontSize: 12),
                      ),
                      value: ent.isPremium,
                      activeThumbColor: pl.emerald,
                      activeTrackColor: pl.emerald.withValues(alpha: 0.35),
                      onChanged: (v) => ent.setPremium(v),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Card(
              title: 'Account',
              children: [
                _Row(label: 'Name', value: auth.name ?? '—'),
                _Row(label: 'Email', value: auth.email ?? '—'),
                _Row(label: 'User ID', value: (auth.userId ?? ApiService.userId).toString()),
              ],
            ),
            const SizedBox(height: 12),
            _Card(
              title: 'API',
              children: [
                _Row(label: 'Base URL', value: ApiService.apiRootValue),
                _Row(label: 'Auth token', value: ApiService.accessToken == null ? 'missing' : 'set'),
                _Row(label: '/auth/me', value: _me == null ? '—' : 'OK'),
              ],
            ),
            const SizedBox(height: 12),
            _Card(
              title: 'Plaid',
              children: [
                _Row(label: 'Configured', value: (_plaid?['plaid_configured'] == true) ? 'yes' : 'no'),
                _Row(label: 'Linked', value: (_plaid?['linked'] == true) ? 'yes' : 'no'),
                _Row(label: 'Items', value: (_plaid?['items'] ?? '—').toString()),
              ],
            ),
            if (_err != null) ...[
              const SizedBox(height: 12),
              Text(_err!, style: TextStyle(color: p.textMuted.withValues(alpha: 0.9), fontSize: 12)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.emerald,
                foregroundColor: p.onEmerald,
              ),
              onPressed: _loading ? null : _refresh,
              child: Text(_loading ? 'Refreshing…' : 'Refresh status'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _PremiumBullet extends StatelessWidget {
  const _PremiumBullet({
    required this.icon,
    required this.title,
    required this.lines,
    required this.example,
    required this.palette,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final String example;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: p.emerald, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('· ', style: TextStyle(color: p.textMuted, fontSize: 13)),
                  Expanded(
                    child: Text(s, style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.3)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Example',
            style: TextStyle(color: p.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6),
          ),
          const SizedBox(height: 4),
          Text(
            example,
            style: TextStyle(
              color: p.textPrimary.withValues(alpha: 0.92),
              fontSize: 13,
              height: 1.35,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: p.textMuted, fontSize: 12))),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: p.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

