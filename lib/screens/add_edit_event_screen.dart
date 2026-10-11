import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class AddEditEventScreen extends StatefulWidget {
  final String? eventId;
  const AddEditEventScreen({super.key, this.eventId});

  @override
  State<AddEditEventScreen> createState() => _AddEditEventScreenState();
}

class _AddEditEventScreenState extends State<AddEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  final List<Person> _participants = [];
  final List<String> _customCategories = [];
  bool _isEdit = false;
  String? _eventId;

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      _isEdit = true;
      _eventId = widget.eventId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ev = context.read<AppProvider>().events
            .firstWhere((e) => e.id == widget.eventId);
        setState(() {
          _nameCtrl.text = ev.name;
          _startDate = ev.startDate;
          _endDate = ev.endDate;
          _participants.addAll(ev.participants);
          _customCategories.addAll(ev.customCategories);
        });
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _catCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final d = await showDatePicker(
      context: context, initialDate: _startDate,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _startDate = d;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final d = await showDatePicker(
      context: context, initialDate: _endDate,
      firstDate: _startDate, lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _endDate = d);
  }

  void _addParticipant() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Person hinzufügen'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _participants.add(Person(name: ctrl.text.trim())));
                Navigator.pop(context);
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  void _addCategory() {
    _catCtrl.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kategorie hinzufügen'),
        content: TextField(
          controller: _catCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Kategoriename', border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              final cat = _catCtrl.text.trim();
              if (cat.isNotEmpty && !_customCategories.contains(cat) &&
                  !TravelEvent.defaultCategories.contains(cat)) {
                setState(() => _customCategories.add(cat));
                Navigator.pop(context);
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte mindestens eine Person hinzufügen')));
      return;
    }
    final prov = context.read<AppProvider>();
    if (_isEdit && _eventId != null) {
      final ev = prov.events.firstWhere((e) => e.id == _eventId);
      ev.name = _nameCtrl.text.trim();
      ev.startDate = _startDate;
      ev.endDate = _endDate;
      ev.participants.clear();
      ev.participants.addAll(_participants);
      ev.customCategories.clear();
      ev.customCategories.addAll(_customCategories);
      await prov.updateEvent(ev);
    } else {
      await prov.addEvent(TravelEvent(
        name: _nameCtrl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        participants: _participants,
        customCategories: _customCategories,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Reise bearbeiten' : 'Neue Reise'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save, tooltip: 'Speichern'),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16,
            MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reisename *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.travel_explore),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v?.trim().isEmpty == true ? 'Name erforderlich' : null,
              ),
              const SizedBox(height: 16),
              const Text('Zeitraum', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Von: ${fmt.format(_startDate)}'),
                      onPressed: _pickStartDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Bis: ${fmt.format(_endDate)}'),
                      onPressed: _pickEndDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Personen', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Hinzufügen'),
                    onPressed: _addParticipant,
                  ),
                ],
              ),
              ..._participants.asMap().entries.map((entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  child: Text(entry.value.name[0].toUpperCase(),
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13)),
                ),
                title: Text(entry.value.name),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                  onPressed: () => setState(() => _participants.removeAt(entry.key)),
                ),
              )),
              if (_participants.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Noch keine Personen',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Eigene Kategorien', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Hinzufügen'),
                    onPressed: _addCategory,
                  ),
                ],
              ),
              Text('Standard: ${TravelEvent.defaultCategories.join(', ')}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8, runSpacing: 4,
                children: _customCategories.map((cat) => Chip(
                  label: Text(cat, style: const TextStyle(fontSize: 13)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _customCategories.remove(cat)),
                )).toList(),
              ),
              if (_customCategories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Keine eigenen Kategorien',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(_isEdit ? 'Änderungen speichern' : 'Reise erstellen'),
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
