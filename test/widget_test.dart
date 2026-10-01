// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:travelbalance/main.dart';
import 'package:travelbalance/providers/app_provider.dart';
import 'package:travelbalance/screens/home_screen.dart';

void main() {
  testWidgets('TravelBalance wird korrekt geladen', (WidgetTester tester) async {
    final provider = AppProvider();
    await provider.loadData();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const TravelBalanceApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}

