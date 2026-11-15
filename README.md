# 🧳 TravelBalance

**Reisekosten einfach aufteilen – ohne Zettelwirtschaft und ohne Streit.**

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)
![Plattform](https://img.shields.io/badge/Android-Ziel%3A%20Android%20%26%20iOS-3DDC84?logo=android&logoColor=white)

TravelBalance ist eine App, mit der du die Kosten einer gemeinsamen Reise zwischen mehreren Personen aufteilst. Du trägst ein, wer etwas bezahlt hat und für wen – die App rechnet aus, wer am Ende wem wie viel Geld schuldet.

> 📖 Die technische Beschreibung des Codes findest du auf einer eigenen Seite: **[Code-Dokumentation → docs/DOKUMENTATION.md](docs/DOKUMENTATION.md)**

---

## Inhaltsverzeichnis

1. [Was kann TravelBalance?](#was-kann-travelbalance)
2. [Ein Beispiel](#ein-beispiel)
3. [Daten sichern: JSON-Export und -Import](#daten-sichern-json-export-und--import)
4. [Entwickelt mit Flutter](#entwickelt-mit-flutter)
5. [Installation der Entwicklungsumgebung](#installation-der-entwicklungsumgebung)
6. [App starten und bauen](#app-starten-und-bauen)
7. [Projektstruktur](#projektstruktur)
8. [Dokumentation](#dokumentation)

---

## Was kann TravelBalance?

- 🗺️ **Reisen anlegen** – mit Name, Zeitraum (von – bis) und beliebig vielen Mitreisenden.
- 💶 **Ausgaben erfassen** – Datum, Betrag, Kategorie und Notiz. Es können auch **mehrere Personen** unterschiedlich hohe Beträge für dieselbe Rechnung bezahlen.
- ⚖️ **Rechnungen flexibel aufteilen** – entweder **gleichmäßig** auf alle (oder nur auf ausgewählte Personen) oder **manuell** mit eigenen Beträgen. Bei der manuellen Aufteilung zeigt die App sofort an, wie viel vom Betrag schon verteilt ist und wie viel noch fehlt.
- 💱 **Fremdwährungen** – den Wechselkurs holt die App automatisch ab; alle Beträge werden zusätzlich in **Euro** umgerechnet.
- 🏷️ **Kategorien** – Unterkunft, Essen & Trinken, Transport, Aktivitäten, Einkaufen, Maut und Sonstiges. Pro Reise kannst du **eigene Kategorien** ergänzen.
- 📊 **Statistik** – Gesamtausgaben, Ausgaben je Person und je Kategorie; der Zeitraum lässt sich einschränken.
- 🤝 **Salden** – die App zeigt, **wer wem wie viel** überweisen muss, damit alle quitt sind. Bereits bezahlte Ausgleichszahlungen kannst du als „Ausgleichsbuchung" erfassen.
- 📄 **PDF teilen** – Salden, Statistik und Ausgabenliste als PDF über das Teilen-Menü versenden.
- 💾 **Automatische Sicherung als JSON** – siehe [unten](#daten-sichern-json-export-und--import).

---

## Ein Beispiel

Anna, Ben und Clara sind gemeinsam im Urlaub:

| Wer zahlt? | Was? | Betrag |
|------------|------|-------:|
| Anna | Hotel | 300,00 € |
| Ben | Abendessen | 90,00 € |
| Clara | Maut | 60,00 € |

Die Gesamtkosten betragen 450 €, jeder trägt also 150 €. TravelBalance zeigt:

- **Clara zahlt Anna** 90,00 €
- **Ben zahlt Anna** 60,00 €

Damit ist alles ausgeglichen – mit nur zwei Überweisungen.

---

## Daten sichern: JSON-Export und -Import

Deine Daten gehören dir. TravelBalance legt sie als gut lesbare **JSON-Datei** in einem Ordner deiner Wahl ab.

**Export**

- Du wählst einmalig in den **Einstellungen** einen Sicherungsordner.
- Bei **jedem Speichern oder Löschen** (Reise, Ausgabe, Ausgleichsbuchung) schreibt die App die Datei `travelbalance_export.json` neu.
- Vor dem Überschreiben wird die alte Datei als datierte Kopie gesichert (z. B. `travelbalance_export_2026_10_06.json`). Es bleiben **maximal 5 Kopien** erhalten, die älteste wird automatisch gelöscht.
- Über **Einstellungen → Jetzt exportieren** kannst du die Sicherung jederzeit manuell auslösen.
- Wird der Sicherungsordner gelöscht oder ist er nicht mehr erreichbar, weist dich die App darauf hin.

**Import**

- Unter **Einstellungen → JSON importieren** wählst du eine Sicherungsdatei aus.
- ⚠️ Der Import **ersetzt alle vorhandenen Reisen** durch den Inhalt der Datei. Exportiere vorher, wenn du den aktuellen Stand behalten möchtest.

So kannst du deine Daten sichern, auf ein neues Handy umziehen oder mit anderen Programmen weiterverarbeiten.

---

## Entwickelt mit Flutter

Der gesamte Code ist in **[Flutter](https://flutter.dev)** (Programmiersprache **[Dart](https://dart.dev)**) geschrieben. Damit entsteht aus einer einzigen Codebasis eine App für **Android und iOS**.

| Bereich | Eingesetzt |
|---------|-----------|
| Framework | [Flutter](https://flutter.dev) / [Dart](https://dart.dev) |
| State-Management | [provider](https://pub.dev/packages/provider) |
| Lokale Speicherung | [shared_preferences](https://pub.dev/packages/shared_preferences) + JSON-Datei |
| Wechselkurse | [Frankfurter API](https://api.frankfurter.app) (kostenlos, kein Schlüssel nötig) |
| PDF-Export | [pdf](https://pub.dev/packages/pdf), [printing](https://pub.dev/packages/printing), [share_plus](https://pub.dev/packages/share_plus) |
| Sicherungsordner (Android) | [saf_util](https://pub.dev/packages/saf_util), [saf_stream](https://pub.dev/packages/saf_stream) |

> ℹ️ **Hinweis zu iOS:** Die Auswahl des Sicherungsordners nutzt das Android-eigene *Storage Access Framework (SAF)*. Der Android-Build ist der aktuell vorgesehene Hauptweg; für iOS muss die Ordnerwahl noch angepasst werden.

---

## Installation der Entwicklungsumgebung

Wenn du den Code selbst ausführen oder weiterentwickeln möchtest, brauchst du die folgenden Werkzeuge.

### 1. Flutter SDK installieren

Die offizielle Anleitung deckt Windows, macOS und Linux ab:

👉 **<https://docs.flutter.dev/get-started/install>**

Das Flutter SDK bringt Dart bereits mit. Das Projekt benötigt eine aktuelle stabile Flutter-Version mit **Dart 3.13.4 oder neuer** (siehe `pubspec.yaml`).

Prüfe die Installation anschließend im Terminal:

```bash
flutter --version
flutter doctor
```

`flutter doctor` zeigt dir, was noch fehlt (z. B. Android-Lizenzen oder Xcode).

### 2. Git installieren

Zum Herunterladen des Repositories: <https://git-scm.com/downloads>

### 3. Editor / IDE wählen

| Editor | Link | Zusätzlich nötig |
|--------|------|------------------|
| **Visual Studio Code** | <https://code.visualstudio.com> | [Flutter-Erweiterung](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter) (installiert auch die Dart-Erweiterung) |
| **Android Studio** | <https://developer.android.com/studio> | Plugins *Flutter* und *Dart* |

Anleitung zur Editor-Einrichtung: <https://docs.flutter.dev/get-started/editor>

### 4. Für Android: Android-SDK einrichten

1. **Android Studio** installieren (<https://developer.android.com/studio>). Es bringt das Android SDK mit.
2. In Android Studio unter *Settings → Languages & Frameworks → Android SDK → SDK Tools* die **Android SDK Command-line Tools** installieren.
3. Android-Lizenzen akzeptieren:
   ```bash
   flutter doctor --android-licenses
   ```
4. **JDK 17** wird für den Gradle-Build benötigt. Das von Android Studio mitgelieferte JDK reicht; alternativ z. B. [Eclipse Temurin](https://adoptium.net).

Offizielle Anleitung: <https://docs.flutter.dev/platform-integration/android/setup>

### 5. Für iOS (nur auf einem Mac)

1. **Xcode** aus dem Mac App Store installieren: <https://developer.apple.com/xcode/>
2. **CocoaPods** installieren: <https://guides.cocoapods.org/using/getting-started.html>
3. Xcode einmal starten und die Lizenz akzeptieren.

Offizielle Anleitung: <https://docs.flutter.dev/platform-integration/ios/setup>

### 6. Testgerät bereitstellen

- **Echtes Android-Handy:** Entwickleroptionen und USB-Debugging aktivieren, per USB anschließen.
- **Emulator:** in Android Studio über den *Device Manager* anlegen (<https://developer.android.com/studio/run/managing-avds>).
- **iOS-Simulator:** wird mit Xcode installiert.

---

## App starten und bauen

```bash
# 1. Repository klonen
git clone https://github.com/<dein-benutzername>/travelbalance.git
cd travelbalance

# 2. Abhängigkeiten laden
flutter pub get

# 3. Verfügbare Geräte anzeigen
flutter devices

# 4. App im Debug-Modus starten
flutter run
```

> 💡 In **VS Code** startest du die App alternativ mit `F5` und wählst unten rechts das Zielgerät aus.

**Release-Build für Android (APK):**

```bash
flutter build apk --release
```

Die fertige Datei liegt danach unter `build/app/outputs/flutter-apk/app-release.apk`.

**Release-Build für iOS (nur auf dem Mac):**

```bash
flutter build ios --release
```

> ⚠️ **Hinweise**
> - Die Datei `android/local.properties` enthält Pfade deines Rechners (SDK-Ordner). Flutter erzeugt sie automatisch; sie gehört **nicht** ins Git-Repository.
> - Der Release-Build ist derzeit mit dem Debug-Schlüssel signiert. Für eine Veröffentlichung (z. B. im Play Store) brauchst du eine eigene Signatur: <https://docs.flutter.dev/deployment/android>

Weitere Flutter-Grundlagen: <https://docs.flutter.dev/get-started/codelab>

---

## Projektstruktur

```
lib/
├── main.dart                 # Einstiegspunkt, Theme, Lokalisierung
├── models/                   # Datenmodelle (Reise, Person, Ausgabe …)
├── providers/                # State-Management (AppProvider)
├── services/                 # Speichern, Wechselkurse, PDF, Log
├── utils/                    # Berechnungen und Formatierung
├── screens/                  # Bildschirme der App
└── widgets/                  # Wiederverwendbare Bausteine (Seitenmenü …)
```

Eine Beschreibung jeder einzelnen Datei findest du in der **[Code-Dokumentation](docs/DOKUMENTATION.md)**.

---

## Dokumentation

| Seite | Inhalt |
|-------|--------|
| 📖 [docs/DOKUMENTATION.md](docs/DOKUMENTATION.md) | Ausführliche Code-Dokumentation: Datenmodelle, Berechnungslogik, Dateiformat des Exports, Screens, Architektur und Abhängigkeiten |

---

*TravelBalance · Reisekosten einfach aufteilen*
