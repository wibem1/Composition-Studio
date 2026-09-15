# Composition Studio – verbindlicher Projektstatus

**Stand:** 15. September 2026, nach erfolgreichem MiniDAW-CI-Build

> Diese Datei ist die technische Wahrheit für den aktuellen Entwicklungsstand. Bei Widersprüchen zwischen Chatverläufen, Geräten oder älteren Notizen gilt diese Datei zusammen mit dem aktuellen Repository-Stand.

## 1. Aktuelle Strategie

Die bisherige Composition-Studio-Entwicklung bis einschließlich **V1.0RC** wurde praktisch auf einem Intel-MacBook getestet. Der Release Candidate erwies sich als **nicht brauchbar**. Die Strategie, den bisherigen Gesamtaufbau durch weitere Einzelreparaturen funktionsfähig zu machen, wurde deshalb aufgegeben.

Der neue Ansatz lautet: **zuerst eine kleine, tatsächlich lauffähige MiniDAW als technisches Fundament bauen.** Erst wenn deren Kernfunktionen zuverlässig funktionieren, wird darauf das vollständige Composition Studio aufgebaut.

Der erste MiniDAW-Funktionsnachweis ist jetzt **erfolgreich kompiliert und technisch paketiert**. Der lokale Praxistest auf dem Intel-MacBook ist der nächste Schritt. Ein erfolgreicher CI-Build allein gilt weiterhin ausdrücklich nicht als Nachweis hörbarer Wiedergabe oder lokaler Plugin-Funktion.

## 2. Ziel von Composition Studio

Composition Studio soll eine praktisch benutzbare Musikproduktions- und Kompositionsumgebung für macOS werden. Vorgesehen sind insbesondere:

- Arrangement mit echten Spuren und Clips
- MIDI-Import und MIDI-Export
- Transport mit sichtbar mitlaufender Playposition
- Instrument-/Plugin-Browser
- VST3/AU-Instrument- und Effekt-Hosting
- hörbare MIDI-Wiedergabe über Instrument-Plugins
- Routing und Mixer
- Projekt laden und speichern
- Piano-Roll und Notenfunktionen
- KI-/MusicChat-Integration für Komposition, Analyse, Variation und Weiterentwicklung musikalischen Materials

## 3. Architektur

Die vereinbarte Grundarchitektur bleibt:

**Composition Studio → EngineBridge → MAGDA**

- **Composition Studio:** eigene Oberfläche, musikalischer Workflow und KI-Funktionen.
- **EngineBridge:** klar definierte, möglichst kleine Schnittstelle zwischen Oberfläche und Engine.
- **MAGDA:** technische Engine für Audio, MIDI, Plugin-Hosting und grundlegende DAW-Funktionen. MAGDA soll möglichst wenig verändert werden.

Die MiniDAW benutzt genau dieses Prinzip als kleinen Funktionsnachweis: Swift/AppKit-Oberfläche → CompositionStudioEngineBridge → gepinnte MAGDA-Engine.

## 4. Verbindliches GUI-Ziel

Der bereits freigegebene helle Composition-Studio-GUI-Entwurf bleibt die visuelle Zielsetzung. Er soll **nicht aufgrund technischer Neuaufbauten neu gestaltet werden**.

Wesentliche Merkmale:

- hell, freundlich und kontrastreich
- klare optische Gliederung der Bereiche
- Arrangement deutlich von den umgebenden Panels abgesetzt
- unterschiedliche Helligkeitsstufen statt monotonem Grau
- dezente Farben, keine unnötige Buntheit
- links KI-/MusicChat-Bereich
- Mitte Arrangement
- rechts Browser
- unten Inspector/Routing, Piano-Roll/Notation und Transport
- Branding: **COMPOSITION STUDIO by Klangwerke**

Die MiniDAW selbst ist ausdrücklich **kein GUI-Entwurf**, sondern ein technischer Prüfstand.

## 5. MiniDAW – aktueller Funktionsnachweis

### Branch und Build

- Entwicklungsbranch: `minidaw-proof-v1-final`
- getesteter CI-Commit: `1b622d0e3dc6c0e9eb0469fdb79253d4f35e9f09`
- Commit-Titel: `MiniDAW: cache MAGDA dependencies and bridge build`
- Workflow: `Build MiniDAW Proof`
- Workflow-Run: `34974631772`
- Ergebnis: **SUCCESS**
- Zielarchitektur: **x86_64 / Intel Mac**
- Deployment Target: macOS 11.0
- gepinnter MAGDA-Stand: `15e9071d657bf9179432c6a0a3a62f8dd686d8a1`

### Erzeugtes Artefakt

- Name: `MiniDAW-Proof-Intel`
- Artifact ID: `10400176565`
- Größe: 26,784,175 Bytes
- SHA-256: `09f6922d939d6148416b99d81e9d44d6181178a273bda24f0b47c9efd637df71`
- Aufbewahrung durch GitHub Actions: 30 Tage

Der Workflow hat vor dem Upload automatisch geprüft:

- Bridge-Dylib vorhanden und x86_64
- Swift-App erfolgreich gebaut
- Info.plist syntaktisch gültig
- App-Binary x86_64
- dynamische Verknüpfung zur CompositionStudioEngineBridge vorhanden
- Ad-hoc-Codesign der Bridge und App
- `codesign --verify --deep --strict` erfolgreich
- ZIP-Paket erfolgreich erzeugt

### Was die MiniDAW tatsächlich implementiert

Die MiniDAW ist bewusst klein. Beim Start initialisiert sie die MAGDA-Engine und erzeugt eine echte Testspur mit einem MIDI-Clip und vier Noten **C–E–G–C**. Das Tempo wird auf 120 BPM gesetzt.

Die Oberfläche bietet genau den vorgesehenen technischen Testpfad:

1. **Plugins suchen** – startet den MAGDA-Plugin-Scan.
2. **Instrument auswählen/laden** – zeigt gefundene Instrument-Plugins und fügt das ausgewählte Instrument der Testspur hinzu.
3. **Ton testen** – sendet einen Preview-Ton an das Instrument auf der Spur.
4. **Play** – setzt die Position auf 0 und startet den echten MAGDA-Transport.
5. **Stop** – stoppt den MAGDA-Transport.

Zusätzlich zeigt die MiniDAW getrennt:

- Engine-Status
- Transportstatus und Transportposition
- Position des Audio-Threads
- Anzahl gefundener Instrumente
- eine sichtbar mitlaufende Playhead-Anzeige

Damit ist der Codepfad für **Spur/Clip → MIDI → Instrument → Transport → Audio-Thread/Playposition** vorhanden. Ob das auf dem Ziel-Mac tatsächlich hörbar und synchron funktioniert, muss der lokale Praxistest bestätigen.

## 6. MiniDAW-Build-Cache

Für die MiniDAW ist jetzt ein eigener GitHub-Actions-Cache eingerichtet.

Der Cache speichert die fertig kompilierte `libCompositionStudioEngineBridge.dylib`. Sein Schlüssel hängt ab von:

- Betriebssystem
- x86_64-Architektur
- gepinntem MAGDA-Commit
- SHA-256-artigem Hash des gesamten `native/EngineBridge`-Quellbaums

Aktueller Cache-Key:

`minidaw-engine-macOS-x86_64-15e9071d657bf9179432c6a0a3a62f8dd686d8a1-4d535e8a860385e4ca113eb5ba9ac458cad3c3e6b1d528f4e20a52c8ed25817f`

Beim ersten erfolgreichen Lauf war erwartungsgemäß noch kein Cache vorhanden. Nach erfolgreichem vollständigem MAGDA-/Bridge-Build wurde der Cache unter diesem Schlüssel gespeichert. Bei einem folgenden Build mit unverändertem MAGDA-Stand und unveränderter Bridge können MAGDA-Checkout, Submodule, CMake-Konfiguration und der sehr große C++-Build übersprungen werden. Änderungen nur an `MiniDAW.swift` sollten dadurch erheblich schneller bauen.

Wichtig: Ändert sich die EngineBridge, wird absichtlich ein neuer Cache-Key erzeugt und die Bridge vollständig neu gebaut. Das verhindert, dass ein veralteter Engine-Unterbau unbemerkt verwendet wird.

## 7. Abnahmekriterium auf dem Intel-MacBook

Die erste entscheidende Funktionskette lautet:

**App starten → Testspur/Clip → Instrument-Plugin → Ton → Play → hörbare MIDI-Wiedergabe → sichtbar/synchron mitlaufende Playposition**

Für den nächsten Praxistest sind folgende Punkte verbindlich:

1. App startet stabil und zeigt `Engine: bereit`.
2. `Testspur + C–E–G–C angelegt` erscheint.
3. `Plugins suchen` findet installierte Instrumente, insbesondere nach Möglichkeit Pianoteq.
4. Ein Instrument lässt sich auswählen und laden; es erscheint keine Fehlermeldung.
5. `Ton testen` erzeugt einen hörbaren Ton über das geladene Instrument.
6. `Play` startet den Transport und die vier MIDI-Noten C–E–G–C sind hörbar.
7. Die angezeigte Transportposition läuft vorwärts.
8. Die Audio-Thread-Position läuft plausibel mit der Transportposition mit.
9. Der rote Playhead bewegt sich sichtbar.
10. `Stop` hält Wiedergabe und Transport zuverlässig an.
11. Der Ablauf wird mindestens ein zweites Mal wiederholt, ohne Absturz oder inkonsistenten Zustand.

**Erst wenn dieser lokale Test bestanden ist, gilt die MiniDAW als belastbares technisches Fundament.**

## 8. Verworfene bzw. historische Stände

- Frühere V0.x-Stände waren Entwicklungs- und Integrationsstufen, nicht der aktuelle Ausgangspunkt.
- **V1.0RC:** auf dem MacBook praktisch getestet und als unbrauchbar verworfen.
- Die alte Strategie „den RC durch weitere Klecker-Reparaturen retten“ ist beendet.
- Alte Branches, Artefakte und Chatangaben dürfen nicht automatisch als aktueller Entwicklungsstand interpretiert werden.

Historischer Code darf weiterhin als Quelle für funktionierende Einzelbausteine dienen. Er ist aber nicht automatisch Teil der neuen Basis.

## 9. Entwicklungsregeln

1. **Keine Klecker-Versionen zur Abnahme.** Zwischenstände dürfen intern gebaut werden, werden aber nicht als neue Version an den Anwender herausgegeben.
2. **Build-Erfolg ist nicht gleich Funktionsnachweis.** Automatisierbare Tests werden vor Herausgabe durchgeführt; Hardware-, Audio- und lokale Plugin-Tests werden klar als solche ausgewiesen.
3. **Keine GUI-Neuerfindung.** Der freigegebene Entwurf bleibt das Ziel.
4. **Keine unnötige MAGDA-Modifikation.** Engine-Funktionen werden bevorzugt über eine definierte Bridge genutzt.
5. **Fehler werden nicht durch Attrappen kaschiert.** Ein sichtbarer Button oder eine statische Darstellung zählt nicht als implementierte Funktion.
6. **Funktion vor Umfang.** Erst eine kleine vollständig funktionierende Kette, dann Erweiterung.
7. **GitHub ist das Projektgedächtnis.** Relevante Strategieänderungen, getestete Stände und bekannte Blocker werden hier dokumentiert.
8. **Chats sind nicht verbindlich.** Vor Änderungen am Projekt ist zuerst dieser Status und anschließend der aktuelle Repository-Stand zu prüfen.

## 10. Arbeitsablauf ab jetzt

Vor jeder neuen Entwicklungsarbeit:

1. `PROJECT_STATUS.md` lesen.
2. aktuellen Branch/Commit und relevante Build-Ergebnisse prüfen.
3. nicht aufgrund eines möglicherweise veralteten Chatverlaufs zurückspringen.

Nach jedem wesentlichen Test oder Strategiewechsel:

1. Ergebnis dokumentieren,
2. getesteten Commit/Build eindeutig nennen,
3. funktionierende und nicht funktionierende Punkte trennen,
4. nächsten technischen Schritt festhalten.

## 11. Aktuell nächster Schritt

**Das erfolgreiche Artefakt `MiniDAW-Proof-Intel` auf dem Intel-MacBook praktisch testen.**

Der CI-Stand ist technisch sauber gebaut und paketiert. Noch nicht nachgewiesen sind die entscheidenden maschinenspezifischen Punkte: Start auf dem Ziel-Mac, lokaler Plugin-Scan, tatsächliche Plugin-Instanziierung, Audioausgabe und Synchronität zwischen hörbarer Wiedergabe, Transportposition und Audio-Thread.

Nach diesem Praxistest wird diese Datei erneut mit dem tatsächlichen Testergebnis aktualisiert. Erst danach beginnt die Erweiterung in Richtung vollständiges Composition Studio.
