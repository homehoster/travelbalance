import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/log.dart';
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
  static const _prefAutomaticExport = 'automaticExport';
  bool automaticExport = false;
  static const _prefWriteLogFiles = 'writeLogFiles';
  bool writeLogFiles = false;
  static const _prefBackupCount = 'backupCount';
  int backupCount = 5;
  static const _prefSaveSettingsFile = 'saveSettingsFile';
  bool saveSettingsFile = false;

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
      automaticExport = prefs.getBool(_prefAutomaticExport) ?? false;
      writeLogFiles = prefs.getBool(_prefWriteLogFiles) ?? false;
      final savedBackupCount = prefs.getInt(_prefBackupCount) ?? 5;
      backupCount = savedBackupCount >= 1 && savedBackupCount <= 50
          ? savedBackupCount
          : 5;
      saveSettingsFile = prefs.getBool(_prefSaveSettingsFile) ?? false;
      LogService.setEnabled(writeLogFiles);
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
    if (export && automaticExport && exportDirectory != null) {
      await _exportToFolder();
    }
    notifyListeners();
  }

  Future<void> exportNow() async {
    if (exportDirectory == null) {
      throw Exception('Kein Sicherungsordner gewählt');
    }
    await _persist(export: false);
    await _exportToFolder();
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
    if (automaticExport) await _persist(export: true);
    return exportError == null;
  }

  Future<void> _exportToFolder() async {
    final dir = exportDirectory;
    if (dir == null) return;
    try {
      final json = jsonEncode(events.map((e) => e.toJson()).toList());
      await StorageService.rotateAndSave(dir, json, maxBackups: backupCount);
      if (saveSettingsFile) {
        await StorageService.saveSettings(dir, jsonEncode(_settingsJson));
      }
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

  Map<String, Object> get _settingsJson => {
    'type': 'travelbalance_settings',
    'version': 1,
    'themeMode': themeMode.name,
    'sortMode': sortMode.name,
    'automaticExport': automaticExport,
    'writeLogFiles': writeLogFiles,
    'backupCount': backupCount,
    'saveSettingsFile': saveSettingsFile,
  };

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefThemeMode, themeMode.name);
    await prefs.setString(_prefSort, sortMode.name);
    await prefs.setBool(_prefAutomaticExport, automaticExport);
    await prefs.setBool(_prefWriteLogFiles, writeLogFiles);
    await prefs.setInt(_prefBackupCount, backupCount);
    await prefs.setBool(_prefSaveSettingsFile, saveSettingsFile);
    if (automaticExport && saveSettingsFile && exportDirectory != null) {
      await _saveSettingsFileToFolder();
    }
    notifyListeners();
  }

  Future<void> _saveSettingsFileToFolder() async {
    final dir = exportDirectory;
    if (dir == null) return;
    try {
      await StorageService.saveSettings(dir, jsonEncode(_settingsJson));
      exportError = null;
      folderProblem = false;
    } catch (e) {
      folderProblem = e is StorageFolderException;
      exportError = e.toString();
      debugPrint('Settings export error: $e');
      messengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Einstellungen konnten nicht gespeichert werden: $e'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 8),
          ),
        );
    }
  }

  Future<void> setAutomaticExport(bool enabled) async {
    automaticExport = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutomaticExport, enabled);
    notifyListeners();
    if (enabled && exportDirectory != null) await _persist(export: true);
  }

  Future<void> setWriteLogFiles(bool enabled) async {
    writeLogFiles = enabled;
    LogService.setEnabled(enabled);
    await _saveSettings();
  }

  Future<void> setBackupCount(int count) async {
    if (count < 1 || count > 50) {
      throw ArgumentError.value(count, 'count', 'Must be 1-50');
    }
    backupCount = count;
    await _saveSettings();
  }

  Future<void> setSaveSettingsFile(bool enabled) async {
    saveSettingsFile = enabled;
    await _saveSettings();
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
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        events = decoded
            .map((e) => TravelEvent.fromJson(e as Map<String, dynamic>))
            .toList();
        await _persist(export: false);
        return true;
      }
      if (decoded is Map<String, dynamic> &&
          decoded['type'] == 'travelbalance_settings') {
        return await _importSettings(decoded);
      }
      return false;
    } catch (e) {
      debugPrint('Import error: $e');
      return false;
    }
  }

  Future<bool> _importSettings(Map<String, dynamic> json) async {
    if (json['version'] != 1 ||
        json['themeMode'] is! String ||
        json['sortMode'] is! String ||
        json['automaticExport'] is! bool ||
        json['writeLogFiles'] is! bool ||
        json['backupCount'] is! int ||
        json['saveSettingsFile'] is! bool) {
      return false;
    }
    final importedTheme = ThemeMode.values.where(
      (mode) => mode.name == json['themeMode'],
    );
    final importedSort = EventSortMode.values.where(
      (mode) => mode.name == json['sortMode'],
    );
    final importedBackupCount = json['backupCount'] as int;
    if (importedTheme.isEmpty ||
        importedSort.isEmpty ||
        importedBackupCount < 1 ||
        importedBackupCount > 50) {
      return false;
    }

    themeMode = importedTheme.first;
    sortMode = importedSort.first;
    automaticExport = json['automaticExport'] as bool;
    writeLogFiles = json['writeLogFiles'] as bool;
    backupCount = importedBackupCount;
    saveSettingsFile = json['saveSettingsFile'] as bool;
    LogService.setEnabled(writeLogFiles);
    await _saveSettings();
    return true;
  }

  // ---- Sort Mode ----
  Future<void> setSortMode(EventSortMode mode) async {
    sortMode = mode;
    await _saveSettings();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _saveSettings();
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
