import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../utils/calculations.dart';
import '../widgets/app_drawer.dart';
import '../services/pdf_export_service.dart';
import 'add_edit_expense_screen.dart';
import 'add_edit_event_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _tabIndex = 0;
  DateTime? _statFrom; // null = erste Ausgabe
  DateTime? _statTo;   // null = letzte Ausgabe

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() => _tabIndex = _tabCtrl.index));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final evIdx = prov.events.indexWhere((e) => e.id == widget.eventId);
    if (evIdx < 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nicht gefunden')),
        body: const Center(child: Text('Reise nicht gefunden')),
      );
    }
    final ev = prov.events[evIdx];

    return Scaffold(
      appBar: AppBar(
        title: Text(ev.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Als PDF teilen',
            onPressed: () async {
              try {
                await PdfExportService.shareEventPdf(ev, from: _statFrom, to: _statTo);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PDF-Fehler: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Bearbeiten',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditEventScreen(eventId: ev.id),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'Ausgaben'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Statistik'),
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Salden'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ExpensesTab(event: ev, eventId: widget.eventId),
          _StatisticsTab(
            event: ev,
            from: _statFrom,
            to: _statTo,
            onRangeChanged: (f, t) => setState(() {
              _statFrom = f;
              _statTo = t;
            }),
          ),
          _BalancesTab(event: ev, eventId: widget.eventId),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditExpenseScreen(eventId: widget.eventId),
                ),
              ),
              tooltip: 'Neue Ausgabe',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AUSGABEN TAB
// ══════════════════════════════════════════════════════════════════════════════
class _ExpensesTab extends StatelessWidget {
  final TravelEvent event;
  final String eventId;
  const _ExpensesTab({required this.event, required this.eventId});

  @override
  Widget build(BuildContext context) {
    if (event.expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Noch keine Ausgaben',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tippe auf + um eine Ausgabe hinzuzufügen',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      );
    }

    final sorted = [...event.expenses]
      ..sort((a, b) => b.date.compareTo(a.date));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) =>
          _ExpenseCard(expense: sorted[i], event: event, eventId: eventId),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final TravelEvent event;
  final String eventId;
  const _ExpenseCard({
    required this.expense,
    required this.event,
    required this.eventId,
  });

  String _personName(String id) => event.participants
      .firstWhere((p) => p.id == id, orElse: () => Person(name: '?'))
      .name;

  @override
  Widget build(BuildContext context) {
    final prov = context.read<AppProvider>();
    final fmt = DateFormat('dd.MM.yy', 'de_DE');
    final payerNames = expense.payers
        .map((p) => _personName(p.personId))
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AddEditExpenseScreen(eventId: eventId, expenseId: expense.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CategoryBadge(expense.category),
                  const SizedBox(width: 8),
                  Text(
                    fmt.format(expense.date),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmtEur(expense.totalEur),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (expense.currency != 'EUR')
                        Text(
                          '(${fmtAmt(expense.totalOriginal, expense.currency)})',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Ausgabe löschen?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Abbrechen'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Löschen'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await prov.deleteExpense(eventId, expense.id);
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Löschen',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (expense.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(expense.description, style: const TextStyle(fontSize: 13)),
              ],
              const SizedBox(height: 6),
              Text(
                'Bezahlt von: $payerNames',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              if (expense.note.isNotEmpty)
                Text(
                  'Notiz: ${expense.note}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge(this.category);

  Color get _color {
    const colors = {
      'Unterkunft': Colors.blue,
      'Essen & Trinken': Colors.orange,
      'Transport': Colors.green,
      'Aktivitäten': Colors.purple,
      'Einkaufen': Colors.pink,
      'Maut': Colors.red,
      'Sonstiges': Colors.grey,
    };
    return colors[category] ?? Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATISTIK TAB
// ══════════════════════════════════════════════════════════════════════════════
class _StatisticsTab extends StatefulWidget {
  final TravelEvent event;
  final DateTime? from;
  final DateTime? to;
  final void Function(DateTime? from, DateTime? to) onRangeChanged;
  const _StatisticsTab({
    required this.event,
    required this.from,
    required this.to,
    required this.onRangeChanged,
  });

  @override
  State<_StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<_StatisticsTab> {
  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  // Standard: erste / letzte Ausgabe (bzw. Reisezeitraum ohne Ausgaben)
  DateTime get _defaultFrom {
    if (widget.event.expenses.isEmpty) return widget.event.startDate;
    return _day((widget.event.expenses.map((e) => e.date).toList()..sort()).first);
  }

  DateTime get _defaultTo {
    if (widget.event.expenses.isEmpty) return widget.event.endDate;
    return _day((widget.event.expenses.map((e) => e.date).toList()..sort()).last);
  }

  DateTime get _fromDate => widget.from ?? _defaultFrom;
  DateTime get _toDate => widget.to ?? _defaultTo;

  List<Expense> get _filtered => widget.event.expenses.where((e) {
      final d = _day(e.date);
      return !d.isBefore(_day(_fromDate)) && !d.isAfter(_day(_toDate));
    }).toList();

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy', 'de_DE');
    final expenses = _filtered;
    final total = expenses.fold(0.0, (s, e) => s + e.totalEur);

    // Ausgaben je Person (Begünstigte)
    final personOwed = <String, double>{};
    for (final p in widget.event.participants) {
      personOwed[p.id] = 0;
    }
    for (final exp in expenses) {
      for (final ben in exp.beneficiaries) {
        personOwed[ben.personId] = (personOwed[ben.personId] ?? 0) + ben.amount;
      }
    }

    // Bezahlt je Person (Zahler)
    final personPaid = <String, double>{};
    for (final p in widget.event.participants) {
      personPaid[p.id] = 0;
    }
    for (final exp in expenses) {
      for (final payer in exp.payers) {
        personPaid[payer.personId] =
            (personPaid[payer.personId] ?? 0) +
            payer.amount * exp.exchangeRateToEur;
      }
    }
    final totalPaid = personPaid.values.fold(0.0, (s, v) => s + v);

    // Ausgaben je Kategorie
    final catTotals = <String, double>{};
    for (final exp in expenses) {
      catTotals[exp.category] = (catTotals[exp.category] ?? 0) + exp.totalEur;
    }
    final catSorted = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // firstDate / lastDate für DatePicker-Grenzen
    final firstExpDate = widget.event.expenses.isNotEmpty
        ? (widget.event.expenses.map((e) => e.date).toList()..sort()).first
        : widget.event.startDate;
    final lastExpDate = widget.event.expenses.isNotEmpty
        ? (widget.event.expenses.map((e) => e.date).toList()..sort()).last
        : widget.event.endDate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zeitraumfilter
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zeitraum',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _fromDate,
                              firstDate: firstExpDate,
                              lastDate: _toDate,
                              locale: const Locale('de', 'DE'),
                            );
                            // "Von"-Picker
                            if (d != null) widget.onRangeChanged(d, widget.to);   
                          },
                          child: Text(
                            'Von: ${fmt.format(_fromDate)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _toDate,
                              firstDate: _fromDate,
                              lastDate: lastExpDate,
                              locale: const Locale('de', 'DE'),
                            );
                            // "Bis"-Picker
                            if (d != null) widget.onRangeChanged(widget.from, d);
                          },
                          child: Text(
                            'Bis: ${fmt.format(_toDate)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Zurücksetzen',
                        onPressed: () => widget.onRangeChanged(null, null),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Gesamtsumme
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.summarize, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gesamtausgaben'),
                      Text(
                        fmtEur(total),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${expenses.length} Ausgaben',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Bezahlt je Person
          const Text(
            'Bezahlt je Person',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: widget.event.participants.map((p) {
                  final amt = personPaid[p.id] ?? 0;
                  final pct = totalPaid > 0 ? amt / totalPaid : 0.0;
                  return _StatRow(
                    name: p.name,
                    amount: amt,
                    percent: pct,
                    color: Colors.blue[700]!,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Ausgaben je Person (Anteil)
          const Text(
            'Ausgaben je Person (Anteil)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: widget.event.participants.map((p) {
                  final amt = personOwed[p.id] ?? 0;
                  final pct = total > 0 ? amt / total : 0.0;
                  return _StatRow(
                    name: p.name,
                    amount: amt,
                    percent: pct,
                    color: Theme.of(context).colorScheme.primary,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Ausgaben je Kategorie
          if (catSorted.isNotEmpty) ...[
            const Text(
              'Ausgaben nach Kategorie',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: catSorted.map((e) {
                    final pct = total > 0 ? e.value / total : 0.0;
                    return _StatRow(
                      name: e.key,
                      amount: e.value,
                      percent: pct,
                      color: Colors.green[700]!,
                      nameWidth: 110,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String name;
  final double amount;
  final double percent;
  final Color color;
  final double nameWidth;
  const _StatRow({
    required this.name,
    required this.amount,
    required this.percent,
    required this.color,
    this.nameWidth = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: nameWidth,
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: percent,
              color: color,
              backgroundColor: Colors.grey[200],
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              fmtEur(amount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SALDEN TAB
// ══════════════════════════════════════════════════════════════════════════════
class _BalancesTab extends StatefulWidget {
  final TravelEvent event;
  final String eventId;
  const _BalancesTab({required this.event, required this.eventId});

  @override
  State<_BalancesTab> createState() => _BalancesTabState();
}

class _BalancesTabState extends State<_BalancesTab> {
  void _showSettlementDialog(BuildContext context) {
    final prov = context.read<AppProvider>();
    final participants = widget.event.participants;
    if (participants.length < 2) return;

    String fromId = participants[0].id;
    String toId = participants[1].id;
    DateTime date = DateTime.now();
    final amtCtrl = TextEditingController(text: '0,00');
    final fmt = DateFormat('dd.MM.yy', 'de_DE');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Ausgleichsbuchung'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Datum
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(fmt.format(date)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('de', 'DE'),
                    );
                    if (d != null) setDlg(() => date = d);
                  },
                ),
                const SizedBox(height: 16),
                // "Von (Zahler)"
                DropdownButtonFormField<String>(
                  key: ValueKey('from_$fromId'),
                  initialValue: fromId,
                  decoration: const InputDecoration(
                    labelText: 'Von (Zahler)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: participants
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                  if (v == null) return;
                  setDlg(() {
                    if (v == toId) toId = fromId; // tauschen statt blockieren
                    fromId = v;
                  });
                },
                ),
                const SizedBox(height: 12),
                // "An (Empfänger)"
                DropdownButtonFormField<String>(
                  key: ValueKey('to_$toId'),
                  initialValue: toId,
                  decoration: const InputDecoration(
                    labelText: 'An (Empfänger)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: participants
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setDlg(() {
                      if (v == fromId) fromId = toId; // tauschen statt blockieren 
                      toId = v;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Betrag
                TextField(
                  controller: amtCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Betrag (€)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixText: '€',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final amt =
                    double.tryParse(amtCtrl.text.replaceAll(',', '.')) ?? 0.0;
                if (amt <= 0) return;
                if (fromId == toId) return;
                await prov.addManualSettlement(
                  widget.eventId,
                  ManualSettlement(
                    fromPersonId: fromId,
                    toPersonId: toId,
                    date: date,
                    amount: amt,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final ev = prov.events.firstWhere(
      (e) => e.id == widget.eventId,
      orElse: () => widget.event,
    );
    final balances = calculateBalances(ev);
    final settlements = calculateSettlements(balances);
    final fmt = DateFormat('dd.MM.yy', 'de_DE');

    String _name(String id) => ev.participants
        .firstWhere((p) => p.id == id, orElse: () => Person(name: '?'))
        .name;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kontostand
          const Text(
            'Kontostand je Person',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...balances.map((b) => _BalanceCard(balance: b)),
          const SizedBox(height: 16),

          // Empfohlene Ausgleichszahlungen
          const Text(
            'Empfohlene Ausgleichszahlungen',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (settlements.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Alles ausgeglichen!'),
                  ],
                ),
              ),
            )
          else
            ...settlements.map((s) => _SettlementCard(settlement: s)),
          const SizedBox(height: 20),

          // Ausgleichsbuchungen (manuell)
          Row(
            children: [
              const Text(
                'Ausgleichsbuchungen',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Erfassen'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                onPressed: () => _showSettlementDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ev.manualSettlements.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Noch keine Ausgleichsbuchungen',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else
            ...ev.manualSettlements
                .sorted((a, b) => b.date.compareTo(a.date))
                .map(
                  (ms) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.green[50],
                    child: ListTile(
                      leading: const Icon(
                        Icons.handshake_outlined,
                        color: Colors.green,
                      ),
                      title: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: _name(ms.fromPersonId),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' → '),
                            TextSpan(
                              text: _name(ms.toPersonId),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      subtitle: Text(
                        fmt.format(ms.date),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fmtEur(ms.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Buchung löschen?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Abbrechen'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Löschen'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true && context.mounted) {
                                await prov.deleteManualSettlement(
                                  widget.eventId,
                                  ms.id,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

extension _ListSort<T> on List<T> {
  List<T> sorted(Comparator<T> compare) => [...this]..sort(compare);
}

class _BalanceCard extends StatelessWidget {
  final PersonBalance balance;
  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final isPositive = balance.net >= 0;
    final color = isPositive ? Colors.green[700]! : Colors.red[700]!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                balance.personName[0].toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    balance.personName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Bezahlt: ${fmtEur(balance.paid)}  Anteil: ${fmtEur(balance.owed)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${balance.net >= 0 ? '+' : ''}${fmtEur(balance.net)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
                Text(
                  isPositive ? 'bekommt zurück' : 'schuldet',
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final Settlement settlement;
  const _SettlementCard({required this.settlement});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.arrow_forward, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  children: [
                    TextSpan(
                      text: settlement.fromPersonName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' zahlt '),
                    TextSpan(
                      text: settlement.toPersonName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              fmtEur(settlement.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
