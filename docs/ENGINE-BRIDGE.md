# Composition Studio 1.0.59 – Anbindung der zentralen Composition Engine

Die vorhandene `engine-bridge.js` verwendet die **tatsächliche** zentrale Engine
`wibem1/Composition-Engine/composition-engine.js` mit ihren Funktionen
`extractJson()` und `findScore()`.

## Ablauf für neue Kompositionen
REAPER-Lua → KI (ein Aufruf: musikalische Partitur als JSON) → Node.js-Bridge
→ zentrale Composition Engine (JSON-Parsing) → vorhandenes REAPER-CS-MIDI-Importmodul.

Bei eindeutigen Neukompositionsaufträgen ohne ausgewählte MIDI-Items entfällt
der vorgeschaltete Controller. Werden Aufgaben als `NEED_NEW` erkannt, geht
auch dieser Weg über JSON. LilyPond bleibt im Code für Bestands-/Fortsetzungswege
erhalten; die gesamte Engine-Umstellung ist noch nicht abgeschlossen.

## Voraussetzungen unter Windows
Node.js LTS muss installiert und als `node.exe` im PATH erreichbar sein.
Die App lädt bei Bedarf die Engine- und Bridge-Dateien aus den GitHub-Repositories
in `REAPER/CompositionStudioTemp`. Ohne Netzwerk oder Node.js schlägt
die lokale Umsetzung mit einer Fehlermeldung fehl. Eine zusätzliche
kommerzielle API / KI-Übersetzung wird dafür nicht benutzt.

## Aktuelle Grenzen
- Zunächst Neukompositionen, nicht alle Variationen und Fortsetzungen.
- Der gemeinsame Engine-Parser wird verwendet, aber nicht die gesamte
  `CompositionEngine.compose()`-Pipeline, weil diese für manche Formate
  zusätzliche KI-Aufrufe ausführt.
- Unterstützt einfache Tracks und Noten mit Start/Dauer/Pitch/Velocity,
  Program Change, Kanal, Tempo und Taktart.
- Kein automatisches Ergänzen fehlender Takte oder musikalischer Reparaturen.
- Der Adapter verlangt eine installierte Node.js-Laufzeit.
- Die Engine wird bei jedem Aufruf von GitHub geholt; ihre tatsächliche
  Runtime-Version ist aktuell 2.20.1 und kann unabhängig von 1.0.59 wechseln.
- Ein REAPER-Windows-End-to-End-Test ist vor Freigabe als stabil erforderlich.

## Prüfschritte
1. Node.js über PowerShell: `node --version`.
2. Einfache JSON-Probe mit dem Adapter durchführen; dabei muss eine
   `CSMETA`-Zeile und mindestens eine `CS|new`-Zeile entstehen.
3. In REAPER erst dann genau eine kleine KI-Neukomposition testen.
4. Erst nach erfolgreichem Hörtest weitere Bearbeitungswege umstellen.
