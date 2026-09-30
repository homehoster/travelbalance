# travelbalance

A new Flutter project.

# TravelBalance – Code-Dokumentation

> Reisekosten einfach aufteilen · Flutter-App · Stand: September 2026

---

## Inhaltsverzeichnis

1. [Projektstruktur](#1-projektstruktur)
2. [main.dart](#2-maindart)
3. [models/models.dart](#3-modelsmodelsdart)
4. [providers/app_provider.dart](#4-providersapp_providerdart)
5. [services/storage_service.dart](#5-servicesstorage_servicedart)
6. [services/currency_service.dart](#6-servicescurrency_servicedart)
7. [services/log.dart](#7-serviceslogdart)
8. [services/formatjson.dart](#8-servicesformatjsondart)
9. [utils/calculations.dart](#9-utilscalculationsdart)
10. [screens/home_screen.dart](#10-screenshome_screendart)
11. [screens/add_edit_event_screen.dart](#11-screensadd_edit_event_screendart)
12. [screens/add_edit_expense_screen.dart](#12-screensadd_edit_expense_screendart)
13. [screens/event_detail_screen.dart](#13-screensevent_detail_screendart)
14. [screens/settings_screen.dart](#14-screenssettings_screendart)
15. [widgets/app_drawer.dart](#15-widgetsapp_drawerdart)
16. [Datenfluss & Architektur](#16-datenfluss--architektur)
17. [pubspec.yaml – Abhängigkeiten](#17-pubspecyaml--abhängigkeiten)

---

## 1. Projektstruktur

```
lib/
├── main.dart                          # App-Einstiegspunkt, Theme, Lokalisierung
├── models/
│   └── models.dart                    # Datenmodelle (Person, Expense, TravelEvent …)
├── providers/
│   └── app_provider.dart              # State-Management (ChangeNotifier)
├── services/
│   ├── storage_service.dart           # JSON-Datei schreiben + Backup-Rotation
│   ├── currency_service.dart          # Währungskurse via Frankfurter API
│   ├── log.dart                       # Datei-Logging (Debug)
│   └── formatjson.dart                # JSON hübsch formatieren
├── utils/
│   └── calculations.dart              # Saldoberechnung, Zahlenformatierung
├── screens/
│   ├── home_screen.dart               # Startseite – Reiseliste
│   ├── add_edit_event_screen.dart     # Reise anlegen / bearbeiten
│   ├── add_edit_expense_screen.dart   # Ausgabe anlegen / bearbeiten
│   ├── event_detail_screen.dart       # Tabs: Ausgaben / Statistik / Salden
│   └── settings_screen.dart          # Einstellungen (Speicherort, Import/Export)
└── widgets/
    └── app_drawer.dart                # Seitenmenü (Drawer)
```

---

## 2. main.dart

**Zweck:** Einstiegspunkt der App. Initialisiert den Provider, die Lokalisierung und startet das Widget-Tree.

### `main()` *(async)*
```dart
Future<void> main() async
```
- Ruft `WidgetsFlutterBinding.ensureInitialized()` auf (Pflicht bei asynchronem `main`)
- Initialisiert deutsche Datumsformate via `initializeDateFormatting('de_DE')`
- Erstellt `AppProvider` und lädt gespeicherte Daten (`loadData()`)
- Startet die App mit `ChangeNotifierProvider.value`, sodass der Provider im gesamten Widget-Tree verfügbar ist

### `class TravelBalanceApp` *(StatelessWidget)*
- Definiert das `MaterialApp`-Widget mit:
  - **Lokalisierung:** `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, `GlobalCupertinoLocalizations` (Sprache: `de_DE`) → deutsches Datumsformat in allen System-Dialogen
  - **Theme:** Primärfarbe `#1565C0` (Dunkelblau), Akzentfarbe `#F59E0B` (Amber), Material 3
  - **Startseite:** `HomeScreen`

---

## 3. models/models.dart

**Zweck:** Alle Datenklassen der App. Jede Klasse implementiert `fromJson` / `toJson` für die JSON-Persistenz.

### `class Person`
Repräsentiert eine Reiseteilnehmerin / einen Reiseteilnehmer.

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `id` | `String` | UUID, automatisch generiert |
| `name` | `String` | Anzeigename |

| Methode | Beschreibung |
|---------|--------------|
| `Person.fromJson(Map)` | Deserialisierung aus JSON |
| `toJson()` | Serialisierung nach JSON |
| `==` / `hashCode` | Vergleich über `id` |

---

### `class PayerEntry`
Ein einzelner Zahler innerhalb einer Ausgabe (mehrere Zahler pro Ausgabe möglich).

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `personId` | `String` | Referenz auf `Person.id` |
| `amount` | `double` | Betrag in Originalwährung |

---

### `class BeneficiaryEntry`
Eine begünstigte Person innerhalb einer Ausgabe (Anteil in EUR).

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `personId` | `String` | Referenz auf `Person.id` |
| `amount` | `double` | Anteil in EUR |

---

### `class ManualSettlement`
Eine manuell erfasste Ausgleichsbuchung (z. B. Bargeldübergabe zwischen Personen).

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `id` | `String` | UUID |
| `fromPersonId` | `String` | Wer hat bezahlt |
| `toPersonId` | `String` | Wer hat empfangen |
| `date` | `DateTime` | Datum der Buchung |
| `amount` | `double` | Betrag in EUR |

Wird in der Saldoberechnung berücksichtigt: Zahler erhält Gutschrift, Empfänger erhält Belastung.

---

### `class Expense`
Eine einzelne Ausgabe einer Reise.

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `id` | `String` | UUID |
| `date` | `DateTime` | Datum der Ausgabe |
| `description` | `String` | Kurzbeschreibung |
| `payers` | `List<PayerEntry>` | Wer hat wie viel bezahlt |
| `currency` | `String` | Originalwährung (z. B. `USD`) |
| `exchangeRateToEur` | `double` | Kurs: 1 Einheit Währung = X EUR |
| `category` | `String` | Kategorie (z. B. `Unterkunft`) |
| `note` | `String` | Freitext-Notiz |
| `beneficiaries` | `List<BeneficiaryEntry>` | Wer profitiert (Anteil in EUR) |
| `isEqualSplit` | `bool` | `true` = gleiche Aufteilung, `false` = manuell |

| Getter | Beschreibung |
|--------|--------------|
| `totalOriginal` | Summe aller Zahlerbeträge in Originalwährung |
| `totalEur` | `totalOriginal × exchangeRateToEur` |
| `totalBeneficiariesEur` | Summe aller Begünstigten-Anteile in EUR |

---

### `class TravelEvent`
Eine vollständige Reise mit allen zugehörigen Daten.

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `id` | `String` | UUID |
| `name` | `String` | Reisename |
| `startDate` | `DateTime` | Reisebeginn |
| `endDate` | `DateTime` | Reiseende |
| `participants` | `List<Person>` | Teilnehmerliste |
| `expenses` | `List<Expense>` | Alle Ausgaben |
| `customCategories` | `List<String>` | Selbst definierte Kategorien |
| `manualSettlements` | `List<ManualSettlement>` | Ausgleichsbuchungen |

| Konstante / Getter | Beschreibung |
|-------------------|--------------|
| `defaultCategories` | `['Unterkunft', 'Essen & Trinken', 'Transport', 'Aktivitäten', 'Einkaufen', 'Maut', 'Sonstiges']` |
| `allCategories` | Standard- + eigene Kategorien (ohne Duplikate) |

---

## 4. providers/app_provider.dart

**Zweck:** Zentrales State-Management der App. Hält die Liste aller Reisen im Speicher, persistiert Änderungen und triggert UI-Rebuilds via `ChangeNotifier`.

### `class AppProvider` *(ChangeNotifier)*

#### Felder
| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `events` | `List<TravelEvent>` | Alle Reisen (im Arbeitsspeicher) |
| `exportDirectory` | `String?` | Pfad für JSON-Export |
| `loading` | `bool` | Ladezustand (für Spinner) |

#### Methoden

| Methode | Beschreibung |
|---------|--------------|
| `loadData()` | Lädt Events + Exportpfad aus `SharedPreferences`. Wird einmalig beim App-Start aufgerufen. |
| `_persist({export})` | **Privat.** Speichert alle Events in `SharedPreferences` als JSON-String. Wenn `export=true` und `exportDirectory` gesetzt, wird zusätzlich `StorageService.rotateAndSave()` aufgerufen. |
| `exportNow()` | Öffentlicher Wrapper um `_persist(export: true)`. Wird aus den Einstellungen aufgerufen. |
| `setExportDirectory(dir)` | Setzt und persistiert den Exportpfad. |
| `addEvent(event)` | Fügt eine neue Reise hinzu und persistiert. |
| `updateEvent(event)` | Ersetzt eine bestehende Reise (Suche via `id`) und persistiert. |
| `deleteEvent(eventId)` | Entfernt eine Reise und persistiert. |
| `addExpense(eventId, expense)` | Fügt einer Reise eine Ausgabe hinzu und persistiert. |
| `updateExpense(eventId, expense)` | Ersetzt eine Ausgabe (Suche via `id`) und persistiert. |
| `deleteExpense(eventId, expenseId)` | Entfernt eine Ausgabe und persistiert. |
| `addManualSettlement(eventId, ms)` | Fügt einer Reise eine Ausgleichsbuchung hinzu und persistiert. |
| `deleteManualSettlement(eventId, msId)` | Entfernt eine Ausgleichsbuchung und persistiert. |
| `addCategory(eventId, category)` | Fügt eine eigene Kategorie hinzu (kein Export). |
| `removeCategory(eventId, category)` | Entfernt eine eigene Kategorie (kein Export). |
| `importFromJson(jsonStr)` | Importiert alle Reisen aus einem JSON-String. Gibt `true` bei Erfolg zurück. |

---

## 5. services/storage_service.dart

**Zweck:** Schreibt die Export-JSON-Datei und verwaltet bis zu 5 Backup-Kopien (älteste wird automatisch gelöscht).

### Backup-Rotation
```
travelbalance_export.json      ← aktuelle Datei
travelbalance_export_1.json    ← 1. Backup (vorherige Version)
travelbalance_export_2.json    ← 2. Backup
...
travelbalance_export_5.json    ← ältestes Backup (wird überschrieben)
```

### Methoden

| Methode | Beschreibung |
|---------|--------------|
| `rotateAndSave(dir, jsonStr)` | Rotiert Backups (`_5` löschen, `_4→_5`, …, `_1→_2`), kopiert aktuelle Datei auf `_1`, schreibt neue Hauptdatei. Gibt Fehler ins Log. |
| `loadFromFile(path)` | Liest eine Datei als String. Gibt `null` zurück wenn nicht vorhanden. |
| `listBackups(dir)` | Gibt eine Liste der vorhandenen Backup-Pfade zurück (`_1` bis `_5`). |

---

## 6. services/currency_service.dart

**Zweck:** Ruft aktuelle Wechselkurse von der kostenlosen [Frankfurter API](https://api.frankfurter.app) ab und cacht sie für die App-Session.

### `class CurrencyService`

| Konstante | Beschreibung |
|-----------|--------------|
| `supportedCurrencies` | 28 Währungen: EUR, USD, GBP, CHF, JPY, CAD, AUD, SEK, NOK, DKK, CZK, PLN, HUF, TRY, RON, BGN, HRK, ISK, MXN, BRL, CNY, KRW, SGD, HKD, THB, INR, IDR, ZAR |

| Methode | Beschreibung |
|---------|--------------|
| `getRateToEur(currency)` | Gibt zurück, wie viele EUR 1 Einheit der Währung wert ist. `EUR → 1.0`. Cache-first (Session). API-Timeout: 10 Sekunden. Bei Fehler: letzter gecachter Wert oder `1.0`. |
| `clearCache()` | Leert den Session-Cache (alle gespeicherten Kurse). |

**API-Endpunkt:**
```
GET https://api.frankfurter.app/latest?from={CURRENCY}&to=EUR
```

---

## 7. services/log.dart

**Zweck:** Debug-Logging in Dateien unter `/storage/emulated/0/Download/TravelBalance/Log/`.

### `class LogService`

| Methode | Parameter | Beschreibung |
|---------|-----------|--------------|
| `log(message)` | `fileName`, `isJsonLog` | Schreibt eine Zeile mit Timestamp ins Log (`FileMode.append`). Bei `isJsonLog=true`: überschreibt die Datei komplett mit formatiertem JSON. Erstellt den Ordner automatisch. |

---

## 8. services/formatjson.dart

**Zweck:** Hilfsfunktion für lesbare JSON-Ausgabe (Einrückung 2 Leerzeichen).

### `formatJson(jsonStr)` → `String`
- Parst den JSON-String und gibt ihn mit `JsonEncoder.withIndent('  ')` formatiert zurück
- Bei ungültigem JSON: Originalstring wird unverändert zurückgegeben

---

## 9. utils/calculations.dart

**Zweck:** Saldoberechnung, Ausgleichszahlungen und deutsche Zahlenformatierung.

### Zahlenformatierung

| Funktion | Beispiel | Beschreibung |
|----------|----------|--------------|
| `fmtEur(double)` | `1.234,56 €` | Formatiert einen EUR-Betrag im deutschen Format |
| `fmtAmt(double, currency)` | `1.234,56 USD` | Formatiert einen Betrag mit beliebiger Währung; bei EUR wird `fmtEur` verwendet |

Verwendet `NumberFormat('#,##0.00', 'de_DE')` aus dem `intl`-Package.

---

### `class PersonBalance`
Zwischenergebnis der Saldoberechnung für eine Person.

| Feld | Beschreibung |
|------|--------------|
| `personId` | ID der Person |
| `personName` | Name der Person |
| `paid` | Summe aller tatsächlich geleisteten Zahlungen (in EUR) |
| `owed` | Summe aller konsumierten Anteile (in EUR) |
| `net` | `paid − owed`: positiv = Gläubiger, negativ = Schuldner |

---

### `class Settlement`
Eine empfohlene Ausgleichszahlung zwischen zwei Personen.

| Feld | Beschreibung |
|------|--------------|
| `fromPersonId/Name` | Schuldner (zahlt) |
| `toPersonId/Name` | Gläubiger (empfängt) |
| `amount` | Betrag in EUR (gerundet auf 2 Dezimalstellen) |

---

### `calculateBalances(event, {from, to})` → `List<PersonBalance>`
Berechnet den Saldo jeder Person für eine Reise, optional gefiltert nach Zeitraum.

**Logik:**
1. Alle Teilnehmer mit `paid=0, owed=0` initialisieren
2. Für jede Ausgabe im Zeitraum:
   - Zahler: `paid += payer.amount × exchangeRateToEur`
   - Begünstigte: `owed += beneficiary.amount`
3. Für jede manuelle Ausgleichsbuchung im Zeitraum:
   - `fromPerson.paid += ms.amount` (Zahler verbessert seinen Saldo)
   - `toPerson.owed += ms.amount` (Empfänger verringert sein Guthaben)

---

### `calculateSettlements(balances)` → `List<Settlement>`
Greedy-Algorithmus: minimiert die Anzahl der Überweisungen.

**Logik:**
1. Gläubiger (net > 0) und Schuldner (net < 0) getrennt sortieren (absteigend nach Betrag)
2. Größter Schuldner zahlt größten Gläubiger
3. Differenz auf die verbleibenden Salden anwenden
4. Wiederholen bis alle ausgeglichen (Schwelle: 0,005 €)

---

## 10. screens/home_screen.dart

**Zweck:** Startseite der App. Zeigt alle Reisen als Liste, ermöglicht Navigation und Löschung.

### `class HomeScreen` *(StatelessWidget)*
- Liest `AppProvider` via `context.watch`
- Zeigt `CircularProgressIndicator` während `prov.loading`
- Leerer Zustand: `_EmptyState` mit Hinweis und Button
- Gefüllter Zustand: `ListView` mit `_EventCard` pro Reise
- **FAB + AppBar-Icon:** Navigation zu `AddEditEventScreen`
- **Drawer:** `AppDrawer`

### `_confirmDelete(ctx, prov, ev)`
Zeigt einen Bestätigungs-Dialog und ruft `prov.deleteEvent()` auf.

### `class _EventCard`
Karte für eine Reise in der Liste.

| Anzeige | Beschreibung |
|---------|--------------|
| Name | Fett, groß |
| Zeitraum | `dd.MM.yyyy – dd.MM.yyyy` |
| Chips | Anzahl Personen, Anzahl Ausgaben |
| Gesamtbetrag | Summe aller `expense.totalEur`, formatiert |
| Popup-Menü | Bearbeiten → `AddEditEventScreen`; Löschen → `_confirmDelete` |

---

## 11. screens/add_edit_event_screen.dart

**Zweck:** Formular zum Anlegen und Bearbeiten einer Reise.

### `class AddEditEventScreen` *(StatefulWidget)*
**Parameter:** `eventId` (optional) – wenn gesetzt: Bearbeitungsmodus

### State: `_AddEditEventScreenState`

| Methode | Beschreibung |
|---------|--------------|
| `initState()` | Befüllt Felder wenn `eventId` vorhanden (via `addPostFrameCallback`) |
| `_pickStartDate()` | Öffnet deutschen DatePicker; passt `_endDate` an wenn nötig |
| `_pickEndDate()` | Öffnet deutschen DatePicker (Minimum: `_startDate`) |
| `_addParticipant()` | Dialog mit Textfeld; erstellt neue `Person` und fügt sie zur Liste hinzu |
| `_addCategory()` | Dialog mit Textfeld; fügt eigene Kategorie hinzu (keine Duplikate, keine Standard-Kategorien) |
| `_save()` | Validiert Formular + Pflicht-Personen; ruft `prov.addEvent()` oder `prov.updateEvent()` auf |

**Angezeigt werden:**
- Reisename (Pflichtfeld)
- Zeitraum Von/Bis (DatePicker)
- Personen-Liste mit Hinzufügen / Entfernen
- Eigene Kategorien mit Chips (Standard-Kategorien werden als Info angezeigt)

---

## 12. screens/add_edit_expense_screen.dart

**Zweck:** Formular zum Anlegen und Bearbeiten einer Ausgabe. Komplexester Screen der App.

### `class AddEditExpenseScreen` *(StatefulWidget)*
**Parameter:** `eventId` (Pflicht), `expenseId` (optional, Bearbeitungsmodus)

### State: `_AddEditExpenseScreenState`

#### Hilfsmethoden

| Methode | Beschreibung |
|---------|--------------|
| `_init()` | Lädt Teilnehmer + Kategorien aus dem Event; bei Bearbeitungsmodus werden alle Felder befüllt |
| `_toInput(double)` | Konvertiert `1234.56` → `"1234,56"` (Komma als Dezimaltrennzeichen) |
| `_parseInput(String)` | Konvertiert `"1234,56"` → `1234.56` |
| `_fetchRate()` | Ruft Wechselkurs von `CurrencyService` ab und befüllt `_rateCtrl` |
| `_buildPayers()` | Erstellt `List<PayerEntry>` aus aktivierten Checkbox-Feldern |
| `_buildBeneficiaries()` | Bei Gleichteilung: teilt `totalPayersEur` durch Anzahl aktivierter Personen. Bei manuell: liest Einzelbeträge aus Feldern |
| `_save()` | Validiert alle Eingaben; ruft `prov.addExpense()` oder `prov.updateExpense()` auf |

#### Getter

| Getter | Beschreibung |
|--------|--------------|
| `_rate` | Aktueller Wechselkurs aus `_rateCtrl` |
| `_totalPayersEur` | Summe aller Zahler-Beträge in EUR |
| `_totalPayersOriginal` | Summe aller Zahler-Beträge in Originalwährung |
| `_totalBenEur` | Bei Gleichteilung = `_totalPayersEur`; bei manuell = Summe der Einzelfelder |
| `_benDiff` | `_totalPayersEur − _totalBenEur` (Differenzanzeige) |

#### Hilfs-Widgets

| Widget | Beschreibung |
|--------|--------------|
| `_SectionCard` | Container mit farbigem Header-Icon und Trennlinie |
| `_PayerRow` | Checkbox + Namenstext + Betragsfeld (Originalwährung) + EUR-Umrechnung |
| `_SplitToggle` | Toggle-Buttons „Gleich aufteilen" / „Manuell" |
| `_BeneficiaryEqualRow` | Checkbox + Name + berechneter Anteil (Original + EUR) |
| `_BeneficiaryManualRow` | Checkbox + Name + Eingabefeld in **Originalwährung** |
| `_DiffRow` | Zeigt Gesamt / Aufgeteilt / Differenz mit Farbcodierung (grün OK, orange/rot Fehler) |

---

## 13. screens/event_detail_screen.dart

**Zweck:** Detailansicht einer Reise mit drei Tabs.

### `class EventDetailScreen` *(StatefulWidget)*
**Parameter:** `eventId`

Verwaltet einen `TabController` mit 3 Tabs: Ausgaben, Statistik, Salden.
FAB wird nur im Ausgaben-Tab angezeigt.

---

### Tab 1: `_ExpensesTab`
Liste aller Ausgaben, absteigend nach Datum sortiert.

**`_ExpenseCard`:** Zeigt Kategorie-Badge, Datum, EUR-Betrag (+ Original wenn Fremdwährung), Beschreibung, Zahler-Namen, Notiz. Popup-Menü mit „Löschen"-Option (nach Bestätigung).

**`_CategoryBadge`:** Farbiger Chip je Kategorie (Farben fix für Standardkategorien, Teal für Custom).

---

### Tab 2: `_StatisticsTab` *(StatefulWidget)*

#### `_initRange()`
Setzt `_fromDate` / `_toDate` auf das Datum der **ersten / letzten vorhandenen Ausgabe** (nicht Reisezeitraum). Fallback: Reisezeitraum wenn keine Ausgaben vorhanden.

#### Berechnungen im `build()`

| Berechnung | Beschreibung |
|------------|--------------|
| Gefilterte Ausgaben | Alle `expenses` im Zeitraum `[_fromDate, _toDate]` |
| `personOwed` | Summe der Begünstigten-Anteile je Person (was wurde konsumiert) |
| `personPaid` | Summe der tatsächlichen Zahlungen je Person in EUR (wer hat gezahlt) |
| `catTotals` | Summe je Kategorie, absteigend sortiert |

#### Angezeigte Abschnitte
1. **Zeitraumfilter** – Von/Bis DatePicker + Reset-Button
2. **Gesamtausgaben** – Summe + Anzahl Ausgaben
3. **Bezahlt je Person** – wer hat tatsächlich Geld ausgegeben (Balkengrafik)
4. **Ausgaben je Person (Anteil)** – wer hat wie viel konsumiert (Balkengrafik)
5. **Ausgaben nach Kategorie** – Balkengrafik absteigend

**`_StatRow`:** Einheitliches Widget für Balkenzeilen: Name + `LinearProgressIndicator` + formatierter Betrag.

---

### Tab 3: `_BalancesTab` *(StatefulWidget)*

#### `_showSettlementDialog()`
Öffnet Dialog zur Erfassung einer Ausgleichsbuchung:
- Datumswähler (deutsch)
- Dropdown „Von" (Zahler)
- Dropdown „An" (Empfänger)
- Betragsfeld in EUR
- Validierung: Betrag > 0, Von ≠ An
- Ruft `prov.addManualSettlement()` auf

#### `build()` – Angezeigte Abschnitte
1. **Kontostand je Person** (`_BalanceCard`) – zeigt `paid`, `owed`, `net` in Grün/Rot
2. **Empfohlene Ausgleichszahlungen** (`_SettlementCard`) – aus `calculateSettlements()`; grüner Haken wenn alles ausgeglichen
3. **Ausgleichsbuchungen** – Liste der manuell erfassten Buchungen mit Datum, Von/An, Betrag, Löschen-Button

**`_BalanceCard`:** Zeigt Initialen-Avatar (grün = Gläubiger, rot = Schuldner), Name, paid/owed, net-Betrag.

**`_SettlementCard`:** Orange Karte: „Person A zahlt Person B – Betrag".

---

## 14. screens/settings_screen.dart

**Zweck:** Einstellungen für Speicherort, Export und Import.

### `class SettingsScreen` *(StatelessWidget)*

#### Abschnitt 1: Speicherort
- Zeigt aktuellen `prov.exportDirectory`-Pfad
- Button „Speicherort wählen": öffnet `FilePicker.platform.getDirectoryPath()`; speichert via `prov.setExportDirectory()`

#### Abschnitt 2: Export & Import

| Aktion | Beschreibung |
|--------|--------------|
| „Jetzt exportieren" | Ruft `prov.exportNow()` auf; zeigt Erfolgsmeldung oder Fehler |
| „JSON importieren" | Öffnet `FilePicker.platform.pickFiles()` (`.json`); liest Datei; ruft `prov.importFromJson()` auf |

#### Abschnitt 3: Info
- App-Name und Version

---

## 15. widgets/app_drawer.dart

**Zweck:** Seitenmenü mit Reiseliste und Einstellungen-Link am unteren Rand.

### `class AppDrawer` *(StatelessWidget)*
Verwendet `context.watch<AppProvider>()` um die aktuelle Reiseliste anzuzeigen.

#### Aufbau

```
DrawerHeader
│  Icon + "TravelBalance" + "Reisekosten teilen"
│
Expanded (scrollbar)
│  "Meine Reisen" [+ Neue Reise Button]
│  ─────────────────────────────────────
│  • Reise 1  (Avatar, Name, Statistik)
│  • Reise 2
│  ...
│
─────────────────────────────────────────
Einstellungen (ListTile)
Version-Info
```

#### Navigation bei Reise-Tap
```dart
Navigator.pop(context);                              // Drawer schließen
Navigator.of(context).popUntil((r) => r.isFirst);   // Zurück zu HomeScreen
Navigator.push(context, EventDetailScreen(...));     // Event öffnen
```

---

## 16. Datenfluss & Architektur

```
┌─────────────────────────────────────────────────────┐
│                   UI (Screens/Widgets)              │
│  HomeScreen  │  EventDetailScreen  │  AddEdit...   │
└──────┬───────┴──────────┬──────────┴───────┬────────┘
       │ context.watch    │                  │ context.read
       ▼                  ▼                  ▼
┌──────────────────────────────────────────────────────┐
│                    AppProvider                       │
│  List<TravelEvent> events                           │
│  addEvent / updateEvent / deleteEvent               │
│  addExpense / updateExpense / deleteExpense         │
│  addManualSettlement / deleteManualSettlement       │
└──────────┬──────────────────────────────────────────┘
           │ _persist()
    ┌──────┴──────────────────────┐
    │                             │
    ▼                             ▼
SharedPreferences          StorageService
(schnell, intern)          (JSON-Datei + 5 Backups)
```

### Währungsfluss
```
Nutzer wählt Währung
       │
       ▼
CurrencyService.getRateToEur()
       │  GET api.frankfurter.app
       ▼
exchangeRateToEur gespeichert in Expense
       │
       ▼
calculations.dart: amount × exchangeRateToEur = EUR-Betrag
```

### Saldoberechnung
```
calculateBalances(event)
  ├── Für jede Expense:   payer.paid += amount×rate
  │                        ben.owed  += ben.amount
  └── Für jede ManualSettlement:
                           from.paid += ms.amount
                           to.owed   += ms.amount

calculateSettlements(balances)
  └── Greedy-Algorithmus minimiert Überweisungsanzahl
```

---

## 17. pubspec.yaml – Abhängigkeiten

| Package | Version | Verwendung |
|---------|---------|------------|
| `provider` | ^6.1.2 | State-Management (`ChangeNotifier`) |
| `uuid` | ^4.4.2 | UUID-Generierung für alle Modell-IDs |
| `intl` | ^0.19.0 | Datumsformatierung, Zahlenformatierung (`de_DE`) |
| `shared_preferences` | ^2.3.2 | Persistenz des JSON-Strings und des Exportpfads |
| `http` | ^1.2.2 | HTTP-Anfragen an Frankfurter API |
| `file_picker` | ^8.1.2 | Ordner- und Dateiauswahl |
| `path_provider` | ^2.1.4 | App-Dokumentenordner ermitteln |
| `path` | ^1.9.1 | Plattformübergreifende Pfad-Manipulation |
| `permission_handler` | ^11.3.1 | Android-Speicherberechtigung anfordern |
| `flutter_localizations` | sdk: flutter | Deutsches Datumspicker-Layout |

---

*Dokumentation automatisch erstellt · TravelBalance v1.0*
