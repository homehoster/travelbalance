import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
 
/// Eine eigene Kategorie im Editor.
/// [original] = gespeicherter Name (null = in dieser Sitzung neu angelegt),
/// [name] = aktueller Name im Editor.
class _CatEntry {
  final String? original;
  String name;
  _CatEntry({this.original, required this.name});
}
 
class AddEditEventScreen extends StatefulWidget {
  final String? eventId;
  const AddEditEventScreen({super.key, this.eventId});
 
  @override
  State<AddEditEventScreen> createState() => _AddEditEventScreenState();
}
 
class _AddEditEventScreenState extends State<AddEditEventScreen> {
  static const _fallbackCategory = 'Sonstiges';
 
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
 
  /// Arbeitskopien (gleiche IDs wie im gespeicherten Event). Änderungen
  /// wirken sich erst beim Speichern auf die Reise aus.
  final List<Person> _participants = [];
  final List<_CatEntry> _categories = [];
 
  /// Originalnamen gelöschter Kategorien (Ausgaben werden beim Speichern
  /// auf [_fallbackCategory] umgehängt).
  final List<String> _deletedCategories = [];
 
  /// Verwendung im gespeicherten Event: personId -> Anzahl Einträge,
  /// Kategoriename -> Anzahl Ausgaben.
  final Map<String, int> _personUsage = {};
  final Map<String, int> _categoryUsage = {};
 
  bool _isEdit = false;
  String? _eventId;
 
  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      _isEdit = true;
      _eventId = widget.eventId;
      final ev = context
          .read<AppProvider>()
          .events
          .firstWhere((e) => e.id == widget.eventId);
      _nameCtrl.text = ev.name;
      _startDate = ev.startDate;
      _endDate = ev.endDate;
      // Kopien mit gleicher ID: Abbrechen verändert die Reise nicht.
      _participants
          .addAll(ev.participants.map((p) => Person(id: p.id, name: p.name)));
      _categories.addAll(
        ev.customCategories.map((c) => _CatEntry(original: c, name: c)),
      );
 
      for (final e in ev.expenses) {
        _categoryUsage[e.category] = (_categoryUsage[e.category] ?? 0) + 1;
        final ids = {
          ...e.payers.map((p) => p.personId),
          ...e.beneficiaries.map((b) => b.personId),
        };
        for (final id in ids) {
          _personUsage[id] = (_personUsage[id] ?? 0) + 1;
        }
      }
      for (final m in ev.manualSettlements) {
        for (final id in {m.fromPersonId, m.toPersonId}) {
          _personUsage[id] = (_personUsage[id] ?? 0) + 1;
        }
      }
    }
  }
 
  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
 
  // ── Datum ──────────────────────────────────────────────────────────────────
 
  Future<void> _pickStartDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _endDate = d);
  }
 
  // ── Namensdialog ───────────────────────────────────────────────────────────
 
  Future<String?> _askName({
    required String title,
    required String label,
    required String confirm,
    required String? Function(String) validator,
    String? initial,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(
        title: title,
        label: label,
        confirmLabel: confirm,
        initial: initial,
        validator: validator,
      ),
    );
  }
 
  // ── Personen ───────────────────────────────────────────────────────────────
 
  String? _validatePerson(String v, {Person? exclude}) {
    final s = v.trim();
    if (s.isEmpty) return 'Name erforderlich';
    final lower = s.toLowerCase();
    for (final p in _participants) {
      if (!identical(p, exclude) && p.name.toLowerCase() == lower) {
        return 'Diese Person gibt es bereits';
      }
    }
    return null;
  }
 
  Future<void> _addParticipant() async {
    final v = await _askName(
      title: 'Person hinzufügen',
      label: 'Name',
      confirm: 'Hinzufügen',
      validator: (s) => _validatePerson(s),
    );
    if (v != null && mounted) {
      setState(() => _participants.add(Person(name: v)));
    }
  }
 
  Future<void> _renameParticipant(Person p) async {
    final v = await _askName(
      title: 'Person umbenennen',
      label: 'Name',
      confirm: 'Übernehmen',
      initial: p.name,
      validator: (s) => _validatePerson(s, exclude: p),
    );
    // Nur der Name ändert sich, die ID bleibt.
    if (v != null && mounted) setState(() => p.name = v);
  }
 
  Future<void> _removeParticipant(int index) async {
    final p = _participants[index];
    final n = _personUsage[p.id] ?? 0;
    if (n > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Person kann nicht entfernt werden'),
          content: Text(
            '${p.name} kommt in $n ${n == 1 ? 'Eintrag' : 'Einträgen'} '
            '(Ausgaben bzw. Ausgleichsbuchungen) vor. '
            'Entferne oder ändere zuerst diese Einträge, '
            'sonst stimmen die Salden nicht mehr.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _participants.removeAt(index));
  }
 
  // ── Kategorien ─────────────────────────────────────────────────────────────
 
  String? _validateCategory(String v, {_CatEntry? exclude}) {
    final s = v.trim();
    if (s.isEmpty) return 'Name erforderlich';
    final lower = s.toLowerCase();
    if (TravelEvent.defaultCategories.any((d) => d.toLowerCase() == lower)) {
      return 'Standardkategorie existiert bereits';
    }
    for (final c in _categories) {
      if (!identical(c, exclude) && c.name.toLowerCase() == lower) {
        return 'Kategorie existiert bereits';
      }
    }
    return null;
  }
 
  Future<void> _addCategory() async {
    final v = await _askName(
      title: 'Kategorie hinzufügen',
      label: 'Kategoriename',
      confirm: 'Hinzufügen',
      validator: (s) => _validateCategory(s),
    );
    if (v != null && mounted) {
      setState(() => _categories.add(_CatEntry(name: v)));
    }
  }
 
  Future<void> _renameCategory(_CatEntry c) async {
    final v = await _askName(
      title: 'Kategorie umbenennen',
      label: 'Kategoriename',
      confirm: 'Übernehmen',
      initial: c.name,
      validator: (s) => _validateCategory(s, exclude: c),
    );
    if (v != null && mounted) setState(() => c.name = v);
  }
 
  Future<void> _removeCategory(_CatEntry c) async {
    final n = c.original == null ? 0 : (_categoryUsage[c.original!] ?? 0);
    if (n > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kategorie löschen?'),
          content: Text(
            '"${c.name}" wird in $n ${n == 1 ? 'Ausgabe' : 'Ausgaben'} '
            'verwendet. Diese werden beim Speichern auf '
            '"$_fallbackCategory" gesetzt.',
          ),
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
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() {
      _categories.remove(c);
      if (c.original != null) _deletedCategories.add(c.original!);
    });
  }
 
  // ── Speichern ──────────────────────────────────────────────────────────────
 
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte mindestens eine Person hinzufügen')),
      );
      return;
    }
    final prov = context.read<AppProvider>();
    final customNames = _categories.map((c) => c.name).toList();
 
    if (_isEdit && _eventId != null) {
      final ev = prov.events.firstWhere((e) => e.id == _eventId);
      ev.name = _nameCtrl.text.trim();
      ev.startDate = _startDate;
      ev.endDate = _endDate;
 
      // Personen: gleiche IDs, ggf. neuer Name
      ev.participants
        ..clear()
        ..addAll(_participants);
 
      // Kategorien: alte -> neue Namen in einem Rutsch anwenden
      // (gleichzeitig, damit Tausch/Kettenumbenennungen korrekt sind).
      final mapping = <String, String>{};
      for (final c in _categories) {
        if (c.original != null && c.original != c.name) {
          mapping[c.original!] = c.name;
        }
      }
      for (final o in _deletedCategories) {
        mapping[o] = _fallbackCategory;
      }
      if (mapping.isNotEmpty) {
        for (final e in ev.expenses) {
          final neu = mapping[e.category];
          if (neu != null) e.category = neu;
        }
      }
      ev.customCategories
        ..clear()
        ..addAll(customNames);
 
      await prov.updateEvent(ev);
    } else {
      await prov.addEvent(
        TravelEvent(
          name: _nameCtrl.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          participants: _participants,
          customCategories: customNames,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }
 
  // ── UI ─────────────────────────────────────────────────────────────────────
 
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    final primary = Theme.of(context).colorScheme.primary;
 
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Reise bearbeiten' : 'Neue Reise'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
            tooltip: 'Speichern',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
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
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Name erforderlich' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Zeitraum',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
 
              // ── Personen ──
              Row(
                children: [
                  const Text(
                    'Personen',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Hinzufügen'),
                    onPressed: _addParticipant,
                  ),
                ],
              ),
              ..._participants.asMap().entries.map((entry) {
                final p = entry.value;
                final used = (_personUsage[p.id] ?? 0) > 0;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: primary.withValues(alpha: 0.2),
                    child: Text(
                      p.name[0].toUpperCase(),
                      style: TextStyle(color: primary, fontSize: 13),
                    ),
                  ),
                  title: Text(p.name),
                  onTap: () => _renameParticipant(p),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Umbenennen',
                        onPressed: () => _renameParticipant(p),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: used ? Colors.grey : Colors.red,
                          size: 20,
                        ),
                        tooltip: used ? 'In Verwendung' : 'Entfernen',
                        onPressed: () => _removeParticipant(entry.key),
                      ),
                    ],
                  ),
                );
              }),
              if (_participants.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Noch keine Personen',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
              const SizedBox(height: 20),
 
              // ── Kategorien ──
              Row(
                children: [
                  const Text(
                    'Eigene Kategorien',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Hinzufügen'),
                    onPressed: _addCategory,
                  ),
                ],
              ),
              Text(
                'Standard: ${TravelEvent.defaultCategories.join(', ')}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _categories
                    .map(
                      (c) => InputChip(
                        label: Text(
                          c.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        tooltip: 'Tippen zum Umbenennen',
                        onPressed: () => _renameCategory(c),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removeCategory(c),
                      ),
                    )
                    .toList(),
              ),
              if (_categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Keine eigenen Kategorien',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(
                    _isEdit ? 'Änderungen speichern' : 'Reise erstellen',
                  ),
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
 
/// Dialog mit Textfeld und Inline-Validierung. Besitzt seinen eigenen
/// Controller, damit dieser sauber (nach der Schließ-Animation) entsorgt wird.
class _NameDialog extends StatefulWidget {
  final String title;
  final String label;
  final String confirmLabel;
  final String? initial;
  final String? Function(String) validator;
 
  const _NameDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.validator,
    this.initial,
  });
 
  @override
  State<_NameDialog> createState() => _NameDialogState();
}
 
class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  String? _error;
 
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
 
  void _submit() {
    final v = _ctrl.text.trim();
    final err = widget.validator(v);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, v);
  }
 
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
