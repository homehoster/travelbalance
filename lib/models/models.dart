library travelbalance;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Person {
  final String id;
  String name;
  Person({String? id, required this.name}) : id = id ?? _uuid.v4();
  factory Person.fromJson(Map<String, dynamic> j) =>
      Person(id: j['id'] as String, name: j['name'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  @override
  bool operator ==(Object o) => o is Person && o.id == id;
  @override
  int get hashCode => id.hashCode;
  @override
  String toString() => name;
}

class PayerEntry {
  String personId;
  double amount;
  PayerEntry({required this.personId, required this.amount});
  factory PayerEntry.fromJson(Map<String, dynamic> j) => PayerEntry(
    personId: j['personId'] as String,
    amount: (j['amount'] as num).toDouble(),
  );
  Map<String, dynamic> toJson() => {'personId': personId, 'amount': amount};
}

class BeneficiaryEntry {
  String personId;
  double amount;
  BeneficiaryEntry({required this.personId, required this.amount});
  factory BeneficiaryEntry.fromJson(Map<String, dynamic> j) => BeneficiaryEntry(
    personId: j['personId'] as String,
    amount: (j['amount'] as num).toDouble(),
  );
  Map<String, dynamic> toJson() => {'personId': personId, 'amount': amount};
}

class ManualSettlement {
  final String id;
  String fromPersonId;
  String toPersonId;
  DateTime date;
  double amount;

  ManualSettlement({
    String? id,
    required this.fromPersonId,
    required this.toPersonId,
    required this.date,
    required this.amount,
  }) : id = id ?? _uuid.v4();

  factory ManualSettlement.fromJson(Map<String, dynamic> j) => ManualSettlement(
    id: j['id'] as String,
    fromPersonId: j['fromPersonId'] as String,
    toPersonId: j['toPersonId'] as String,
    date: DateTime.parse(j['date'] as String),
    amount: (j['amount'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromPersonId': fromPersonId,
    'toPersonId': toPersonId,
    'date': date.toIso8601String(),
    'amount': amount,
  };
}

class Expense {
  final String id;
  DateTime date;
  String description;
  List<PayerEntry> payers;
  String currency;
  double exchangeRateToEur;
  String category;
  String note;
  List<BeneficiaryEntry> beneficiaries;
  bool isEqualSplit;

  Expense({
    String? id,
    required this.date,
    required this.description,
    required this.payers,
    required this.currency,
    required this.exchangeRateToEur,
    required this.category,
    required this.note,
    required this.beneficiaries,
    required this.isEqualSplit,
  }) : id = id ?? _uuid.v4();

  double get totalOriginal => payers.fold(0.0, (s, p) => s + p.amount);
  double get totalEur => totalOriginal * exchangeRateToEur;
  double get totalBeneficiariesEur =>
      beneficiaries.fold(0.0, (s, b) => s + b.amount);

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'] as String,
    date: DateTime.parse(j['date'] as String),
    description: j['description'] as String? ?? '',
    payers: (j['payers'] as List)
        .map((e) => PayerEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    currency: j['currency'] as String,
    exchangeRateToEur: (j['exchangeRateToEur'] as num).toDouble(),
    category: j['category'] as String,
    note: j['note'] as String? ?? '',
    beneficiaries: (j['beneficiaries'] as List)
        .map((e) => BeneficiaryEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    isEqualSplit: j['isEqualSplit'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'description': description,
    'payers': payers.map((e) => e.toJson()).toList(),
    'currency': currency,
    'exchangeRateToEur': exchangeRateToEur,
    'category': category,
    'note': note,
    'beneficiaries': beneficiaries.map((e) => e.toJson()).toList(),
    'isEqualSplit': isEqualSplit,
  };
}

class TravelEvent {
  final String id;
  String name;
  DateTime startDate;
  DateTime endDate;
  List<Person> participants;
  List<Expense> expenses;
  List<String> customCategories;
  List<ManualSettlement> manualSettlements;

  TravelEvent({
    String? id,
    required this.name,
    required this.startDate,
    required this.endDate,
    List<Person>? participants,
    List<Expense>? expenses,
    List<String>? customCategories,
    List<ManualSettlement>? manualSettlements,
  }) : id = id ?? _uuid.v4(),
       participants = participants ?? [],
       expenses = expenses ?? [],
       customCategories = customCategories ?? [],
       manualSettlements = manualSettlements ?? [];

  static const List<String> defaultCategories = [
    'Unterkunft',
    'Essen & Trinken',
    'Transport',
    'Aktivitäten',
    'Einkaufen',
    'Maut',
    'Sonstiges',
  ];

  List<String> get allCategories => [
    ...defaultCategories,
    ...customCategories.where((c) => !defaultCategories.contains(c)),
  ];

  factory TravelEvent.fromJson(Map<String, dynamic> j) => TravelEvent(
    id: j['id'] as String,
    name: j['name'] as String,
    startDate: DateTime.parse(j['startDate'] as String),
    endDate: DateTime.parse(j['endDate'] as String),
    participants: (j['participants'] as List)
        .map((e) => Person.fromJson(e as Map<String, dynamic>))
        .toList(),
    expenses: (j['expenses'] as List)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList(),
    customCategories:
        (j['customCategories'] as List?)?.map((e) => e as String).toList() ??
        [],
    manualSettlements:
        (j['manualSettlements'] as List?)
            ?.map((e) => ManualSettlement.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'participants': participants.map((e) => e.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'customCategories': customCategories,
    'manualSettlements': manualSettlements.map((e) => e.toJson()).toList(),
  };
}
