import 'dart:math';

import 'package:intl/intl.dart';

import '../models/models.dart';

// ── Zahlenformatierung (deutsch: 1.234,56 €) ───────────────────────────────
final _numFmt = NumberFormat('#,##0.00', 'de_DE');
String fmtEur(double v) => '${_numFmt.format(v)} €';
String fmtAmt(double v, String currency) =>
    currency == 'EUR' ? fmtEur(v) : '${_numFmt.format(v)} $currency';

// ── Saldoberechnung ─────────────────────────────────────────────────────────
class PersonBalance {
  final String personId;
  final String personName;
  double paid;
  double owed;

  PersonBalance({
    required this.personId,
    required this.personName,
    this.paid = 0.0,
    this.owed = 0.0,
  });

  double get net => paid - owed;
}

class Settlement {
  final String fromPersonId;
  final String fromPersonName;
  final String toPersonId;
  final String toPersonName;
  final double amount;

  Settlement({
    required this.fromPersonId,
    required this.fromPersonName,
    required this.toPersonId,
    required this.toPersonName,
    required this.amount,
  });
}

List<PersonBalance> calculateBalances(
  TravelEvent event, {
  DateTime? from,
  DateTime? to,
}) {
  final map = <String, PersonBalance>{};
  for (final p in event.participants) {
    map[p.id] = PersonBalance(personId: p.id, personName: p.name);
  }

  for (final e in event.expenses) {
    if (from != null && e.date.isBefore(from)) continue;
    if (to != null && e.date.isAfter(to)) continue;

    for (final payer in e.payers) {
      final amountEur = payer.amount * e.exchangeRateToEur;
      map[payer.personId]?.let((b) => b.paid += amountEur);
    }
    for (final ben in e.beneficiaries) {
      map[ben.personId]?.let((b) => b.owed += ben.amount);
    }
  }

  // Manuelle Ausgleichsbuchungen berücksichtigen
  for (final ms in event.manualSettlements) {
    if (from != null && ms.date.isBefore(from)) continue;
    if (to != null && ms.date.isAfter(to)) continue;
    // fromPerson hat bezahlt → paid steigt → net verbessert sich
    map[ms.fromPersonId]?.let((b) => b.paid += ms.amount);
    // toPerson hat Geld erhalten → owed steigt → net sinkt
    map[ms.toPersonId]?.let((b) => b.owed += ms.amount);
  }

  return map.values.toList();
}

List<Settlement> calculateSettlements(List<PersonBalance> balances) {
  final creditors =
      balances
          .where((b) => b.net > 0.005)
          .map((b) => _MutableBalance(b.personId, b.personName, b.net))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
  final debtors =
      balances
          .where((b) => b.net < -0.005)
          .map((b) => _MutableBalance(b.personId, b.personName, b.net.abs()))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  final settlements = <Settlement>[];
  int ci = 0, di = 0;
  while (ci < creditors.length && di < debtors.length) {
    final cr = creditors[ci];
    final de = debtors[di];
    final amount = min(cr.amount, de.amount);
    if (amount > 0.005) {
      settlements.add(
        Settlement(
          fromPersonId: de.personId,
          fromPersonName: de.personName,
          toPersonId: cr.personId,
          toPersonName: cr.personName,
          amount: double.parse(amount.toStringAsFixed(2)),
        ),
      );
    }
    cr.amount -= amount;
    de.amount -= amount;
    if (cr.amount < 0.005) ci++;
    if (de.amount < 0.005) di++;
  }
  return settlements;
}

class _MutableBalance {
  final String personId;
  final String personName;
  double amount;
  _MutableBalance(this.personId, this.personName, this.amount);
}

extension _Let<T> on T {
  void let(void Function(T) block) => block(this);
}
