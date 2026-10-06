import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/event_menu_button.dart';
import 'add_edit_event_screen.dart';
import 'event_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TravelBalance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Neue Reise',
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddEditEventScreen())),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : prov.events.isEmpty
              ? _EmptyState(
                  onAdd: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddEditEventScreen())),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: prov.events.length,
                  itemBuilder: (ctx, i) {
                    final ev = prov.events[i];
                    return _EventCard(
                      event: ev,
                      onTap: () => Navigator.push(ctx,
                        MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: ev.id))),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AddEditEventScreen())),
        tooltip: 'Neue Reise',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final TravelEvent event;
  final VoidCallback onTap;

  const _EventCard({
    required this.event, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    final total = event.expenses.fold(0.0, (s, e) => s + e.totalEur);
    final color = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(event.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  EventMenuButton(event: event),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${fmt.format(event.startDate)} – ${fmt.format(event.endDate)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Chip(Icons.people_outline, '${event.participants.length} Personen', color),
                  const SizedBox(width: 8),
                  _Chip(Icons.receipt_long_outlined, '${event.expenses.length} Ausgaben', color),
                  const Spacer(),
                  Text(
                    '${total.toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.travel_explore, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Noch keine Reisen',
            style: TextStyle(fontSize: 20, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Erstelle deine erste Reise!',
            style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Neue Reise'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
