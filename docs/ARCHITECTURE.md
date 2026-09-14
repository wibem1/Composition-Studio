# Composition Studio – Architektur

## Ziel

Composition Studio ist eine eigenständige macOS-Anwendung mit eigener Oberfläche und eigener KI-Schicht. MAGDA wird als technische Basis für Audio, MIDI, Plugin-Hosting und Projektfunktionen genutzt, nicht als sichtbare Anwendung.

## Drei Schichten

### 1. MAGDA Engine

MAGDA liefert technische Grundfunktionen:

- Audio-Engine
- MIDI
- Transport
- Plugin-Hosting
- Track- und Clip-Funktionen
- Routing
- Projektzustand

Die MAGDA-Oberfläche wird nicht als Composition-Studio-GUI weiterentwickelt. Änderungen an MAGDA sollen auf das notwendige Minimum beschränkt bleiben.

### 2. CompositionStudioCore / EngineBridge

Zwischen MAGDA und der App liegt eine kleine, ausdrücklich definierte C/C++-Schnittstelle.

Regel: Die Swift-Oberfläche greift nie direkt auf MAGDA-Interna zu.

Die Bridge wird funktionsweise erweitert. Jede neue Funktion muss über eine kleine, testbare API sichtbar werden.

Reihenfolge:

1. Initialisierung und Transport
2. Projekt laden/speichern
3. Tracks anlegen, entfernen und auswählen
4. MIDI-Clips importieren, erzeugen, verschieben und exportieren
5. Instrumente und Plugins laden
6. Routing und Audio-I/O
7. Arrangement- und Editor-Funktionen
8. Notation/MusicXML

### 3. Composition Studio App

Die macOS-App enthält:

- das freigegebene Composition-Studio-GUI
- Arrangement
- Browser
- Inspector
- Editor/Notation
- KI-Dialog
- Composition-Workflow

Die App kommuniziert ausschließlich mit CompositionStudioCore/EngineBridge.

## Entwicklungsregel

Es gibt nur einen nativen Haupt-Build. Frühere parallele Wege – vollständiges MAGDA-GUI umbenennen/theme-patchen einerseits und eigene Swift-App andererseits – werden nicht parallel weitergeführt.

Ein Build gilt nur dann als neuer Entwicklungsstand, wenn er ein klar definiertes Nutzungspaket ergänzt. Reine Zwischenstände mit nur einem zusätzlichen sichtbaren Knopf werden nicht als Benutzer-Testversion behandelt.

## Etappen

### V0.6 – technischer Kern

- App startet zuverlässig
- Engine initialisiert
- Play/Pause/Stop
- Position und Tempo
- Projekt laden/speichern
- ein eindeutiger nativer Build

### V0.7 – MIDI-Arbeitsstand

- Tracks
- MIDI-Clips
- MIDI-Import/Export
- grundlegende Clip-Bearbeitung

### V0.8 – Instrumente und Plugins

- Plugin-Liste
- Instrument laden
- Effekt laden
- Routing

### V0.9 – Arrangement

- Clips verschieben/duplizieren/löschen
- Spurverwaltung
- Editor/Pianoroll

### V1.0 – erste gebrauchsfähige Studio-Version

- vollständiger Basis-Workflow von Projektstart bis Speichern
- stabile Audio/MIDI-Wiedergabe
- Instrumente/Plugins
- Arrangement
- erster sinnvoller KI-Kompositionsworkflow

## Build-Prinzipien

- MAGDA-Version ist fest gepinnt.
- Keine rekursive Initialisierung unnötiger Unter-Submodule.
- Keine zweite konkurrierende native Build-Pipeline.
- Versionsnummer kommt aus `native/upstream.env` und wird für App und Artefakt verwendet.
- CI baut nur die Composition-Studio-App plus benötigte Engine-Komponenten.
- Fehlgeschlagene Engine-Integration wird im Build sichtbar und nicht durch Fallback-GUIs kaschiert.
