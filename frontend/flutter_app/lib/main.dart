import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'providers/providers.dart';
import 'screens/dashboard_screen.dart';
import 'screens/impulse_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/plan_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => ImpulseProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => RecommendationsProvider()),
        ChangeNotifierProvider(create: (_) => PlanProvider()),
      ],
      child: const SmartWalletApp(),
    ),
  );
}

class SmartWalletApp extends StatelessWidget {
  const SmartWalletApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title:        'SmartWallet AI',
        debugShowCheckedModeBanner: false,
        theme:        AppTheme.dark,
        home:         const MainShell(),
      );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
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
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined),    activeIcon: Icon(Icons.dashboard),    label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.shield_outlined),       activeIcon: Icon(Icons.shield),       label: 'Impulse'),
    BottomNavigationBarItem(icon: Icon(Icons.radar_outlined),        activeIcon: Icon(Icons.radar),        label: 'Subs'),
    BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Plan'),
    BottomNavigationBarItem(icon: Icon(Icons.lightbulb_outline),     activeIcon: Icon(Icons.lightbulb),    label: 'Insights'),
  ];

  @override
  Widget build(BuildContext context) {
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
          Container(
            margin: const EdgeInsets.only(right: 16),
            width:  34,
            height: 34,
            decoration: const BoxDecoration(color: AppColors.emerald, shape: BoxShape.circle),
            child: const Center(
              child: Text('D', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
      body:                _screens[_tab],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex:    _tab,
          onTap:           (i) => setState(() => _tab = i),
          items:           _navItems,
        ),
      ),
    );
  }
}