// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travelbalance/main.dart';
import 'package:travelbalance/providers/app_provider.dart';
import 'package:travelbalance/screens/home_screen.dart';
import 'package:travelbalance/screens/settings_screen.dart';

void main() {
  test(
    'Speicheroptionen lassen sich einstellen und wiederherstellen',
    () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AppProvider();
      await provider.loadData();

      expect(provider.automaticExport, isFalse);
      expect(provider.writeLogFiles, isFalse);
      expect(provider.backupCount, 5);
      expect(provider.saveSettingsFile, isFalse);

      await provider.setAutomaticExport(true);
      await provider.setWriteLogFiles(true);
      await provider.setSaveSettingsFile(true);
      await provider.setBackupCount(7);
      await expectLater(provider.setBackupCount(51), throwsArgumentError);

      final restoredProvider = AppProvider();
      await restoredProvider.loadData();
      expect(restoredProvider.automaticExport, isTrue);
      expect(restoredProvider.writeLogFiles, isTrue);
      expect(restoredProvider.backupCount, 7);
      expect(restoredProvider.saveSettingsFile, isTrue);
      provider.dispose();
      restoredProvider.dispose();
    },
  );

  test('Einstellungs-JSON kann importiert werden', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();
    await provider.loadData();

    final imported = await provider.importFromJson(
      jsonEncode({
        'type': 'travelbalance_settings',
        'version': 1,
        'themeMode': 'dark',
        'sortMode': 'nameAsc',
        'automaticExport': true,
        'writeLogFiles': false,
        'backupCount': 50,
        'saveSettingsFile': true,
      }),
    );

    expect(imported, isTrue);
    expect(provider.themeMode, ThemeMode.dark);
    expect(provider.sortMode, EventSortMode.nameAsc);
    expect(provider.automaticExport, isTrue);
    expect(provider.backupCount, 50);
    expect(provider.saveSettingsFile, isTrue);
    provider.dispose();
  });

  testWidgets('Theme-Auswahl wird gespeichert und in der App angewendet', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppProvider();
    await provider.loadData();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const TravelBalanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    Navigator.of(tester.element(find.byType(HomeScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    await tester.pumpAndSettle();
    final settingsScrollable = find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Dunkel'),
      300,
      scrollable: settingsScrollable,
    );
    await tester.tap(find.text('Dunkel'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    final restoredProvider = AppProvider();
    await restoredProvider.loadData();
    expect(restoredProvider.themeMode, ThemeMode.dark);
    provider.dispose();
    restoredProvider.dispose();
  });

  testWidgets('TravelBalance wird korrekt geladen', (
    WidgetTester tester,
  ) async {
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
