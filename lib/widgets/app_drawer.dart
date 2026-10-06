import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../screens/event_detail_screen.dart';
import '../screens/add_edit_event_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/event_menu_button.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Drawer(
      child: Column(
        children: [
          // Header
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.7),
                ],
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 64,
                    height: 64,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.travel_explore,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TravelBalance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Reisekosten teilen',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // "Meine Reisen" Abschnitt – scrollbar
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Abschnittsheader
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.luggage,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      ListTile(
                        leading: const Icon(Icons.home_outlined),
                        title: const Text('Meine Reisen'),
                        onTap: () {
                          Navigator.pop(context); // Drawer schließen
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                      ),
                      const Divider(height: 1),
                      Text(
                        'Meine Reisen',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      // Neue Reise
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        tooltip: 'Neue Reise',
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddEditEventScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                if (prov.events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Noch keine Reisen',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  )
                else
                  ...prov.events.map(
                    (ev) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(context).colorScheme.primary
                            .withOpacity(0.15),
                        child: Text(
                          ev.name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        ev.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        '${ev.participants.length} Personen · '
                        '${ev.expenses.length} Ausgaben',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      trailing: EventMenuButton(
                        event: ev,
                        closeDrawerOnEdit: true,
                        iconSize: 20,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventDetailScreen(eventId: ev.id),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Einstellungen unten verankert
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Einstellungen'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'TravelBalance v1.0',
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
