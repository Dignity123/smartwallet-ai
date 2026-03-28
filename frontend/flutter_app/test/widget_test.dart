import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:smartwallet_ai/main.dart';
import 'package:smartwallet_ai/providers/providers.dart';

void main() {
  testWidgets('SmartWallet shell loads with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
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

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
  });
}
