import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../services/log.dart';
import '../services/formatjson.dart';

class StoragePermissionException implements Exception {
  @override
  String toString() => 'Berechtigung „Zugriff auf alle Dateien" fehlt';
}

class StorageService {
  static const _baseName = 'travelbalance_export';
  static const _maxBackups = 5;

  // Beginn Prüfung Speicherberechtigung
  static bool _needsPermission(String dir) =>
      Platform.isAndroid && dir.startsWith('/storage/');

  static Future<bool> hasPermission() async =>
      !Platform.isAndroid || await Permission.manageExternalStorage.isGranted;

  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    return (await Permission.manageExternalStorage.request()).isGranted;
  }
  // Ende Prüfung Speicherberechtigung
  
  /// Writes [jsonStr] to [dir]/travelbalance_export.json,
  /// rotating up to 5 backup copies (oldest deleted).
  static Future<void> rotateAndSave(String dir, String jsonStr) async {
    final base = p.join(dir, '$_baseName.json');

    await LogService.log('=== StorageService.rotateAndSave ===');
    await LogService.log('Zielordner: $dir');
    await LogService.log('Dateipfad: $base');

    if (_needsPermission(dir) && !await hasPermission()) {
      await LogService.log('FEHLER: Berechtigung für $dir fehlt');
      throw StoragePermissionException();
    }

    try {
      final mainFile = File(base);

      // Rotate backups: delete _5, shift _4->_5, _3->_4 ... _1->_2
      if (await mainFile.exists()) {
        await mainFile.copy(await _newBackupPath(dir));
      }

      // Nur die neuesten _maxBackups behalten, älteste löschen
      final backups = await _sortedBackups(dir);
      final excess = backups.length - _maxBackups;
      for (var i = 0; i < excess; i++) {
        await backups[i].delete();
      }

      // Write new main
      await mainFile.writeAsString(formatJson(jsonStr), encoding: utf8);
      await LogService.log(
        'JSON erfolgreich geschrieben: ${jsonStr.length} Zeichen',
      );
      await LogService.log(
        jsonStr,
        fileName: 'travelbalance_export.json',
        isJsonLog: true,
      );
    } catch (e, stack) {
      await LogService.log('FEHLER beim Schreiben: $e');
      await LogService.log('StackTrace: $stack');
      rethrow;
    }
  }

  static final _dateFmt = DateFormat('yyyy_MM_dd');

  static final _backupRe = RegExp(
    '^${RegExp.escape(_baseName)}_(\\d{4}_\\d{2}_\\d{2})(?:_(\\d+))?\\.json\$',
  );  

  /// Freier Backup-Name: ..._2026_10_06.json, sonst ..._2026_10_06_1.json, _2 ...
  static Future<String> _newBackupPath(String dir) async {
    final today = _dateFmt.format(DateTime.now());
    var path = p.join(dir, '${_baseName}_$today.json');
    var i = 1;
    while (await File(path).exists()) {
      path = p.join(dir, '${_baseName}_${today}_$i.json');
      i++;
    }
    return path;
  }

  /// Alle Backups, älteste zuerst (sortiert nach Datum, dann Index).
  static Future<List<File>> _sortedBackups(String dir) async {
    final d = Directory(dir);
    if (!await d.exists()) return [];
    final entries = <MapEntry<String, File>>[];
    await for (final e in d.list()) {
      if (e is! File) continue;
      final m = _backupRe.firstMatch(p.basename(e.path));
      if (m == null) continue;
      final idx = int.parse(m.group(2) ?? '0').toString().padLeft(6, '0');
      entries.add(MapEntry('${m.group(1)}_$idx', e));
    }
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => e.value).toList();
  }
  
  static Future<String?> loadFromFile(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    return await f.readAsString(encoding: utf8);
  }

  static Future<List<String>> listBackups(String dir) async =>
    (await _sortedBackups(dir)).map((f) => f.path).toList();
}
