# Composition Studio – verbindlicher Projektstatus

**Stand:** 15. September 2026 – MAGDA-Systemkatalog abgeschlossen; Beginn der sequenziellen Modultests

> GitHub ist die technische Wahrheit. Bei Widersprüchen mit Chats oder älteren Notizen gilt der aktuelle Repository-Stand.

## 1. Aktive Strategie

Die frühere Zielarchitektur `Composition Studio → EngineBridge → MAGDA` ist aufgegeben.

Langfristiges Ziel:

`Composition Studio → Composition Studio Core → gezielt gewählte Basistechnologien`

MAGDA dient als Forschungsobjekt, Referenzimplementierung und technische Anregung. Langfristig soll möglichst wenig oder kein MAGDA-Code im Composition-Studio-Core verbleiben. Die Basis-DAW wird Integrationslabor der eigenen Core-Module.

## 2. Forschungsbasis und Dokumente

Untersuchter MAGDA-Stand: `15e9071d657bf9179432c6a0a3a62f8dd686d8a1`.

- `AGENTS.md` – verbindliche Arbeits-/Forschungsregeln.
- `docs/RESEARCH_ROADMAP.md` – Forschungs-/Entwicklungs-To-do.
- `docs/MAGDA_CATALOG.md` – abgeschlossene System-/Modullandkarte, anschließend fortlaufende Implementierungsdetails.
- `docs/RESEARCH_JOURNAL.md` – chronologisches Laborbuch inklusive Fehlversuchen.

## 3. MAGDA-Katalog – Abschluss der breiten Inventur

Die vollständige funktionale Systemlandkarte ist erstellt. Erfasst sind:

- produktive Tracktion-DAW: Interfaces, Engine/Wrapper, Audio-/MIDI-Bridges, Core/Domain, API, Project, CLI, Device Packs;
- native Engine: `analysis`, `clip`, `exec`, `io`, `param`, `plan`, `tap`, `transport`;
- Agentensystem;
- Lua/Scripting;
- MCP Bridge;
- Audio-/Playback-, Steuer-, Publish- und Beobachtungsdatenwege;
- Ownership-/Lifetime- und wesentliche Threadgrenzen;
- Trennung MAGDA-eigener Architektur von JUCE-/Tracktion-Funktionalität;
- Ableitung der Composition-Studio-Core-Module.

Wesentliche Architekturdiagnose: MAGDA besitzt am gepinnten Stand zwei Engine-Generationen. Die produktive Tracktion-Architektur arbeitet mit gekoppelt synchronisierten Zuständen (MAGDA-Modell, Tracktion Edit, PlaybackContext, DeviceManager). Die native Engine arbeitet dagegen mit immutable RenderPlan sowie getrennten PlanValues-, Transport- und Clip-Snapshots, Runtime-Bindings und Realtime-Publish.

Die **breite Katalogisierung ist abgeschlossen**. „Abgeschlossen“ bedeutet nicht, dass jede Methode jeder großen Managerdatei bereits einzeln getestet wurde. Diese Tiefenprüfung erfolgt jetzt modulweise und wird jeweils in Katalog und Journal ergänzt.

Katalog-Abschlusscommit: `13b2ec08ad08627cb297fdfd57a0524b5fafdcf0`.
Forschungsjournal dazu: `7e822d3e58a48efa68ce2efbcacbd4de83216c1a`.

## 4. Qualitätskriterium „Modul beherrscht“

Ein Modul gilt erst als beherrscht, wenn API, innere Implementierung, Zustände/Lebenszeiten, Abhängigkeiten, Daten-/Kontrollfluss und Thread-/Realtime-Anforderungen verstanden sind, ein reproduzierbarer isolierter Test existiert und Fehler im betreffenden Code lokalisierbar sind.

Build-Erfolg, technisches Verständnis und praktischer Funktionsnachweis bleiben getrennte Kategorien.

## 5. MiniDAW – Referenzstand und negativer Praxistest

Branch: `minidaw-proof-v1-final`.
Commit: `6719a88dedb7f67f9db8cd14320b901353a12832`.
Workflow Run 6: `34984103280` – **SUCCESS**.
Artefakt: `MiniDAW-Proof-Intel`, Artifact ID `10403543590`, 26,788,915 Bytes, SHA-256 `84471dbceef3d2a12a36070c5252d53051139bb80828190a5b76e52d7cf32e01`.

**Lokaler Praxistest:** negativ – kein Ton. Damit ist MiniDAW trotz erfolgreichem Build **nicht funktional nachgewiesen**. Dieser Fehler wird nicht durch blindes Weiterpatchen der MAGDA-Integration verfolgt, sondern durch isolierte Prüfung der Audiokette.

Die MAGDA-Analyse hat dazu einen wichtigen möglichen Fehlerraum identifiziert: MAGDAs Produktivengine kann Initialisierung fortsetzen, obwohl kein aktuelles AudioDevice geöffnet ist; außerdem müssen JUCE-Gerät, Tracktion WaveDevices und PlaybackContext konsistent sein. Das ist noch keine bewiesene Einzelursache des MiniDAW-Fehlers.

## 6. Abgeleitete Composition-Studio-Core-Module

`AudioDeviceCore`, `TransportCore`, `ProjectModel`, `MidiCore`, `MediaIOCore`, `PluginHost`, `AudioGraphCore`, `MixerCore`, `ParameterCore`, `ProjectCore`, `RecordingCore`, `RenderCore`, `MonitoringCore`, `AnalysisCore`, `MusicChat/Domain API`.

Grundregel: kleine explizite Module statt eines `AudioEngine`-God-Interfaces; keine dauerhafte Doppelhaltung eines eigenen Modells und einer Tracktion-Edit.

## 7. Verbindliches GUI-Ziel

Der freigegebene helle Composition-Studio-GUI-Entwurf bleibt unverändert das visuelle Ziel: hell, freundlich, kontrastreich, klar gegliedert; Branding **COMPOSITION STUDIO by Klangwerke**. Forschungs-/Testoberflächen sind keine GUI-Neuentwürfe.

## 8. Aktuelle Phase

Die breite MAGDA-Inventur ist beendet. Jetzt beginnt die sequenzielle Tiefenprüfung:

`AudioDevice → Transport → MIDI → Track/Clip → PluginHost → AudioGraph → Mixer/Routing → Project → Parameter/Automation → Recording/Render → Monitoring/Analysis → MusicChat`.

Erstes Ziel ist ein isolierter `AudioDeviceCore`-Prüfstand ohne MAGDA, Tracktion, Tracks, Clips oder Plugins: CoreAudio/JUCE-Gerät tatsächlich öffnen, Deviceparameter und aktive Kanäle melden, Callbackaktivität messen, begrenzten Testton direkt ausgeben, Sampleenergie diagnostizieren, sauber stoppen und Fehler strukturiert melden. Erst ein hörbarer Intel-Mac-Test schließt dieses Modul praktisch ab.
