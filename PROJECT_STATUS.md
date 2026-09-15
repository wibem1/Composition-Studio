# Composition Studio – verbindlicher Projektstatus

**Stand:** 15. September 2026

> Diese Datei ist die technische Wahrheit für den aktuellen Entwicklungsstand. Bei Widersprüchen zwischen Chatverläufen, Geräten oder älteren Notizen gilt diese Datei zusammen mit dem aktuellen Repository-Stand.

## 1. Aktuelle Strategie

Die bisherige Composition-Studio-Entwicklung bis einschließlich **V1.0RC** wurde praktisch auf einem Intel-MacBook getestet. Der Release Candidate erwies sich als **nicht brauchbar**. Die Strategie, den bisherigen Gesamtaufbau durch weitere Einzelreparaturen funktionsfähig zu machen, wurde deshalb aufgegeben.

Der neue Ansatz lautet: **zuerst eine kleine, tatsächlich lauffähige MiniDAW als technisches Fundament bauen.** Erst wenn deren Kernfunktionen zuverlässig funktionieren, wird darauf das vollständige Composition Studio aufgebaut.

Die MiniDAW befindet sich derzeit im Build-/Teststadium. Ein erfolgreicher Build allein gilt ausdrücklich **nicht** als Nachweis der Funktionsfähigkeit.

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

Die MiniDAW darf diese Architektur vereinfachen, solange sie als belastbares Fundament für die spätere Integration dient.

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

## 5. MiniDAW – Zweck und Abnahmekriterium

Die MiniDAW ist **kein neues Endprodukt** und keine verkleinerte Zielversion. Sie ist ein technischer Prüfstand.

Die erste entscheidende Funktionskette lautet:

**App starten → MIDI/Spur/Clip → Instrument-Plugin → Audio → Transport/Playposition**

Ein MiniDAW-Stand ist erst dann als belastbare Grundlage anzusehen, wenn auf dem Zielsystem mindestens nachgewiesen ist:

1. App startet stabil.
2. Eine MIDI-Datei bzw. MIDI-Daten können geladen werden.
3. Spur und Clip werden tatsächlich von der Engine verwaltet.
4. Ein installiertes Instrument-Plugin (VST3 oder AU; z. B. Pianoteq) wird gefunden.
5. Das Instrument kann einer MIDI-Spur zugewiesen und instanziiert werden.
6. Play startet den Transport.
7. Die MIDI-Noten erreichen das Instrument und sind hörbar.
8. Die Playposition läuft sichtbar und synchron mit.
9. Stop/Locate funktionieren reproduzierbar.
10. Wiederholtes Starten, Laden und Abspielen führt nicht zu Abstürzen oder offensichtlich inkonsistentem Zustand.

Erst danach werden weitere DAW-Funktionen auf dieses Fundament gesetzt.

## 6. Verworfene bzw. historische Stände

- Frühere V0.x-Stände waren Entwicklungs- und Integrationsstufen, nicht der aktuelle Ausgangspunkt.
- **V1.0RC:** auf dem MacBook praktisch getestet und als unbrauchbar verworfen.
- Die alte Strategie „den RC durch weitere Klecker-Reparaturen retten“ ist beendet.
- Alte Branches, Artefakte und Chatangaben dürfen nicht automatisch als aktueller Entwicklungsstand interpretiert werden.

Historischer Code darf weiterhin als Quelle für funktionierende Einzelbausteine dienen. Er ist aber nicht automatisch Teil der neuen Basis.

## 7. Entwicklungsregeln

1. **Keine Klecker-Versionen zur Abnahme.** Zwischenstände dürfen intern gebaut werden, werden aber nicht als neue Version an den Anwender herausgegeben.
2. **Build-Erfolg ist nicht gleich Funktionsnachweis.** Automatisierbare Tests werden vor Herausgabe durchgeführt; Hardware-, Audio- und lokale Plugin-Tests werden klar als solche ausgewiesen.
3. **Keine GUI-Neuerfindung.** Der freigegebene Entwurf bleibt das Ziel.
4. **Keine unnötige MAGDA-Modifikation.** Engine-Funktionen werden bevorzugt über eine definierte Bridge genutzt.
5. **Fehler werden nicht durch Attrappen kaschiert.** Ein sichtbarer Button oder eine statische Darstellung zählt nicht als implementierte Funktion.
6. **Funktion vor Umfang.** Erst eine kleine vollständig funktionierende Kette, dann Erweiterung.
7. **GitHub ist das Projektgedächtnis.** Relevante Strategieänderungen, getestete Stände und bekannte Blocker werden hier dokumentiert.
8. **Chats sind nicht verbindlich.** Vor Änderungen am Projekt ist zuerst dieser Status und anschließend der aktuelle Repository-Stand zu prüfen.

## 8. Arbeitsablauf ab jetzt

Vor jeder neuen Entwicklungsarbeit:

1. `PROJECT_STATUS.md` lesen.
2. aktuellen Branch/Commit und relevante Build-Ergebnisse prüfen.
3. nicht aufgrund eines möglicherweise veralteten Chatverlaufs zurückspringen.

Nach jedem wesentlichen Test oder Strategiewechsel:

1. Ergebnis dokumentieren,
2. getesteten Commit/Build eindeutig nennen,
3. funktionierende und nicht funktionierende Punkte trennen,
4. nächsten technischen Schritt festhalten.

## 9. Aktuell nächster Schritt

**MiniDAW kompilieren und auf dem Intel-MacBook praktisch testen.**

Danach wird diese Datei mit dem exakten getesteten Build/Commit, dem Testergebnis und den nachgewiesenen Funktionen aktualisiert. Erst auf Basis dieses Ergebnisses wird entschieden, welcher Funktionsblock als Nächstes hinzukommt.
