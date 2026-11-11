import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/storage_service.dart';
import '../utils/messenger.dart';

enum EventSortMode { dateAsc, dateDesc, nameAsc, nameDesc }

class AppProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  List<TravelEvent> events = [];

  /// content://-URI des gewählten Sicherungsordners (SAF)
  String? exportDirectory;
  bool _loading = false;
  String? exportError;

  /// true, wenn der Fehler am Ordner liegt (gelöscht, Zugriff verloren)
  bool folderProblem = false;
  bool get loading => _loading;
  bool get needsFolder => exportDirectory == null;
  static const _prefSort = 'eventSortMode';
  EventSortMode sortMode = EventSortMode.dateDesc;
  static const _prefThemeMode = 'themeMode';
  ThemeMode themeMode = ThemeMode.system;

  static const _prefExportDir = 'exportDirectory';
  static const _prefData = 'travelbalance_data';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Beim Zurückkehren in die App prüfen, ob der Ordner noch existiert
  /// (er könnte in der Zwischenzeit gelöscht worden sein).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkExportFolder();
  }

  Future<void> loadData() async {
    _loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      exportDirectory = prefs.getString(_prefExportDir);
      // Alter Dateipfad (vor SAF-Umbau) ist nicht mehr nutzbar
      if (exportDirectory != null &&
          !exportDirectory!.startsWith('content://')) {
        exportDirectory = null;
        await prefs.remove(_prefExportDir);
      }
      final s = prefs.getString(_prefSort);
      sortMode = EventSortMode.values.firstWhere(
        (m) => m.name == s,
        orElse: () => EventSortMode.dateDesc,
      );
      final savedThemeMode = prefs.getString(_prefThemeMode);
      themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == savedThemeMode,
        orElse: () => ThemeMode.system,
      );
      final raw = prefs.getString(_prefData);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        events = list
            .map((e) => TravelEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('loadData error: $e');
    }
    _loading = false;
    notifyListeners();
    await checkExportFolder();
  }

  /// Prüft den Sicherungsordner und setzt ggf. den Hinweis (Banner).
  Future<void> checkExportFolder() async {
    final dir = exportDirectory;
    if (dir == null) return;
    try {
      await StorageService.ensureFolder(dir);
      if (folderProblem) {
        folderProblem = false;
        exportError = null;
      }
    } on StorageFolderException catch (e) {
      folderProblem = true;
      exportError = e.message;
    } catch (e) {
      debugPrint('checkExportFolder error: $e');
    }
    notifyListeners();
  }

  Future<void> _persist({bool export = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_prefData, json);
    if (export && exportDirectory != null) {
      try {
        await StorageService.rotateAndSave(exportDirectory!, json);
        exportError = null;
        folderProblem = false;
      } catch (e) {
        folderProblem = e is StorageFolderException;
        exportError = e.toString();
        debugPrint('Export error: $e');
        messengerKey.currentState
          ?..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Export fehlgeschlagen: $exportError'),
              backgroundColor: Colors.red[700],
              duration: const Duration(seconds: 8),
              action: folderProblem
                  ? SnackBarAction(
                      label: 'Ordner wählen',
                      textColor: Colors.white,
                      onPressed: () => chooseExportFolder(),
                    )
                  : null,
            ),
          );
      }
    }
    notifyListeners();
  }

  Future<void> exportNow() async {
    if (exportDirectory == null) {
      throw Exception('Kein Sicherungsordner gewählt');
    }
    await _persist(export: true);
    if (exportError != null) throw Exception(exportError);
  }

  Future<void> setExportDirectory(String dir) async {
    exportDirectory = dir;
    exportError = null;
    folderProblem = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefExportDir, dir);
    notifyListeners();
  }

  /// Ordnerdialog öffnen, Wahl speichern und sofort exportieren.
  /// Gibt true zurück, wenn gewählt und exportiert wurde.
  Future<bool> chooseExportFolder() async {
    final dir = await StorageService.pickFolder();
    if (dir == null) return false;
    await setExportDirectory(dir);
    await _persist(export: true);
    return exportError == null;
  }

  // ---- Events ----
  Future<void> addEvent(TravelEvent event) async {
    events.add(event);
    await _persist();
  }

  Future<void> updateEvent(TravelEvent event) async {
    final i = events.indexWhere((e) => e.id == event.id);
    if (i >= 0) events[i] = event;
    await _persist();
  }

  Future<void> deleteEvent(String eventId) async {
    events.removeWhere((e) => e.id == eventId);
    await _persist();
  }

  // ---- Expenses ----
  Future<void> addExpense(String eventId, Expense expense) async {
    final ev = events.firstWhere((e) => e.id == eventId);
    ev.expenses.add(expense);
    await _persist();
  }

  Future<void> updateExpense(String eventId, Expense expense) async {
    final ev = events.firstWhere((e) => e.id == eventId);
    final i = ev.expenses.indexWhere((e) => e.id == expense.id);
    if (i >= 0) ev.expenses[i] = expense;
    await _persist();
  }

  Future<void> deleteExpense(String eventId, String expenseId) async {
    final ev = events.firstWhere((e) => e.id == eventId);
    ev.expenses.removeWhere((e) => e.id == expenseId);
    await _persist();
  }

  // ---- Manual Settlements ----
  Future<void> addManualSettlement(String eventId, ManualSettlement ms) async {
    final ev = events.firstWhere((e) => e.id == eventId);
    ev.manualSettlements.add(ms);
    await _persist();
  }

  Future<void> deleteManualSettlement(String eventId, String msId) async {
    final ev = events.firstWhere((e) => e.id == eventId);
    ev.manualSettlements.removeWhere((m) => m.id == msId);
    await _persist();
  }

  // ---- Custom categories ----
  Future<void> addCategory(String eventId, String category) async {
    final ev = events.firstWhere((e) => e.id == eventId);
    if (!ev.customCategories.contains(category)) {
      ev.customCategories.add(category);
      await _persist(export: false);
    }
  }

  Future<void> removeCategory(String eventId, String category) async {
    final ev = events.firstWhere((e) => e.id == eventId);
    ev.customCategories.remove(category);
    await _persist(export: false);
  }

  // ---- Import ----
  Future<bool> importFromJson(String jsonStr) async {
    try {
      final list = jsonDecode(jsonStr) as List;
      events = list
          .map((e) => TravelEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      await _persist(export: false);
      return true;
    } catch (e) {
      debugPrint('Import error: $e');
      return false;
    }
  }

  // ---- Sort Mode ----
  Future<void> setSortMode(EventSortMode mode) async {
    sortMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSort, mode.name);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefThemeMode, mode.name);
    notifyListeners();
  }

  List<TravelEvent> get sortedEvents {
    final list = [...events];
    switch (sortMode) {
      case EventSortMode.dateAsc:
        list.sort((a, b) => a.startDate.compareTo(b.startDate));
      case EventSortMode.dateDesc:
        list.sort((a, b) => b.startDate.compareTo(a.startDate));
      case EventSortMode.nameAsc:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case EventSortMode.nameDesc:
        list.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
    }
    return list;
  }
}
