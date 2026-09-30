import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/storage_service.dart';

class AppProvider extends ChangeNotifier {
  List<TravelEvent> events = [];
  String? exportDirectory;
  bool _loading = false;
  bool get loading => _loading;

  static const _prefExportDir = 'exportDirectory';
  static const _prefData = 'travelbalance_data';

  Future<void> loadData() async {
    _loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      exportDirectory = prefs.getString(_prefExportDir);
      exportDirectory ??= (await getApplicationDocumentsDirectory()).path;
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
  }

  Future<void> _persist({bool export = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_prefData, json);
    if (export && exportDirectory != null) {
      try {
        await StorageService.rotateAndSave(exportDirectory!, json);
      } catch (e) {
        debugPrint('Export error: $e');
      }
    }
    notifyListeners();
  }

  Future<void> exportNow() async => _persist(export: true);

  Future<void> setExportDirectory(String dir) async {
    exportDirectory = dir;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefExportDir, dir);
    notifyListeners();
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
}
