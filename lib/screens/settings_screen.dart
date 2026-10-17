import 'dart:io';
 
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
 
import '../providers/app_provider.dart';
import '../services/log.dart';
import '../services/storage_service.dart';
import '../widgets/app_version_text.dart';
 
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'Speicherort', icon: Icons.folder_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktueller Ordner:',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prettyFolder(prov.exportDirectory),
                    style: const TextStyle(fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (prov.folderProblem && prov.exportError != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            prov.exportError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Speicherort wählen'),
                      onPressed: () async {
                        final ok = await prov.chooseExportFolder();
                        if (!context.mounted) return;
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Gespeichert: '
                                '${StorageService.displayPath(prov.exportDirectory)}',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Export & Import', icon: Icons.import_export),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.blue),
                  title: const Text('Jetzt exportieren'),
                  subtitle: const Text('Speichert alle Reisen als JSON'),
                  onTap: () async {
                    if (prov.exportDirectory == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bitte zuerst Speicherort wählen'),
                        ),
                      );
                      return;
                    }
                    try {
                      await prov.exportNow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Exportiert nach '
                              '${StorageService.displayPath(prov.exportDirectory)}',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.download_outlined,
                    color: Colors.green,
                  ),
                  title: const Text('JSON importieren'),
                  subtitle: const Text('Daten aus JSON-Datei laden'),
                  onTap: () async {
                    final result = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['json'],
                      dialogTitle: 'TravelBalance JSON wählen',
                    );
                    if (result.isNotEmpty && result.single.path != null) {
                      final path = result.single.path!;
                      final content = await File(path).readAsString();
                      if (!context.mounted) return;
                      final ok = await prov.importFromJson(content);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Import erfolgreich!'
                                : 'Import fehlgeschlagen',
                          ),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Diagnose', icon: Icons.bug_report_outlined),
          Card(
            child: ListTile(
              leading: const Icon(Icons.share, color: Colors.deepPurple),
              title: const Text('Log teilen'),
              subtitle: const Text('Logdateien per Teilen-Menü senden'),
              onTap: () async {
                try {
                  final shared = await LogService.share();
                  if (!shared && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Noch keine Logs vorhanden')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fehler beim Teilen: $e')),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Info', icon: Icons.info_outline),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TravelBalance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const AppVersionText(),
                  const SizedBox(height: 4),
                  const Text('Reisekosten einfach aufteilen.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
 
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
 
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

String prettyFolder(String? uri) {
  if (uri == null) return 'Nicht gesetzt';
  if (!uri.startsWith('content://')) return uri; // normaler Dateipfad
  final segs = Uri.parse(uri).pathSegments; // bereits dekodiert
  final i = segs.indexOf('tree');
  final id = (i >= 0 && i + 1 < segs.length) ? segs[i + 1] : uri;
  final parts = id.split(':');
  final volume = parts.first == 'primary' ? 'Interner Speicher' : parts.first;
  final path = parts.length > 1 ? parts.sublist(1).join(':') : '';
  return path.isEmpty ? volume : '$volume/$path';
}
 
