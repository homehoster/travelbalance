import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/currency_service.dart';
import '../utils/calculations.dart';

class AddEditExpenseScreen extends StatefulWidget {
  final String eventId;
  final String? expenseId;
  const AddEditExpenseScreen({
    super.key,
    required this.eventId,
    this.expenseId,
  });

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  final _descCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '1.0');
  String _currency = 'EUR';
  String _category = TravelEvent.defaultCategories.first;
  bool _isEqualSplit = true;
  bool _loadingRate = false;

  final Map<String, TextEditingController> _payerCtrls = {};
  final Map<String, bool> _payerEnabled = {};
  final Map<String, TextEditingController> _benCtrls = {};
  final Map<String, bool> _benEnabled = {};

  List<Person> _participants = [];
  List<String> _categories = [];
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    final prov = context.read<AppProvider>();
    final ev = prov.events.firstWhere((e) => e.id == widget.eventId);
    setState(() {
      _participants = ev.participants;
      _categories = ev.allCategories;
      if (!_categories.contains(_category)) _category = _categories.first;
    });

    for (final p in _participants) {
      _payerCtrls[p.id] = TextEditingController(text: '0,00');
      _payerEnabled[p.id] = false;
      _benCtrls[p.id] = TextEditingController(text: '0,00');
      _benEnabled[p.id] = true;
    }

    if (widget.expenseId != null) {
      _isEdit = true;
      final exp = ev.expenses.firstWhere((e) => e.id == widget.expenseId);
      setState(() {
        _date = exp.date;
        _descCtrl.text = exp.description;
        _noteCtrl.text = exp.note;
        _currency = exp.currency;
        _rateCtrl.text = exp.exchangeRateToEur.toStringAsFixed(6);
        _category = exp.category;
        _isEqualSplit = exp.isEqualSplit;
      });
      for (final payer in exp.payers) {
        _payerEnabled[payer.personId] = true;
        _payerCtrls[payer.personId]?.text = _toInput(payer.amount);
      }
      for (final ben in exp.beneficiaries) {
        _benEnabled[ben.personId] = true;
        final orig = exp.exchangeRateToEur > 0
            ? ben.amount / exp.exchangeRateToEur
            : ben.amount;
        _benCtrls[ben.personId]?.text = _toInput(orig);
      }
      for (final p in _participants) {
        if (exp.beneficiaries.every((b) => b.personId != p.id)) {
          _benEnabled[p.id] = _isEqualSplit;
        }
      }
    } else {
      for (final p in _participants) {
        _benEnabled[p.id] = true;
      }
    }
  }

  // Eingabe: Komma als Dezimaltrennzeichen
  String _toInput(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
  double _parseInput(String s) =>
      double.tryParse(s.replaceAll(',', '.')) ?? 0.0;

  @override
  void dispose() {
    _descCtrl.dispose();
    _noteCtrl.dispose();
    _rateCtrl.dispose();
    for (final c in _payerCtrls.values) {
      c.dispose();
    }
    for (final c in _benCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchRate() async {
    if (_currency == 'EUR') {
      setState(() => _rateCtrl.text = '1.000000');
      return;
    }
    setState(() => _loadingRate = true);
    final rate = await CurrencyService.getRateToEur(_currency);
    if (mounted) {
      setState(() {
        _rateCtrl.text = rate.toStringAsFixed(6);
        _loadingRate = false;
      });
    }
  }

  double get _rate => double.tryParse(_rateCtrl.text) ?? 1.0;

  // Summe der manuellen Eingaben in Originalwährung
  double get _totalBenOriginal => _benCtrls.entries
            .where((e) => _benEnabled[e.key] == true)
            .fold(0.0, (s, e) => s + _parseInput(e.value.text));

  double get _totalPayersEur {
    double sum = 0;
    for (final e in _payerCtrls.entries) {
      if (_payerEnabled[e.key] == true) {
        sum += _parseInput(e.value.text) * _rate;
      }
    }
    return sum;
  }

  double get _totalPayersOriginal {
    double sum = 0;
    for (final e in _payerCtrls.entries) {
      if (_payerEnabled[e.key] == true) {
        sum += _parseInput(e.value.text);
      }
    }
    return sum;
  }

  double get _totalBenEur {
    if (_isEqualSplit) {
      final n = _participants.where((p) => _benEnabled[p.id] == true).length;
      return n == 0 ? 0 : _totalPayersEur;
    }
    return _totalBenOriginal * _rate; // ← Umrechnung in EUR
  }

  double get _benDiff => _totalPayersEur - _totalBenEur;
  double get _benDiffOriginal => _totalPayersOriginal - _totalBenOriginal;
  

  List<BeneficiaryEntry> _buildBeneficiaries() {
    final enabledBens = _participants
        .where((p) => _benEnabled[p.id] == true)
        .toList();
    if (_isEqualSplit) {
      if (enabledBens.isEmpty) return [];
      final share = _totalPayersEur / enabledBens.length;
      return enabledBens
          .map((p) => BeneficiaryEntry(personId: p.id, amount: share))
          .toList();
    } else {
      return _participants
          .where((p) => _benEnabled[p.id] == true)
          .map(
            (p) => BeneficiaryEntry(
              personId: p.id,
              amount: _parseInput(_benCtrls[p.id]?.text ?? '0') * _rate,
            ),
          )
          .toList();
    }
  }

  List<PayerEntry> _buildPayers() {
    return _participants
        .where((p) => _payerEnabled[p.id] == true)
        .map(
          (p) => PayerEntry(
            personId: p.id,
            amount: _parseInput(_payerCtrls[p.id]?.text ?? '0'),
          ),
        )
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final payers = _buildPayers();
    if (payers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mindestens eine zahlende Person angeben'),
        ),
      );
      return;
    }
    if (_totalPayersOriginal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gesamtbetrag muss größer 0 sein')),
      );
      return;
    }
    final beneficiaries = _buildBeneficiaries();
    if (beneficiaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mindestens eine begünstigte Person angeben'),
        ),
      );
      return;
    }
    final prov = context.read<AppProvider>();

    if (_isEdit && widget.expenseId != null) {
      final ev = prov.events.firstWhere((e) => e.id == widget.eventId);
      final exp = ev.expenses.firstWhere((e) => e.id == widget.expenseId);
      exp.date = _date;
      exp.description = _descCtrl.text.trim();
      exp.payers = payers;
      exp.currency = _currency;
      exp.exchangeRateToEur = _rate;
      exp.category = _category;
      exp.note = _noteCtrl.text.trim();
      exp.beneficiaries = beneficiaries;
      exp.isEqualSplit = _isEqualSplit;
      await prov.updateExpense(widget.eventId, exp);
    } else {
      await prov.addExpense(
        widget.eventId,
        Expense(
          date: _date,
          description: _descCtrl.text.trim(),
          payers: payers,
          currency: _currency,
          exchangeRateToEur: _rate,
          category: _category,
          note: _noteCtrl.text.trim(),
          beneficiaries: beneficiaries,
          isEqualSplit: _isEqualSplit,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yy', 'de_DE');
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ausgabe bearbeiten' : 'Neue Ausgabe'),
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
            12,
            16,
            MediaQuery.of(context).viewInsets.bottom + 80,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Datum
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Datum:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        locale: const Locale('de', 'DE'),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                    child: Text(fmt.format(_date)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Beschreibung
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Währung + Kurs
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: const InputDecoration(
                        labelText: 'Währung',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: CurrencyService.supportedCurrencies
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _currency = v);
                          _fetchRate();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _rateCtrl,
                      decoration: InputDecoration(
                        labelText: '1 $_currency = ? EUR',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: _loadingRate
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                onPressed: _fetchRate,
                                tooltip: 'Kurs abrufen',
                              ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (_currency != 'EUR')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '1 $_currency = ${double.tryParse(_rateCtrl.text)?.toStringAsFixed(4) ?? "-"} EUR',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              const SizedBox(height: 12),

              // Kategorie
              DropdownButtonFormField<String>(
                value: _categories.contains(_category)
                    ? _category
                    : _categories.first,
                decoration: const InputDecoration(
                  labelText: 'Kategorie',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 12),

              // Notiz
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notiz (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // ---- ZAHLER ----
              _SectionCard(
                color: primaryColor,
                icon: Icons.payment,
                title: 'Wer hat bezahlt?',
                trailing: Text(
                  '${fmtAmt(_totalPayersOriginal, _currency)}'
                  '${_currency != 'EUR' ? ' = ${fmtEur(_totalPayersEur)}' : ''}',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                child: Column(
                  children: _participants
                      .map(
                        (p) => _PayerRow(
                          person: p,
                          enabled: _payerEnabled[p.id] ?? false,
                          controller: _payerCtrls[p.id]!,
                          currency: _currency,
                          rate: _rate,
                          onToggle: (v) => setState(() {
                            _payerEnabled[p.id] = v;
                            if (!v) _payerCtrls[p.id]?.text = '0,00';
                          }),
                          onChanged: () => setState(() {}),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),

              // ---- BEGÜNSTIGTE ----
              _SectionCard(
                color: Colors.green[700]!,
                icon: Icons.people_outline,
                title: 'Für wen wurde bezahlt?',
                trailing: null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SplitToggle(
                      isEqual: _isEqualSplit,
                      onChanged: (v) => setState(() => _isEqualSplit = v),
                    ),
                    const SizedBox(height: 8),
                    ..._participants.map(
                      (p) => _isEqualSplit
                          ? _BeneficiaryEqualRow(
                              person: p,
                              enabled: _benEnabled[p.id] ?? true,
                              shareEur: () {
                                final n = _participants
                                    .where((x) => _benEnabled[x.id] == true)
                                    .length;
                                return n == 0 ? 0.0 : _totalPayersEur / n;
                              }(),
                              shareOriginal: () {
                                final n = _participants
                                    .where((x) => _benEnabled[x.id] == true)
                                    .length;
                                return n == 0 ? 0.0 : _totalPayersOriginal / n;
                              }(),
                              currency: _currency,
                              onToggle: (v) =>
                                  setState(() => _benEnabled[p.id] = v),
                            )
                          : _BeneficiaryManualRow(
                              person: p,
                              enabled: _benEnabled[p.id] ?? true,
                              controller: _benCtrls[p.id]!,
                              currency: _currency,
                              onToggle: (v) => setState(() {
                                _benEnabled[p.id] = v;
                                if (!v) _benCtrls[p.id]?.text = '0,00';
                              }),
                              onChanged: () => setState(() {}),
                            ),
                    ),
                    if (!_isEqualSplit) ...[
                      const Divider(),
                      _DiffRow(
                        total: _totalPayersEur,
                        allocated: _totalBenEur,
                        diff: _benDiff,
                        currency: _currency,
                        totalOriginal: _totalPayersOriginal,
                        allocatedOriginal: _totalBenOriginal,
                        diffOriginal: _benDiffOriginal,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(
                    _isEdit ? 'Änderungen speichern' : 'Ausgabe speichern',
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

// ── Hilfswidgets ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;
  const _SectionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}

class _PayerRow extends StatefulWidget {
  final Person person;
  final bool enabled;
  final TextEditingController controller;
  final String currency;
  final double rate;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChanged;
  const _PayerRow({
    required this.person,
    required this.enabled,
    required this.controller,
    required this.currency,
    required this.rate,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  State<_PayerRow> createState() => _PayerRowState();
}

class _PayerRowState extends State<_PayerRow> {
  double _parse() =>
      double.tryParse(widget.controller.text.replaceAll(',', '.')) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final amtEur = _parse() * widget.rate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: widget.enabled,
            onChanged: (v) => widget.onToggle(v ?? false),
          ),
          Expanded(
            child: Text(
              widget.person.name,
              style: TextStyle(color: widget.enabled ? null : Colors.grey),
            ),
          ),
          if (widget.enabled) ...[
            SizedBox(
              width: 100,
              child: TextFormField(
                controller: widget.controller,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: widget.currency,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                onChanged: (_) => widget.onChanged(),
                onTap: () => widget.controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: widget.controller.text.length,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (widget.currency != 'EUR')
              SizedBox(
                width: 72,
                child: Text(
                  '= ${fmtEur(amtEur)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.right,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SplitToggle extends StatelessWidget {
  final bool isEqual;
  final ValueChanged<bool> onChanged;
  const _SplitToggle({required this.isEqual, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleBtn(
            label: 'Gleich aufteilen',
            icon: Icons.people,
            selected: isEqual,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ToggleBtn(
            label: 'Manuell',
            icon: Icons.tune,
            selected: !isEqual,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : Colors.grey[700],
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeneficiaryEqualRow extends StatelessWidget {
  final Person person;
  final bool enabled;
  final double shareEur;
  final double shareOriginal;
  final String currency;
  final ValueChanged<bool> onToggle;
  const _BeneficiaryEqualRow({
    required this.person,
    required this.enabled,
    required this.shareEur,
    required this.shareOriginal,
    required this.currency,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(value: enabled, onChanged: (v) => onToggle(v ?? true)),
          Expanded(
            child: Text(
              person.name,
              style: TextStyle(color: enabled ? null : Colors.grey),
            ),
          ),
          if (enabled)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtAmt(shareOriginal, currency),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (currency != 'EUR')
                  Text(
                    fmtEur(shareEur),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BeneficiaryManualRow extends StatelessWidget {
  final Person person;
  final bool enabled;
  final TextEditingController controller;
  final String currency;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChanged;
  const _BeneficiaryManualRow({
    required this.person,
    required this.enabled,
    required this.controller,
    required this.currency,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(value: enabled, onChanged: (v) => onToggle(v ?? true)),
          Expanded(
            child: Text(
              person.name,
              style: TextStyle(color: enabled ? null : Colors.grey),
            ),
          ),
          if (enabled)
            SizedBox(
              width: 120,
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: currency, // ← gleiche Währung wie Zahler
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                onChanged: (_) => onChanged(),
                onTap: () => controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  final double total;
  final double allocated;
  final double diff;
  final String currency;
  final double totalOriginal;
  final double allocatedOriginal;
  final double diffOriginal;
  const _DiffRow({
    required this.total,
    required this.allocated,
    required this.diff,
    required this.currency,
    required this.totalOriginal,
    required this.allocatedOriginal,
    required this.diffOriginal,
  });

  @override
  Widget build(BuildContext context) {
    final isOk = diffOriginal.abs() < 0.01;
    final color =
        isOk ? Colors.green : (diffOriginal < 0 ? Colors.red : Colors.orange);
    final foreign = currency != 'EUR';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _InfoRow('Gesamt Ausgabe:', fmtAmt(totalOriginal, currency)),
          if (foreign) _InfoRow('  (in EUR):', fmtEur(total)),
          _InfoRow('Aufgeteilt:', fmtAmt(allocatedOriginal, currency)),
          if (foreign) _InfoRow('  (in EUR):', fmtEur(allocated)),
          _InfoRow(
            'Differenz:',
            '${diffOriginal >= 0 ? '+' : ''}${fmtAmt(diffOriginal, currency)}',
            valueColor: color,
            bold: true,
          ),
          if (foreign && !isOk)
            _InfoRow('  (in EUR):',
                '${diff >= 0 ? '+' : ''}${fmtEur(diff)}'),
          if (!isOk)
            Text(
              diffOriginal > 0
                  ? 'Noch ${fmtAmt(diffOriginal, currency)} nicht zugewiesen'
                  : '${fmtAmt(-diffOriginal, currency)} zu viel zugewiesen',
              style: TextStyle(fontSize: 11, color: color),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _InfoRow(this.label, this.value, {this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
