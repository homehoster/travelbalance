import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Schreibt bei aktivierter Option Logs in den app-eigenen Ordner.
/// Rotation: Ab 5 MB wird travelbalance.log zu travelbalance.log.1,
/// eine ältere .1 wird überschrieben. Maximal also ca. 10 MB Logdaten.
class LogService {
  static const _fileName = 'travelbalance.log';
  static const _maxBytes = 5 * 1024 * 1024;
  static bool _enabled = false;

  static Directory? _dir;

  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  static Future<Directory> _logDir() async {
    if (_dir != null) return _dir!;
    Directory base;
    try {
      base =
          await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } catch (_) {
      base = await getApplicationDocumentsDirectory();
    }
    final d = Directory(p.join(base.path, 'logs'));
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  static Future<void> log(String message) async {
    debugPrint(message);
    if (!_enabled) return;
    try {
      final dir = await _logDir();
      final file = File(p.join(dir.path, _fileName));
      await _rotateIfNeeded(file);
      await file.writeAsString(
        '[${DateTime.now().toIso8601String()}] $message\n',
        mode: FileMode.append,
        encoding: utf8,
      );
    } catch (e) {
      debugPrint('Fehler beim Schreiben des Logs: $e');
    }
  }

  static Future<void> _rotateIfNeeded(File file) async {
    if (!await file.exists()) return;
    if (await file.length() < _maxBytes) return;
    final old = File('${file.path}.1');
    if (await old.exists()) await old.delete();
    await file.rename(old.path);
  }

  /// Vorhandene Logdateien (aktuelle zuerst).
  static Future<List<File>> logFiles() async {
    final dir = await _logDir();
    final result = <File>[];
    for (final name in [_fileName, '$_fileName.1']) {
      final f = File(p.join(dir.path, name));
      if (await f.exists() && await f.length() > 0) result.add(f);
    }
    return result;
  }

  /// Öffnet das Teilen-Menü mit den Logdateien.
  /// Gibt false zurück, wenn es noch keine Logs gibt.
  static Future<bool> share() async {
    final files = await logFiles();
    if (files.isEmpty) return false;
    await SharePlus.instance.share(
      ShareParams(
        subject: 'TravelBalance Log',
        files: files.map((f) => XFile(f.path, mimeType: 'text/plain')).toList(),
      ),
    );
    return true;
  }
}
