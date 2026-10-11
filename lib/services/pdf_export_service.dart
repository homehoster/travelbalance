import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../utils/calculations.dart';

/// Erzeugt eine PDF mit Salden, Statistik und Ausgabenliste einer Reise
/// und öffnet das Android-/iOS-Teilen-Menü.
class PdfExportService {
  static Future<void> shareEventPdf(
    TravelEvent ev, {
    DateTime? from,
    DateTime? to,
  }) async {
    final bytes = await buildPdf(ev, from: from, to: to);
    final safe = ev.name.replaceAll(RegExp(r'[^\w\-]+'), '_');
    await Printing.sharePdf(bytes: bytes, filename: 'TravelBalance_$safe.pdf');
  }

  static Future<Uint8List> buildPdf(
    TravelEvent ev, {
    DateTime? from,
    DateTime? to,
  }) async {
    // Schrift mit €-Unterstützung laden (benötigt Internet),
    // sonst Standardschrift und "€" -> "EUR".
    pw.ThemeData? theme;
    var fallback = false;
    try {
      final regular = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();
      theme = pw.ThemeData.withFont(base: regular, bold: bold);
    } catch (_) {
      fallback = true;
    }
    String t(String s) => fallback ? s.replaceAll('€', 'EUR') : s;

    final dateFmt = DateFormat('dd.MM.yyyy', 'de_DE');
    final doc = pw.Document(theme: theme);
    const headColor = PdfColor.fromInt(0xFF1565C0);

    pw.Widget h1(String s) => pw.Text(
      t(s),
      style: pw.TextStyle(
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: headColor,
      ),
    );
    pw.Widget h2(String s) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(
        t(s),
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
    );
    pw.Widget header(String section) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        h1('${ev.name} – $section'),
        pw.SizedBox(height: 2),
        pw.Text(
          '${dateFmt.format(ev.startDate)} – ${dateFmt.format(ev.endDate)}  ·  '
          '${ev.participants.map((p) => p.name).join(', ')}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Divider(),
      ],
    );
    pw.Widget footer(pw.Context c) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'TravelBalance · erstellt ${dateFmt.format(DateTime.now())} · '
        'Seite ${c.pageNumber}/${c.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );

    String name(String id) => ev.participants
        .firstWhere((p) => p.id == id, orElse: () => Person(name: '?'))
        .name;

    // ───────────────────────── SALDEN ─────────────────────────
    final balances = calculateBalances(ev);
    final settlements = calculateSettlements(balances);
    final manual = [...ev.manualSettlements]
      ..sort((a, b) => b.date.compareTo(a.date));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: footer,
        build: (_) => [
          header('Salden'),
          h2('Kontostand je Person'),
          pw.TableHelper.fromTextArray(
            headers: ['Person', 'Bezahlt', 'Anteil', 'Saldo'],
            data: balances
                .map(
                  (b) => [
                    b.personName,
                    t(fmtEur(b.paid)),
                    t(fmtEur(b.owed)),
                    t('${b.net >= 0 ? '+' : ''}${fmtEur(b.net)}'),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          h2('Empfohlene Ausgleichszahlungen'),
          if (settlements.isEmpty)
            pw.Text('Alles ausgeglichen.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Von', 'An', 'Betrag'],
              data: settlements
                  .map(
                    (s) => [
                      s.fromPersonName,
                      s.toPersonName,
                      t(fmtEur(s.amount)),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignments: {2: pw.Alignment.centerRight},
            ),
          h2('Erfasste Ausgleichsbuchungen'),
          if (manual.isEmpty)
            pw.Text('Keine Ausgleichsbuchungen.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Datum', 'Von', 'An', 'Betrag'],
              data: manual
                  .map(
                    (m) => [
                      dateFmt.format(m.date),
                      name(m.fromPersonId),
                      name(m.toPersonId),
                      t(fmtEur(m.amount)),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignments: {3: pw.Alignment.centerRight},
            ),
        ],
      ),
    );

    // ───────────────────────── STATISTIK ─────────────────────────
    final all = ev.expenses;
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    final dates = all.map((e) => day(e.date)).toList()..sort();
    final fromD = from != null
        ? day(from)
        : (dates.isNotEmpty ? dates.first : day(ev.startDate));
    final toD = to != null
        ? day(to)
        : (dates.isNotEmpty ? dates.last : day(ev.endDate));
    final expenses = all
        .where((e) => !day(e.date).isBefore(fromD) && !day(e.date).isAfter(toD))
        .toList();

    final total = expenses.fold(0.0, (s, e) => s + e.totalEur);
    final paid = {for (final p in ev.participants) p.id: 0.0};
    final owed = {for (final p in ev.participants) p.id: 0.0};
    final cats = <String, double>{};
    for (final e in expenses) {
      for (final p in e.payers) {
        paid[p.personId] =
            (paid[p.personId] ?? 0) + p.amount * e.exchangeRateToEur;
      }
      for (final b in e.beneficiaries) {
        owed[b.personId] = (owed[b.personId] ?? 0) + b.amount;
      }
      cats[e.category] = (cats[e.category] ?? 0) + e.totalEur;
    }
    final catSorted = cats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    String pct(double v) =>
        total > 0 ? '${(v / total * 100).toStringAsFixed(1)} %' : '–';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: footer,
        build: (_) => [
          header('Statistik'),
          pw.Text(
            'Zeitraum: ${dateFmt.format(fromD)} – ${dateFmt.format(toD)}',
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Gesamtausgaben (${expenses.length} Ausgaben)'),
                pw.Text(
                  t(fmtEur(total)),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          h2('Bezahlt je Person'),
          pw.TableHelper.fromTextArray(
            headers: ['Person', 'Betrag', 'Anteil'],
            data: ev.participants
                .map(
                  (p) => [
                    p.name,
                    t(fmtEur(paid[p.id] ?? 0)),
                    pct(paid[p.id] ?? 0),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
          ),
          h2('Ausgaben je Person (Anteil)'),
          pw.TableHelper.fromTextArray(
            headers: ['Person', 'Betrag', 'Anteil'],
            data: ev.participants
                .map(
                  (p) => [
                    p.name,
                    t(fmtEur(owed[p.id] ?? 0)),
                    pct(owed[p.id] ?? 0),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
          ),
          h2('Ausgaben nach Kategorie'),
          if (catSorted.isEmpty)
            pw.Text('Keine Ausgaben im Zeitraum.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Kategorie', 'Betrag', 'Anteil'],
              data: catSorted
                  .map((e) => [e.key, t(fmtEur(e.value)), pct(e.value)])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignments: {
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
            ),
        ],
      ),
    );

    // ───────────────────────── AUSGABEN ─────────────────────────
    final sorted = [...ev.expenses]..sort((a, b) => a.date.compareTo(b.date));
    final shortFmt = DateFormat('dd.MM.yy', 'de_DE');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        footer: footer,
        build: (_) => [
          header('Ausgaben'),
          if (sorted.isEmpty)
            pw.Text('Keine Ausgaben erfasst.')
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'Datum',
                'Kategorie',
                'Beschreibung',
                'Bezahlt von',
                'Für',
                'Betrag (EUR)',
                'Originalbetrag',
              ],
              data: sorted.map((e) {
                final payers = e.payers
                    .map((p) => name(p.personId))
                    .join(', ');
                final bens = e.beneficiaries.length == ev.participants.length
                    ? 'Alle'
                    : e.beneficiaries.map((b) => name(b.personId)).join(', ');
                final desc = e.note.isEmpty
                    ? e.description
                    : '${e.description}${e.description.isEmpty ? '' : '\n'}'
                          'Notiz: ${e.note}';
                return [
                  shortFmt.format(e.date),
                  e.category,
                  desc,
                  payers,
                  bens,
                  t(fmtEur(e.totalEur)),
                  e.currency == 'EUR' ? '' : t(fmtAmt(e.totalOriginal, e.currency)),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(48),
                1: const pw.FixedColumnWidth(80),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FixedColumnWidth(70),
                6: const pw.FixedColumnWidth(75),
              },
              cellAlignments: {
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
            ),
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              t('Summe: ${fmtEur(sorted.fold(0.0, (s, e) => s + e.totalEur))}'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }
}
