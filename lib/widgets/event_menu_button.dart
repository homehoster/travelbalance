import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../screens/add_edit_event_screen.dart';

/// 3-Punkte-Menü (Bearbeiten / Löschen) für eine Reise.
/// Wird auf der Startseite und im Seitenmenü verwendet.
class EventMenuButton extends StatelessWidget {
  final TravelEvent event;

  /// true, wenn das Menü im Drawer liegt: Drawer wird vor dem Bearbeiten geschlossen.
  final bool closeDrawerOnEdit;
  final double? iconSize;

  const EventMenuButton({
    super.key,
    required this.event,
    this.closeDrawerOnEdit = false,
    this.iconSize,
  });

  void _edit(BuildContext context) {
    final nav = Navigator.of(context);
    if (closeDrawerOnEdit) nav.pop();
    nav.push(
      MaterialPageRoute(builder: (_) => AddEditEventScreen(eventId: event.id)),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final prov = context.read<AppProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reise löschen?'),
        content: Text('"${event.name}" und alle Ausgaben werden gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) await prov.deleteEvent(event.id);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      iconSize: iconSize,
      padding: EdgeInsets.zero,
      onSelected: (v) {
        if (v == 'edit') _edit(context);
        if (v == 'delete') _delete(context);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Löschen', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}