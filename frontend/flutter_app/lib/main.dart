import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'providers/providers.dart';
import 'screens/dashboard_screen.dart';
import 'screens/impulse_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/savings_goals_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/analytics_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeNotifier = ThemeModeNotifier();
  await themeNotifier.load();
  final entitlements = EntitlementsNotifier();
  await entitlements.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeNotifier),
        ChangeNotifierProvider.value(value: entitlements),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => ImpulseProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => PlanProvider()),
      ],
      child: const SmartWalletApp(),
    ),
  );
}

class SmartWalletApp extends StatelessWidget {
  const SmartWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModeNotifier>(
      builder: (_, theme, __) => MaterialApp(
        title: 'Affordly AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: theme.themeMode,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(builder: (_, auth, __) {
      if (auth.bootstrapping) {
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
          ),
        );
      }
      return const MainShell();
    });
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  static const _screens = [
    DashboardScreen(),
    ImpulseScreen(),
    SubscriptionsScreen(),
    PlanScreen(),
    SavingsGoalsScreen(),
  ];

  static const _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), activeIcon: Icon(Icons.shield), label: 'Impulse'),
    BottomNavigationBarItem(icon: Icon(Icons.radar_outlined), activeIcon: Icon(Icons.radar), label: 'Subs'),
    BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Plan'),
    BottomNavigationBarItem(
        icon: Icon(Icons.track_changes_outlined),
        activeIcon: Icon(Icons.track_changes_rounded),
        label: 'Goals'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load data for default tab; profile is already hydrated via AuthProvider.
      await context.read<DashboardProvider>().load();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final p = context.palette;
    final nameOrEmail = auth.name ?? auth.email ?? '';
    final initial = nameOrEmail.trim().isEmpty ? 'D' : nameOrEmail.trim()[0].toUpperCase();

    return Scaffold(
      drawer: _AppDrawer(
        currentTab: _tab,
        onSelectTab: (i) => setState(() => _tab = i),
      ),
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            children: [
              TextSpan(text: 'Smart', style: TextStyle(color: p.textPrimary)),
              TextSpan(text: 'Wallet ', style: TextStyle(color: p.textPrimary)),
              TextSpan(text: 'AI', style: TextStyle(color: p.emerald)),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Financial assistant',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Tooltip(
              message: nameOrEmail.isEmpty ? 'Demo profile' : nameOrEmail,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: p.emerald, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(color: p.onEmerald, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _screens[_tab],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: _navItems,
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.currentTab, required this.onSelectTab});
  final int currentTab;
  final void Function(int) onSelectTab;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final p = context.palette;
    final title = (auth.name ?? '').trim().isNotEmpty ? auth.name!.trim() : (auth.email ?? 'Account');
    final subtitle = (auth.email ?? '').trim().isEmpty ? 'Signed in' : auth.email!;

    return Drawer(
      backgroundColor: p.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: Icon(Icons.account_circle_rounded, color: p.emerald),
              title: Text(title, style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w800)),
              subtitle: Text(subtitle, style: TextStyle(color: p.textMuted)),
            ),
            Divider(color: p.border),
            _nav(
              context,
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              selected: currentTab == 0,
              onTap: () => _goTab(context, 0),
            ),
            ListTile(
              leading: Icon(Icons.insights_rounded, color: p.textSecondary),
              title: Text('Analytics', style: TextStyle(color: p.textSecondary)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AnalyticsScreen()));
              },
            ),
            _nav(
              context,
              icon: Icons.shield_rounded,
              label: 'Impulse guard',
              selected: currentTab == 1,
              onTap: () => _goTab(context, 1),
            ),
            _nav(
              context,
              icon: Icons.radar_rounded,
              label: 'Subscriptions',
              selected: currentTab == 2,
              onTap: () => _goTab(context, 2),
            ),
            _nav(
              context,
              icon: Icons.account_balance_rounded,
              label: 'Plan & alerts',
              selected: currentTab == 3,
              onTap: () => _goTab(context, 3),
            ),
            _nav(
              context,
              icon: Icons.track_changes_rounded,
              label: 'Savings goals',
              selected: currentTab == 4,
              onTap: () => _goTab(context, 4),
            ),
            Divider(color: p.border),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline_rounded, color: p.textSecondary),
              title: Text('Financial assistant', style: TextStyle(color: p.textSecondary)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChatScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_rounded, color: p.textSecondary),
              title: Text('Settings', style: TextStyle(color: p.textSecondary)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  ListTile _nav(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final p = context.palette;
    return ListTile(
      leading: Icon(icon, color: selected ? p.emerald : p.textSecondary),
      title: Text(
        label,
        style: TextStyle(color: selected ? p.textPrimary : p.textSecondary, fontWeight: FontWeight.w600),
      ),
      selected: selected,
      onTap: onTap,
    );
  }

  void _goTab(BuildContext context, int tab) {
    Navigator.of(context).pop();
    onSelectTab(tab);
  }
}
