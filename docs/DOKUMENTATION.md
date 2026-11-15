# TravelBalance – Code-Dokumentation

> Reisekosten einfach aufteilen · Flutter-App · Stand: November 2026

[← Zurück zur Startseite (README)](../README.md)

---

## Inhaltsverzeichnis

1. [Projektstruktur](#1-projektstruktur)
2. [main.dart](#2-maindart)
3. [models/models.dart](#3-modelsmodelsdart)
4. [providers/app_provider.dart](#4-providersapp_providerdart)
5. [services/storage_service.dart](#5-servicesstorage_servicedart)
6. [services/currency_service.dart](#6-servicescurrency_servicedart)
7. [services/pdf_export_service.dart](#7-servicespdf_export_servicedart)
8. [services/log.dart](#8-serviceslogdart)
9. [services/formatjson.dart](#9-servicesformatjsondart)
10. [utils/calculations.dart](#10-utilscalculationsdart)
11. [utils/messenger.dart](#11-utilsmessengerdart)
12. [screens/home_screen.dart](#12-screenshome_screendart)
13. [screens/add_edit_event_screen.dart](#13-screensadd_edit_event_screendart)
14. [screens/add_edit_expense_screen.dart](#14-screensadd_edit_expense_screendart)
15. [screens/event_detail_screen.dart](#15-screensevent_detail_screendart)
16. [screens/settings_screen.dart](#16-screenssettings_screendart)
17. [widgets/app_drawer.dart](#17-widgetsapp_drawerdart)
18. [widgets/event_menu_button.dart](#18-widgetsevent_menu_buttondart)
19. [Datenfluss & Architektur](#19-datenfluss--architektur)
20. [Dateiformat des JSON-Exports](#20-dateiformat-des-json-exports)
21. [pubspec.yaml – Abhängigkeiten](#21-pubspecyaml--abhängigkeiten)
22. [Android-Build-Konfiguration](#22-android-build-konfiguration)

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
│   ├── storage_service.dart           # JSON-Export in SAF-Ordner + Backup-Rotation
│   ├── currency_service.dart          # Währungskurse via Frankfurter API
│   ├── pdf_export_service.dart        # PDF-Bericht (Salden, Statistik, Ausgaben)
│   ├── log.dart                       # Datei-Logging mit Rotation
│   └── formatjson.dart                # JSON hübsch formatieren
├── utils/
│   ├── calculations.dart              # Saldoberechnung, Zahlenformatierung
│   └── messenger.dart                 # Globaler ScaffoldMessenger-Key
├── screens/
│   ├── home_screen.dart               # Startseite – Reiseliste
│   ├── add_edit_event_screen.dart     # Reise anlegen / bearbeiten
│   ├── add_edit_expense_screen.dart   # Ausgabe anlegen / bearbeiten
│   ├── event_detail_screen.dart       # Tabs: Ausgaben / Statistik / Salden
│   └── settings_screen.dart           # Einstellungen (Ordner, Import/Export, Log)
└── widgets/
    ├── app_drawer.dart                # Seitenmenü (Drawer)
    └── event_menu_button.dart         # 3-Punkte-Menü einer Reise
```

---

## 2. main.dart

**Zweck:** Einstiegspunkt der App. Initialisiert Provider und Lokalisierung und startet den Widget-Tree.

### `main()` *(async)*
- Ruft `WidgetsFlutterBinding.ensureInitialized()` auf (Pflicht bei asynchronem `main`)
- Initialisiert deutsche Datumsformate via `initializeDateFormatting('de_DE')`
- Erstellt `AppProvider` und lädt gespeicherte Daten (`loadData()`)
- Startet die App mit `ChangeNotifierProvider.value`, sodass der Provider im gesamten Widget-Tree verfügbar ist

### `class TravelBalanceApp` *(StatelessWidget)*
Definiert das `MaterialApp`:

| Einstellung | Wert |
|-------------|------|
| Lokalisierung | `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, `GlobalCupertinoLocalizations`; `locale: de_DE`, unterstützt `de_DE` und `en_US` |
| Theme | Material 3, Seed-Farbe `#1565C0` (Blau), Sekundärfarbe `#F59E0B` (Amber); AppBar und FAB in Blau; Karten mit 12 px Radius |
| `scaffoldMessengerKey` | `messengerKey` (siehe [utils/messenger.dart](#11-utilsmessengerdart)) |
| Startseite | `HomeScreen` |

---

## 3. models/models.dart

**Zweck:** Alle Datenklassen der App. Jede Klasse implementiert `fromJson` / `toJson` für die JSON-Persistenz. IDs sind UUIDs (Paket `uuid`).

### `class Person`
Reiseteilnehmer.

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `id` | `String` | UUID, automatisch generiert |
| `name` | `String` | Anzeigename (veränderbar, die `id` bleibt beim Umbenennen gleich) |

`==` und `hashCode` vergleichen über die `id`.

---

### `class PayerEntry`
Ein einzelner Zahler innerhalb einer Ausgabe (mehrere Zahler pro Ausgabe möglich).

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `personId` | `String` | Referenz auf `Person.id` |
| `amount` | `double` | Betrag in **Originalwährung** |

---

### `class BeneficiaryEntry`
Eine begünstigte Person innerhalb einer Ausgabe.

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `personId` | `String` | Referenz auf `Person.id` |
| `amount` | `double` | Anteil in **EUR** |

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

---

### `class Expense`
Eine einzelne Ausgabe einer Reise.

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `id` | `String` | UUID |
| `date` | `DateTime` | Datum der Ausgabe |
| `description` | `String` | Kurzbeschreibung (optional) |
| `payers` | `List<PayerEntry>` | Wer hat wie viel bezahlt |
| `currency` | `String` | Originalwährung (z. B. `USD`) |
| `exchangeRateToEur` | `double` | Kurs: 1 Einheit Währung = X EUR |
| `category` | `String` | Kategoriename (z. B. `Unterkunft`) |
| `note` | `String` | Freitext-Notiz |
| `beneficiaries` | `List<BeneficiaryEntry>` | Wer profitiert (Anteil in EUR) |
| `isEqualSplit` | `bool` | `true` = gleichmäßig, `false` = manuell |

| Getter | Beschreibung |
|--------|--------------|
| `totalOriginal` | Summe aller Zahlerbeträge in Originalwährung |
| `totalEur` | `totalOriginal × exchangeRateToEur` |
| `totalBeneficiariesEur` | Summe aller Begünstigten-Anteile in EUR |

> Kategorien werden als **Text** gespeichert (nicht als ID). Beim Umbenennen oder Löschen einer eigenen Kategorie werden deshalb die betroffenen Ausgaben im `AddEditEventScreen` angepasst (siehe Abschnitt 13).

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
| `customCategories` | `List<String>` | Selbst definierte Kategorien dieser Reise |
| `manualSettlements` | `List<ManualSettlement>` | Ausgleichsbuchungen |

| Konstante / Getter | Beschreibung |
|--------------------|--------------|
| `defaultCategories` | `Unterkunft`, `Essen & Trinken`, `Transport`, `Aktivitäten`, `Einkaufen`, `Maut`, `Sonstiges` |
| `allCategories` | Standard- + eigene Kategorien (ohne Duplikate) |

---

## 4. providers/app_provider.dart

**Zweck:** Zentrales State-Management. Hält alle Reisen im Speicher, persistiert Änderungen und löst UI-Rebuilds über `ChangeNotifier` aus. Zusätzlich `WidgetsBindingObserver`: Beim Zurückkehren in die App (`resumed`) wird der Sicherungsordner geprüft.

### `enum EventSortMode`
`dateAsc`, `dateDesc`, `nameAsc`, `nameDesc` – Sortierung der Reiseliste.

### `class AppProvider` *(ChangeNotifier)*

#### Felder

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `events` | `List<TravelEvent>` | Alle Reisen (im Arbeitsspeicher) |
| `exportDirectory` | `String?` | `content://`-URI des Sicherungsordners (SAF) |
| `exportError` | `String?` | Letzte Fehlermeldung beim Export (für Banner) |
| `folderProblem` | `bool` | `true`, wenn der Fehler am Ordner liegt (gelöscht, Zugriff verloren) |
| `needsFolder` | `bool` *(Getter)* | `true`, solange kein Ordner gewählt ist |
| `loading` | `bool` *(Getter)* | Ladezustand (für Spinner) |
| `sortMode` | `EventSortMode` | Aktuelle Sortierung, Standard `dateDesc` |

#### Methoden

| Methode | Beschreibung |
|---------|--------------|
| `loadData()` | Lädt Events, Exportordner und Sortierung aus `SharedPreferences`. Verwirft alte Dateipfade (vor dem SAF-Umbau), die nicht mit `content://` beginnen. Prüft danach den Ordner. |
| `checkExportFolder()` | Ruft `StorageService.ensureFolder()` auf und setzt bzw. löscht `folderProblem` / `exportError`. |
| `_persist({export})` | **Privat.** Speichert alle Events als JSON-String in `SharedPreferences`. Bei `export=true` und gesetztem Ordner zusätzlich `StorageService.rotateAndSave()`. Bei Fehlern wird ein roter SnackBar über `messengerKey` angezeigt (bei Ordnerproblemen mit Button „Ordner wählen"). |
| `exportNow()` | Erzwingt einen Export; wirft eine `Exception`, wenn kein Ordner gewählt ist oder der Export fehlschlägt. |
| `setExportDirectory(dir)` | Setzt und persistiert den Ordner, setzt Fehlerstatus zurück. |
| `chooseExportFolder()` | Öffnet den Android-Ordnerdialog, speichert die Wahl und exportiert sofort. Gibt `true` bei Erfolg zurück. |
| `addEvent` / `updateEvent` / `deleteEvent` | Reisen verwalten und persistieren (mit Export). |
| `addExpense` / `updateExpense` / `deleteExpense` | Ausgaben einer Reise verwalten (mit Export). |
| `addManualSettlement` / `deleteManualSettlement` | Ausgleichsbuchungen verwalten (mit Export). |
| `addCategory` / `removeCategory` | Eigene Kategorie hinzufügen/entfernen (**ohne** Export). |
| `importFromJson(jsonStr)` | Ersetzt **alle** Reisen durch den Inhalt des JSON-Strings (erwartet eine Liste von Reisen). Gibt `true` bei Erfolg zurück; speichert **ohne** Export. |
| `setSortMode(mode)` | Speichert die Sortierung in `SharedPreferences`. |
| `sortedEvents` | *(Getter)* Sortierte Kopie von `events` gemäß `sortMode`. |

---

## 5. services/storage_service.dart

**Zweck:** Schreibt die Export-JSON-Datei in einen frei wählbaren Ordner und verwaltet bis zu 5 Backup-Kopien. Verwendet das Android **Storage Access Framework (SAF)** über die Pakete `saf_util` und `saf_stream` – dadurch ist keine Speicherberechtigung im Manifest nötig.

### `class StorageFolderException`
Wird geworfen, wenn der Ordner ungültig, gelöscht oder nicht mehr zugreifbar ist. `message` kann direkt dem Nutzer angezeigt werden.

### Dateinamen und Backup-Rotation

```
travelbalance_export.json              ← aktuelle Hauptdatei (wird überschrieben)
travelbalance_export_2026_10_06.json   ← Backup vom Tag (vorheriger Stand)
travelbalance_export_2026_10_06_1.json ← weiteres Backup am selben Tag
...                                     ← insgesamt maximal 5 Backups
```

### Methoden

| Methode | Beschreibung |
|---------|--------------|
| `pickFolder()` | Öffnet den Android-Ordnerdialog mit dauerhaftem Schreibrecht, gibt die `content://`-URI zurück (oder `null` bei Abbruch). |
| `displayPath(uri)` | Lesbare Darstellung der URI, z. B. `primary:Download/TravelBalance`. |
| `ensureFolder(uri)` | Prüft URI-Format, dauerhafte Berechtigung und ob der Ordner existiert. Wirft sonst `StorageFolderException`. |
| `rotateAndSave(dirUri, jsonStr)` | Ablauf: Ordner prüfen → bestehende Hauptdatei als datiertes Backup kopieren → nur die neuesten 5 Backups behalten (ältere löschen) → Hauptdatei mit formatiertem JSON (`formatJson`) überschreiben. Fehler werden ins Log geschrieben und weitergereicht. |
| `_newBackupName(existing)` | Erzeugt einen freien Namen `…_JJJJ_MM_TT.json`, bei Kollision `…_JJJJ_MM_TT_1.json` usw. |
| `_sortedBackupUris(dirUri)` | Liefert alle Backup-URIs (erkannt per Regex), sortiert nach Datum und Index, älteste zuerst. |

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
| `clearCache()` | Leert den Session-Cache. |

**API-Endpunkt:**
```
GET https://api.frankfurter.app/latest?from={CURRENCY}&to=EUR
```

> ℹ️ Es wird immer der **aktuelle** Kurs abgerufen, nicht der Kurs des Ausgabedatums. Schlägt der Abruf fehl (z. B. offline), liefert die Methode `1.0`. Der Kurs lässt sich im Ausgabeformular deshalb auch von Hand korrigieren.

---

## 7. services/pdf_export_service.dart

**Zweck:** Erzeugt einen PDF-Bericht einer Reise und öffnet das Teilen-Menü des Betriebssystems.

### `class PdfExportService`

| Methode | Beschreibung |
|---------|--------------|
| `shareEventPdf(ev, {from, to})` | Baut die PDF und teilt sie über `Printing.sharePdf`. Dateiname: `TravelBalance_<Reisename>.pdf` (Sonderzeichen → `_`). |
| `buildPdf(ev, {from, to})` | Erstellt die PDF mit drei Abschnitten (siehe unten). |

**Schrift:** Versucht, Roboto über `PdfGoogleFonts` zu laden (benötigt Internet, damit das `€`-Zeichen dargestellt wird). Schlägt das fehl, wird die Standardschrift verwendet und `€` durch `EUR` ersetzt.

**Inhalt:**

| Seite | Format | Inhalt |
|-------|--------|--------|
| Salden | A4 hoch | Kontostand je Person, empfohlene Ausgleichszahlungen, erfasste Ausgleichsbuchungen |
| Statistik | A4 hoch | Zeitraum, Gesamtausgaben, bezahlt je Person, Anteil je Person, Ausgaben nach Kategorie – **verwendet den Zeitraumfilter** aus dem Statistik-Tab |
| Ausgaben | A4 quer | Tabelle aller Ausgaben (Datum, Kategorie, Beschreibung/Notiz, Zahler, Für, Betrag in EUR, Originalbetrag) mit Summe |

Jede Seite hat eine Fußzeile mit Erstellungsdatum und Seitenzahl.

---

## 8. services/log.dart

**Zweck:** Debug-Logging in den **app-eigenen Ordner** (keine Berechtigung nötig).

### `class LogService`

Logdatei: `<App-Ordner>/logs/travelbalance.log`. Ab **5 MB** wird die Datei zu `travelbalance.log.1` umbenannt (eine vorhandene `.1` wird überschrieben) – es entstehen also maximal ca. 10 MB Logdaten.

| Methode | Beschreibung |
|---------|--------------|
| `log(message)` | Schreibt eine Zeile mit Zeitstempel (anhängend) und gibt sie zusätzlich per `debugPrint` aus. Fehler beim Schreiben werden abgefangen. |
| `logFiles()` | Liste der vorhandenen, nicht leeren Logdateien (aktuelle zuerst). |
| `share()` | Öffnet das Teilen-Menü mit den Logdateien. Gibt `false` zurück, wenn es noch keine Logs gibt. |

---

## 9. services/formatjson.dart

**Zweck:** Hilfsfunktion für lesbare JSON-Ausgabe.

### `formatJson(jsonStr)` → `String`
- Parst den JSON-String und gibt ihn mit `JsonEncoder.withIndent('  ')` (2 Leerzeichen) formatiert zurück
- Bei ungültigem JSON: Originalstring wird unverändert zurückgegeben

---

## 10. utils/calculations.dart

**Zweck:** Saldoberechnung, Ausgleichszahlungen und deutsche Zahlenformatierung.

### Zahlenformatierung

| Funktion | Beispiel | Beschreibung |
|----------|----------|--------------|
| `fmtEur(double)` | `1.234,56 €` | EUR-Betrag im deutschen Format |
| `fmtAmt(double, currency)` | `1.234,56 USD` | Betrag mit beliebiger Währung; bei `EUR` wird `fmtEur` verwendet |

Verwendet `NumberFormat('#,##0.00', 'de_DE')` aus dem Paket `intl`.

### `class PersonBalance`

| Feld | Beschreibung |
|------|--------------|
| `personId`, `personName` | Person |
| `paid` | Summe aller tatsächlich geleisteten Zahlungen (EUR) |
| `owed` | Summe aller konsumierten Anteile (EUR) |
| `net` | `paid − owed`: positiv = bekommt Geld zurück, negativ = schuldet |

### `class Settlement`
Empfohlene Ausgleichszahlung: `fromPersonId/Name` (zahlt), `toPersonId/Name` (empfängt), `amount` (EUR, auf 2 Nachkommastellen gerundet).

### `calculateBalances(event, {from, to})` → `List<PersonBalance>`
Berechnet den Saldo jeder Person, optional gefiltert nach Zeitraum.

1. Alle Teilnehmer mit `paid = 0`, `owed = 0` initialisieren
2. Für jede Ausgabe im Zeitraum:
   - Zahler: `paid += payer.amount × exchangeRateToEur`
   - Begünstigte: `owed += beneficiary.amount`
3. Für jede Ausgleichsbuchung im Zeitraum:
   - `fromPerson.paid += amount` (Zahler verbessert seinen Saldo)
   - `toPerson.owed += amount` (Empfänger verringert sein Guthaben)

### `calculateSettlements(balances)` → `List<Settlement>`
Greedy-Algorithmus, der die Zahl der Überweisungen klein hält:

1. Gläubiger (`net > 0,005`) und Schuldner (`net < −0,005`) getrennt nach Betrag absteigend sortieren
2. Größter Schuldner zahlt an größten Gläubiger (Betrag = Minimum beider Restbeträge)
3. Restbeträge anpassen, ausgeglichene Personen überspringen
4. Wiederholen, bis alles ausgeglichen ist

---

## 11. utils/messenger.dart

```dart
final messengerKey = GlobalKey<ScaffoldMessengerState>();
```
Globaler Schlüssel für den `ScaffoldMessenger`. Damit kann der `AppProvider` SnackBars anzeigen (z. B. bei Export-Fehlern), ohne einen `BuildContext` zu besitzen. Wird in `MaterialApp.scaffoldMessengerKey` eingehängt.

---

## 12. screens/home_screen.dart

**Zweck:** Startseite. Zeigt alle Reisen als Liste.

### `class HomeScreen` *(StatelessWidget)*
- Liest `AppProvider` via `context.watch` und sortiert einmal pro Build (`prov.sortedEvents`)
- **AppBar:** Sortier-Menü (Datum auf-/absteigend, Name A–Z / Z–A) und „+"-Button für eine neue Reise
- **Warnbanner (`MaterialBanner`):** erscheint bei `exportError` oder wenn noch kein Ordner gewählt ist. Button „Ordner wählen" bzw. „Erneut versuchen"
- Während `prov.loading`: `CircularProgressIndicator`
- Leerer Zustand: `_EmptyState` mit Hinweis und Button
- Gefüllter Zustand: `ListView` mit `_EventCard` pro Reise
- **FAB:** neue Reise · **Drawer:** `AppDrawer`

### `class _EventCard`

| Anzeige | Beschreibung |
|---------|--------------|
| Name | Fett, groß |
| Zeitraum | `dd.MM.yyyy – dd.MM.yyyy` |
| Chips | Anzahl Personen, Anzahl Ausgaben (`_Chip`) |
| Gesamtbetrag | Summe aller `expense.totalEur`, mit `fmtEur` formatiert |
| 3-Punkte-Menü | `EventMenuButton` (Bearbeiten / Löschen) |

---

## 13. screens/add_edit_event_screen.dart

**Zweck:** Formular zum Anlegen und Bearbeiten einer Reise.

### `class AddEditEventScreen` *(StatefulWidget)*
**Parameter:** `eventId` (optional) – wenn gesetzt: Bearbeitungsmodus.

### Arbeitskopien
Im Bearbeitungsmodus arbeitet der Screen mit **Kopien** der Personen (gleiche IDs) und Kategorien (`_CatEntry`: `original` = gespeicherter Name, `name` = aktueller Name). Erst beim Speichern werden die Änderungen in die Reise übernommen – **Abbrechen verändert nichts**.

### Funktionen

| Funktion | Beschreibung |
|----------|--------------|
| `initState()` | Befüllt Felder und zählt, wie oft Personen (`_personUsage`) und Kategorien (`_categoryUsage`) in Ausgaben und Ausgleichsbuchungen vorkommen |
| `_pickStartDate()` / `_pickEndDate()` | DatePicker; Ende wird nachgezogen, wenn es vor dem Beginn läge |
| `_askName(...)` | Allgemeiner Namensdialog (`_NameDialog`) mit Inline-Validierung |
| `_addParticipant()` / `_renameParticipant()` | Person hinzufügen / umbenennen (Name eindeutig, ohne Beachtung der Groß-/Kleinschreibung; die `id` bleibt erhalten) |
| `_removeParticipant()` | Entfernt eine Person nur, wenn sie in **keinem** Eintrag vorkommt; sonst Hinweisdialog |
| `_addCategory()` / `_renameCategory()` | Eigene Kategorie hinzufügen / umbenennen (keine Duplikate, keine Standardkategorie) |
| `_removeCategory()` | Löscht eine Kategorie; bei Verwendung Rückfrage – betroffene Ausgaben werden beim Speichern auf **„Sonstiges"** gesetzt |
| `_save()` | Validiert Formular (mind. 1 Person). Im Bearbeitungsmodus: Personen übernehmen, Kategorie-Umbenennungen und -Löschungen **in einem Rutsch** auf alle Ausgaben anwenden (damit Tausch und Kettenumbenennungen korrekt sind), dann `prov.updateEvent()`. Sonst `prov.addEvent()`. |

---

## 14. screens/add_edit_expense_screen.dart

**Zweck:** Formular zum Anlegen und Bearbeiten einer Ausgabe. Komplexester Screen der App.

### `class AddEditExpenseScreen` *(StatefulWidget)*
**Parameter:** `eventId` (Pflicht), `expenseId` (optional, Bearbeitungsmodus)

### Formularfelder
Datum · Beschreibung (optional) · Währung + Kurs · Kategorie · Notiz (optional) · **Wer hat bezahlt?** · **Für wen wurde bezahlt?**

### Hilfsmethoden

| Methode | Beschreibung |
|---------|--------------|
| `_init()` | Lädt Teilnehmer und Kategorien; im Bearbeitungsmodus werden alle Felder befüllt. Manuelle Begünstigten-Beträge werden dabei von EUR zurück in die Originalwährung gerechnet (`ben.amount / exchangeRateToEur`). |
| `_toInput(double)` / `_parseInput(String)` | Umwandlung `1234.56` ↔ `"1234,56"` (Komma als Dezimaltrennzeichen) |
| `_fetchRate()` | Holt den Kurs über `CurrencyService` und trägt ihn in das Kursfeld ein; wird bei Währungswechsel und über den Refresh-Button aufgerufen |
| `_buildPayers()` | Erstellt `List<PayerEntry>` aus den aktivierten Zahlern |
| `_buildBeneficiaries()` | **Gleichmäßig:** `Gesamtbetrag in EUR ÷ Anzahl abgehakter Personen`. **Manuell:** Eingabefeld (Originalwährung) × Kurs |
| `_save()` | Validiert (mind. 1 Zahler, Gesamtbetrag > 0, mind. 1 Begünstigter) und ruft `prov.addExpense()` bzw. `prov.updateExpense()` auf |

### Getter

| Getter | Beschreibung |
|--------|--------------|
| `_rate` | Aktueller Wechselkurs aus dem Kursfeld |
| `_totalPayersOriginal` / `_totalPayersEur` | Summe der Zahlerbeträge in Originalwährung bzw. EUR |
| `_totalBenOriginal` | Summe der manuell eingegebenen Beträge (Originalwährung) |
| `_totalBenEur` | Gleichmäßig: `_totalPayersEur` (wenn mind. 1 Person abgehakt); manuell: `_totalBenOriginal × _rate` |
| `_benDiff` / `_benDiffOriginal` | `bezahlt − aufgeteilt` in EUR bzw. Originalwährung |

### Hilfs-Widgets

| Widget | Beschreibung |
|--------|--------------|
| `_SectionCard` | Container mit farbigem Header-Icon und Trennlinie |
| `_PayerRow` | Checkbox + Name + Betragsfeld (Originalwährung) + EUR-Umrechnung |
| `_SplitToggle` / `_ToggleBtn` | Umschalter „Gleich aufteilen" / „Manuell" |
| `_BeneficiaryEqualRow` | Checkbox + Name + berechneter Anteil (Original + EUR) |
| `_BeneficiaryManualRow` | Checkbox + Name + Eingabefeld in **Originalwährung** |
| `_DiffRow` | Zeigt **Gesamt / Aufgeteilt / Differenz** (Original und EUR) mit Farbcodierung: grün = aufgegangen, orange = noch nicht zugewiesen, rot = zu viel zugewiesen |
| `_InfoRow` | Eine Zeile Beschriftung + Wert |

---

## 15. screens/event_detail_screen.dart

**Zweck:** Detailansicht einer Reise mit drei Tabs.

### `class EventDetailScreen` *(StatefulWidget)*
**Parameter:** `eventId`

- `TabController` mit 3 Tabs: **Ausgaben**, **Statistik**, **Salden**
- **AppBar-Aktionen:** *Als PDF teilen* (nutzt den Zeitraumfilter des Statistik-Tabs) und *Bearbeiten*
- Der gewählte Statistik-Zeitraum (`_statFrom` / `_statTo`) liegt in diesem Widget, damit Tab und PDF-Export denselben Filter verwenden
- Der FAB „Neue Ausgabe" wird nur im Tab „Ausgaben" angezeigt
- Wurde die Reise gelöscht, erscheint „Reise nicht gefunden"

---

### Tab 1: `_ExpensesTab`
Liste aller Ausgaben, absteigend nach Datum sortiert. Ein Tipp auf eine Karte öffnet die Ausgabe zum **Bearbeiten**.

**`_ExpenseCard`:** Kategorie-Badge, Datum, EUR-Betrag (plus Originalbetrag bei Fremdwährung), Beschreibung, Zahler-Namen, Notiz. Popup-Menü mit „Löschen" (nach Bestätigung).

**`_CategoryBadge`:** Farbiger Chip je Kategorie (feste Farben für Standardkategorien, Teal für eigene).

---

### Tab 2: `_StatisticsTab` *(StatefulWidget)*

**Standardzeitraum:** Datum der **ersten bis letzten vorhandenen Ausgabe** (ohne Ausgaben: Reisezeitraum). Die DatePicker sind auf diesen Bereich begrenzt; der Reset-Button setzt den Filter zurück.

| Berechnung | Beschreibung |
|------------|--------------|
| Gefilterte Ausgaben | Alle Ausgaben im gewählten Zeitraum (tagesgenau) |
| `personPaid` | Tatsächliche Zahlungen je Person in EUR |
| `personOwed` | Summe der Begünstigten-Anteile je Person (was wurde „verbraucht") |
| `catTotals` | Summe je Kategorie, absteigend sortiert |

**Angezeigte Abschnitte:** Zeitraumfilter · Gesamtausgaben (Summe + Anzahl) · Bezahlt je Person · Ausgaben je Person (Anteil) · Ausgaben nach Kategorie.

**`_StatRow`:** Name + `LinearProgressIndicator` + Betrag.

---

### Tab 3: `_BalancesTab` *(StatefulWidget)*
Die Salden berücksichtigen **alle** Ausgaben (der Statistik-Zeitraum gilt hier nicht).

#### `_showSettlementDialog()`
Dialog zur Erfassung einer Ausgleichsbuchung:
- Datumswähler
- Dropdown „Von (Zahler)" und „An (Empfänger)" – wählt man dieselbe Person in beiden, werden die Felder **getauscht** statt blockiert
- Betrag in EUR (Komma oder Punkt)
- Validierung: Betrag > 0, Von ≠ An
- Speichert über `prov.addManualSettlement()`

#### Angezeigte Abschnitte
1. **Kontostand je Person** (`_BalanceCard`) – `paid`, `owed`, `net` in Grün (bekommt zurück) / Rot (schuldet)
2. **Empfohlene Ausgleichszahlungen** (`_SettlementCard`) – aus `calculateSettlements()`; grüner Haken, wenn alles ausgeglichen ist
3. **Ausgleichsbuchungen** – Liste der erfassten Buchungen mit Datum, Von → An, Betrag und Löschen-Button

---

## 16. screens/settings_screen.dart

**Zweck:** Einstellungen für Sicherungsordner, Export/Import und Diagnose.

### `class SettingsScreen` *(StatelessWidget)*

| Abschnitt | Inhalt |
|-----------|--------|
| **Speicherort** | Zeigt den gewählten Ordner (`prettyFolder`, z. B. „Interner Speicher/Download/TravelBalance") und ggf. die Ordner-Warnung. Button „Speicherort wählen" → `prov.chooseExportFolder()` |
| **Export & Import** | **„Jetzt exportieren"** → `prov.exportNow()` mit Erfolgs-/Fehlermeldung. **„JSON importieren"** → `FilePicker.pickFiles` (nur `.json`), liest die Datei und ruft `prov.importFromJson()` auf (⚠️ ersetzt alle Reisen) |
| **Diagnose** | **„Log teilen"** → `LogService.share()`; Hinweis, wenn noch keine Logs existieren |
| **Info** | App-Name, Version, Slogan |

`prettyFolder(uri)` wandelt eine `content://`-URI in eine lesbare Pfadangabe um.

---

## 17. widgets/app_drawer.dart

**Zweck:** Seitenmenü mit Reiseliste und Einstellungen-Link am unteren Rand.

### `class AppDrawer` *(StatelessWidget)*
Verwendet `context.watch<AppProvider>()` und zeigt die Reisen in der gewählten Sortierung (`prov.sortedEvents`).

```
DrawerHeader
│  Icon + "TravelBalance" + "Reisekosten teilen"
│
Expanded (scrollbar)
│  "Meine Reisen" (Tipp → zurück zur Startseite)   [+ Neue Reise]
│  ─────────────────────────────────────────────
│  • Reise 1  (Avatar, Name, "x Personen · y Ausgaben", 3-Punkte-Menü)
│  • Reise 2
│  ...
│
─────────────────────────────────────────────────
Einstellungen (ListTile)
Version-Info
```

#### Navigation bei Reise-Tipp
```dart
Navigator.pop(context);                              // Drawer schließen
Navigator.of(context).popUntil((r) => r.isFirst);   // Zurück zur Startseite
Navigator.push(context, EventDetailScreen(...));     // Reise öffnen
```

---

## 18. widgets/event_menu_button.dart

**Zweck:** Wiederverwendbares 3-Punkte-Menü (Bearbeiten / Löschen) für eine Reise. Wird auf der Startseite und im Seitenmenü verwendet.

### `class EventMenuButton` *(StatelessWidget)*

| Parameter | Beschreibung |
|-----------|--------------|
| `event` | Die betroffene `TravelEvent` |
| `closeDrawerOnEdit` | `true` im Drawer: Der Drawer wird vor dem Öffnen des Bearbeiten-Screens geschlossen |
| `iconSize` | Optionale Icon-Größe |

- **Bearbeiten** → `AddEditEventScreen(eventId: …)`
- **Löschen** → Bestätigungsdialog, dann `prov.deleteEvent()` (löst einen Export aus)

---

## 19. Datenfluss & Architektur

```
┌─────────────────────────────────────────────────────┐
│                   UI (Screens/Widgets)              │
│  HomeScreen  │  EventDetailScreen  │  AddEdit...    │
└──────┬───────┴──────────┬──────────┴───────┬────────┘
       │ context.watch    │                  │ context.read
       ▼                  ▼                  ▼
┌──────────────────────────────────────────────────────┐
│                    AppProvider                       │
│  List<TravelEvent> events                            │
│  addEvent / updateEvent / deleteEvent                │
│  addExpense / updateExpense / deleteExpense          │
│  addManualSettlement / deleteManualSettlement        │
└──────────┬───────────────────────────────────────────┘
           │ _persist()
    ┌──────┴──────────────────────┐
    │                             │
    ▼                             ▼
SharedPreferences          StorageService
(schnell, intern)          (JSON-Datei im SAF-Ordner
                            + max. 5 Backups)
```

### Wann wird exportiert?

| Aktion | Export |
|--------|:------:|
| Reise anlegen / ändern / löschen | ✅ |
| Ausgabe anlegen / ändern / löschen | ✅ |
| Ausgleichsbuchung anlegen / löschen | ✅ |
| „Jetzt exportieren" / Ordner wählen | ✅ |
| JSON importieren | ❌ (nur interne Speicherung) |
| Sortierung ändern | ❌ |

### Währungsfluss
```
Nutzer wählt Währung
       │
       ▼
CurrencyService.getRateToEur()
       │  GET api.frankfurter.app
       ▼
Kurs im Formular (manuell änderbar)
       │
       ▼
exchangeRateToEur wird in der Expense gespeichert
       │
       ▼
calculations.dart: amount × exchangeRateToEur = EUR-Betrag
```

### Saldoberechnung
```
calculateBalances(event)
  ├── Für jede Expense:   payer.paid += amount × rate
  │                        ben.owed  += ben.amount
  └── Für jede ManualSettlement:
                           from.paid += ms.amount
                           to.owed   += ms.amount

calculateSettlements(balances)
  └── Greedy-Algorithmus minimiert die Überweisungsanzahl
```

---

## 20. Dateiformat des JSON-Exports

Die Datei enthält eine **Liste aller Reisen**. Dieselbe Struktur erwartet der Import.

```json
[
  {
    "id": "…uuid…",
    "name": "Italien 2026",
    "startDate": "2026-08-01T00:00:00.000",
    "endDate": "2026-08-14T00:00:00.000",
    "participants": [
      { "id": "…uuid…", "name": "Anna" },
      { "id": "…uuid…", "name": "Ben" }
    ],
    "expenses": [
      {
        "id": "…uuid…",
        "date": "2026-08-02T00:00:00.000",
        "description": "Hotel",
        "payers": [ { "personId": "…Anna…", "amount": 300.0 } ],
        "currency": "EUR",
        "exchangeRateToEur": 1.0,
        "category": "Unterkunft",
        "note": "",
        "beneficiaries": [
          { "personId": "…Anna…", "amount": 150.0 },
          { "personId": "…Ben…", "amount": 150.0 }
        ],
        "isEqualSplit": true
      }
    ],
    "customCategories": [],
    "manualSettlements": [
      {
        "id": "…uuid…",
        "fromPersonId": "…Ben…",
        "toPersonId": "…Anna…",
        "date": "2026-08-10T00:00:00.000",
        "amount": 50.0
      }
    ]
  }
]
```

| Hinweis | Erklärung |
|---------|-----------|
| `payers[].amount` | in **Originalwährung** |
| `beneficiaries[].amount` | in **EUR** |
| `manualSettlements[].amount` | in **EUR** |
| `customCategories`, `manualSettlements` | optional – fehlen sie, werden leere Listen angenommen |

---

## 21. pubspec.yaml – Abhängigkeiten

**Dart SDK:** `^3.13.4` · **App-Version:** `0.0.1+4`

| Package | Version | Verwendung |
|---------|---------|------------|
| `provider` | ^6.1.5+1 | State-Management (`ChangeNotifier`) |
| `uuid` | ^4.6.0 | UUID-Generierung für alle Modell-IDs |
| `intl` | ^0.20.3 | Datums- und Zahlenformatierung (`de_DE`) |
| `shared_preferences` | ^2.5.5 | Interne Speicherung der Daten, des Ordners und der Sortierung |
| `http` | ^1.6.0 | HTTP-Anfragen an die Frankfurter API |
| `file_picker` | ^13.1.0 | Dateiauswahl für den JSON-Import |
| `path_provider` | ^2.1.6 | App-Ordner für Logdateien |
| `path` | ^1.9.1 | Plattformübergreifende Pfad-Manipulation |
| `pdf` | ^3.11.1 | PDF-Erzeugung |
| `printing` | ^5.13.1 | PDF-Schriften und Teilen (`Printing.sharePdf`) |
| `saf_util` | ^3.1.1 | Android SAF: Ordnerwahl, Auflisten, Löschen |
| `saf_stream` | ^4.0.2 | Android SAF: Dateien lesen und schreiben |
| `share_plus` | ^13.3.1 | Teilen-Menü für Logdateien |
| `flutter_localizations` | SDK | Deutsche Datumspicker und Dialoge |
| `cupertino_icons` | ^2.0.0 | iOS-Icons |

**Dev-Abhängigkeiten:** `flutter_test`, `flutter_lints` (^6.0.0), `flutter_launcher_icons` (^0.14.3, Konfiguration für das App-Icon in `pubspec.yaml`).

**Assets:** `assets/icon/app_icon.png`

---

## 22. Android-Build-Konfiguration

| Datei | Wichtige Einstellungen |
|-------|-----------------------|
| `android/app/build.gradle.kts` | `namespace` / `applicationId`: `com.example.travelbalance` · `compileSdk = 37` · Java/Kotlin-Target 17 · Release derzeit mit **Debug-Signatur** |
| `android/settings.gradle.kts` | Flutter-Plugin-Loader, Android Gradle Plugin `9.1.0`, Kotlin `2.4.0` |
| `android/gradle.properties` | `org.gradle.jvmargs=-Xmx8G …`, `android.useAndroidX=true` |
| `android/local.properties` | Rechnerspezifisch (SDK-Pfade, Version) – wird von Flutter erzeugt und **nicht** eingecheckt |
| `AndroidManifest.xml` | Berechtigung `INTERNET` (Wechselkurse); App-Label „TravelBalance". Speicherberechtigungen sind nicht nötig, da der Ordner über das SAF gewählt wird |

> Vor einer Veröffentlichung sollten `applicationId` (derzeit das Platzhalter-Präfix `com.example`) und die Release-Signatur angepasst werden: <https://docs.flutter.dev/deployment/android>

---

[← Zurück zur Startseite (README)](../README.md)

*TravelBalance · Code-Dokumentation*
