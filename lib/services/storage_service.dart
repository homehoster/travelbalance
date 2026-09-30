import 'dart:convert';
import 'dart:io';

import '../services/log.dart';
import '../services/formatjson.dart';

import 'package:path/path.dart' as p;

class StorageService {
  static const _baseName = 'travelbalance_export';
  static const _maxBackups = 5;

  /// Writes [jsonStr] to [dir]/travelbalance_export.json,
  /// rotating up to 5 backup copies (oldest deleted).
  static Future<void> rotateAndSave(String dir, String jsonStr) async {
    final base = p.join(dir, '$_baseName.json');

    await LogService.log('=== StorageService.rotateAndSave ===');
    await LogService.log('Zielordner: $dir');
    await LogService.log('Dateipfad: $base');

    try {
      final mainFile = File(base);

      // Rotate backups: delete _5, shift _4->_5, _3->_4 ... _1->_2
      final b5 = File(p.join(dir, '${_baseName}_5.json'));
      if (await b5.exists()) await b5.delete();

      for (int i = _maxBackups - 1; i >= 1; i--) {
        final src = File(p.join(dir, '${_baseName}_$i.json'));
        final dst = File(p.join(dir, '${_baseName}_${i + 1}.json'));
        if (await src.exists()) {
          await src.rename(dst.path);
        }
      }

      // Save current main as _1
      if (await mainFile.exists()) {
        await mainFile.copy(p.join(dir, '${_baseName}_1.json'));
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
    }
  }

  static Future<String?> loadFromFile(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    return await f.readAsString(encoding: utf8);
  }

  static Future<List<String>> listBackups(String dir) async {
    final files = <String>[];
    for (int i = 1; i <= _maxBackups; i++) {
      final f = File(p.join(dir, '${_baseName}_$i.json'));
      if (await f.exists()) files.add(f.path);
    }
    return files;
  }
}
