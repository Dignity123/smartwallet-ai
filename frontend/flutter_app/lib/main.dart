import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'providers/auth_provider.dart';
import 'providers/providers.dart';
import 'screens/dashboard_screen.dart';
import 'screens/impulse_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/login_screen.dart';
import 'screens/chat_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => ImpulseProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => RecommendationsProvider()),
        ChangeNotifierProvider(create: (_) => PlanProvider()),
      ],
      child: const WalletAppRoot(),
    ),
  );
}

class WalletAppRoot extends StatelessWidget {
  const WalletAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartWallet AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          if (auth.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
            );
          }
          if (!auth.authenticated) {
            return const LoginScreen();
          }
          return const MainShell();
        },
      ),
    );
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
    RecommendationsScreen(),
  ];

  static const _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), activeIcon: Icon(Icons.shield), label: 'Impulse'),
    BottomNavigationBarItem(icon: Icon(Icons.radar_outlined), activeIcon: Icon(Icons.radar), label: 'Subs'),
    BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Plan'),
    BottomNavigationBarItem(icon: Icon(Icons.lightbulb_outline), activeIcon: Icon(Icons.lightbulb), label: 'Insights'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nameOrEmail = ApiService.userName ?? ApiService.userEmail ?? 'U';
    final initial = nameOrEmail.trim().isEmpty ? '?' : nameOrEmail.trim()[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            children: [
              TextSpan(text: 'Smart', style: TextStyle(color: Color(0xFFF9FAFB))),
              TextSpan(text: 'Wallet ', style: TextStyle(color: Color(0xFFF9FAFB))),
              TextSpan(text: 'AI', style: TextStyle(color: AppColors.emerald)),
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
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.emerald,
              child: Text(initial, style: const TextStyle(color: AppColors.background, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            color: AppColors.surface,
            onSelected: (v) async {
              if (v == 'logout') {
                await context.read<AuthProvider>().logout();
              }
            },
            itemBuilder: (_) {
              final email = auth.authenticated ? (ApiService.userEmail ?? ApiService.userName ?? 'Signed in') : '';
              final showLogout =
                  ApiService.authEnabledOnServer || (ApiService.accessToken != null && ApiService.accessToken!.isNotEmpty);
              return [
                PopupMenuItem(
                  value: 'profile',
                  enabled: false,
                  child: Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
                if (showLogout) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Text('Sign out', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ];
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _screens[_tab],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
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
