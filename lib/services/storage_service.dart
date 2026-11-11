import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import '../services/formatjson.dart';
import '../services/log.dart';

/// Der gewählte Sicherungsordner ist ungültig, gelöscht oder nicht mehr
/// zugreifbar. [message] kann direkt dem Nutzer angezeigt werden.
class StorageFolderException implements Exception {
  final String message;
  StorageFolderException(this.message);
  @override
  String toString() => message;
}

class StorageService {
  static const _baseName = 'travelbalance_export';
  static const _mainName = '$_baseName.json';
  static const _settingsName = 'travelbalance_settings.json';
  static const _defaultMaxBackups = 5;

  static final _util = SafUtil();
  static final _stream = SafStream();

  static final _dateFmt = DateFormat('yyyy_MM_dd');
  static final _backupRe = RegExp(
    '^${RegExp.escape(_baseName)}_(\\d{4}_\\d{2}_\\d{2})(?:_(\\d+))?\\.json\$',
  );

  // ── Ordnerwahl ────────────────────────────────────────────────────────────

  /// Öffnet den Android-Ordnerdialog (SAF) mit dauerhaftem Schreibrecht.
  /// Gibt die content://-URI zurück oder null bei Abbruch.
  static Future<String?> pickFolder() async {
    final dir = await _util.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    return dir?.uri;
  }

  /// Lesbare Darstellung der URI, z. B. "primary:Download/TravelBalance".
  static String displayPath(String? uri) {
    if (uri == null) return 'Nicht gesetzt';
    try {
      final decoded = Uri.decodeComponent(uri);
      final i = decoded.indexOf('/tree/');
      return i >= 0 ? decoded.substring(i + 6) : decoded;
    } catch (_) {
      return uri;
    }
  }

  /// Prüft, ob der Ordner noch existiert und beschreibbar ist.
  /// Wirft [StorageFolderException], wenn nicht.
  static Future<void> ensureFolder(String uri) async {
    if (!uri.startsWith('content://')) {
      throw StorageFolderException(
        'Der Sicherungsordner ist ungültig. Bitte neu wählen.',
      );
    }
    var hasPerm = false;
    try {
      hasPerm = await _util.hasPersistedPermission(
        uri,
        checkRead: true,
        checkWrite: true,
      );
    } catch (_) {}
    if (!hasPerm) {
      throw StorageFolderException(
        'Kein Zugriff mehr auf den Sicherungsordner. '
        'Er wurde möglicherweise gelöscht oder verschoben.',
      );
    }
    try {
      await _util.list(uri); // schlägt fehl, wenn der Ordner nicht existiert
    } catch (_) {
      throw StorageFolderException(
        'Der Sicherungsordner existiert nicht mehr. Bitte neu wählen.',
      );
    }
  }

  // ── Speichern mit Rotation ────────────────────────────────────────────────

  /// Schreibt [jsonStr] nach [dirUri]/travelbalance_export.json.
  /// Vorher wird die bestehende Datei als datierte Kopie gesichert.
  /// [maxBackups] legt fest, wie viele Kopien (1-50) erhalten bleiben.
  static Future<void> rotateAndSave(
    String dirUri,
    String jsonStr, {
    int maxBackups = _defaultMaxBackups,
  }) async {
    if (maxBackups < 1 || maxBackups > 50) {
      throw ArgumentError.value(maxBackups, 'maxBackups', 'Must be 1-50');
    }
    await LogService.log('=== StorageService.rotateAndSave ===');
    await LogService.log('Zielordner: ${displayPath(dirUri)}');

    try {
      await ensureFolder(dirUri);

      final entries = await _util.list(dirUri);
      final names = entries.map((e) => e.name).toSet();

      // Bestehende Hauptdatei als Backup sichern
      String? mainUri;
      for (final e in entries) {
        if (!e.isDir && e.name == _mainName) mainUri = e.uri;
      }
      if (mainUri != null) {
        final old = await _stream.readFileBytes(mainUri);
        await _stream.writeFileBytes(
          dirUri,
          _newBackupName(names),
          'application/json',
          old,
        );
      }

      // Nur die neuesten Backups behalten
      final backups = await _sortedBackupUris(dirUri);
      final excess = backups.length - maxBackups;
      for (var i = 0; i < excess; i++) {
        await _util.delete(backups[i], false);
      }

      // Hauptdatei überschreiben
      await _stream.writeFileBytes(
        dirUri,
        _mainName,
        'application/json',
        Uint8List.fromList(utf8.encode(formatJson(jsonStr))),
        overwrite: true,
      );
      await LogService.log('JSON geschrieben: ${jsonStr.length} Zeichen');
    } catch (e, stack) {
      await LogService.log('FEHLER beim Schreiben: $e');
      if (e is! StorageFolderException) {
        await LogService.log('StackTrace: $stack');
      }
      rethrow;
    }
  }

  static Future<void> saveSettings(String dirUri, String jsonStr) async {
    await ensureFolder(dirUri);
    await _stream.writeFileBytes(
      dirUri,
      _settingsName,
      'application/json',
      Uint8List.fromList(utf8.encode(formatJson(jsonStr))),
      overwrite: true,
    );
  }

  /// Freier Backup-Name: ..._2026_10_06.json, sonst ..._2026_10_06_1.json ...
  static String _newBackupName(Set<String> existing) {
    final today = _dateFmt.format(DateTime.now());
    var name = '${_baseName}_$today.json';
    var i = 1;
    while (existing.contains(name)) {
      name = '${_baseName}_${today}_$i.json';
      i++;
    }
    return name;
  }

  /// URIs aller Backups, älteste zuerst (Datum, dann Index).
  static Future<List<String>> _sortedBackupUris(String dirUri) async {
    final items = <(String, String)>[]; // (Sortierschlüssel, URI)
    for (final e in await _util.list(dirUri)) {
      if (e.isDir) continue;
      final m = _backupRe.firstMatch(e.name);
      if (m == null) continue;
      final idx = int.parse(m.group(2) ?? '0').toString().padLeft(6, '0');
      items.add(('${m.group(1)}_$idx', e.uri));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    return items.map((e) => e.$2).toList();
  }
}
