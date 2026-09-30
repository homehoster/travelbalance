import 'dart:convert';
import 'dart:io';

import '../services/formatjson.dart';

class LogService {
  static Future<void> log(
    String message, {
    String fileName = 'travelbalance.log',
    bool isJsonLog = false,
  }) async {
    try {
      final dir = Directory('/storage/emulated/0/Download/TravelBalance/Log');

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File('${dir.path}/$fileName');

      if (isJsonLog) {
        // JSON-Datei komplett überschreiben
        await file.writeAsString(formatJson(message), encoding: utf8);
      } else {
        // Normales Log: anhängen + Timestamp
        final timestamp = DateTime.now().toIso8601String();

        await file.writeAsString(
          '[$timestamp] $message\n',
          mode: FileMode.append,
          encoding: utf8,
        );
      }

      print(message);
    } catch (e) {
      print('Fehler beim Schreiben des Logs: $e');
    }
  }
}
