# MAGDA-Katalog für Composition Studio

**Untersuchter Referenzstand:** `Conceptual-Machines/magda-core` commit `15e9071d657bf9179432c6a0a3a62f8dd686d8a1` (27.08.2026)

**Zweck:** MAGDA wird als Forschungs- und Referenzsystem untersucht. Dieser Katalog soll das System so weit zerlegen, dass jeder für Composition Studio relevante Baustein verstanden, isoliert getestet und anschließend bewusst ersetzt, vereinfacht oder nur als Referenz verwendet werden kann.

## 1. Erste Gesamtarchitektur

Der MAGDA-Quellbaum gliedert sich auf oberster Ebene in fünf eigene Bereiche:

- `magda/agents` – Agent-/KI-System.
- `magda/daw` – bestehende DAW-Anwendung und die gegenwärtig von Composition Studio verwendete Tracktion-basierte Engine-Schicht.
- `magda/engine` – neue native Engine; laut Build-Konfiguration derzeit bewusst „dark“: wird gebaut und getestet, aber nicht in die App gelinkt.
- `magda/mcp_bridge` – MCP-Anbindung.
- `magda/scripting` – Lua-/Scripting-System.

Wichtige Fremd-/Basistechnologien laut Root-CMake: JUCE als direkte First-Class-Abhängigkeit, Tracktion Engine für DAW-Funktionalität, SoundTouch und Signalsmith Stretch für Time-Stretching, juce-llm, llama.cpp, Lua, SQLite und optional ONNX Runtime/CLAP. Das ist für unsere Strategie entscheidend: Nicht alles, was über MAGDA erreichbar ist, ist MAGDA-eigene Engine-Logik.

## 2. `magda/daw` – bestehendes DAW-System

Erste Unterteilung des Quellbaums:

- `api` – externe/programmatische DAW-API.
- `audio` – Audio-/MIDI-Brücken, Device-/Metering-/Plugin-nahe Funktionen.
- `cli` – Kommandozeilenfunktionen.
- `core` – umfangreiches DAW-Daten-, Manager-, Command- und Zustandsmodell.
- `device_packs` – interne/optionale Devices.
- `engine` – Tracktion-basierter Engine-Adapter und Plugin/Transport/Recording-Funktionen.
- `interfaces` – abstrakte Schnittstellen für Clip, Track, Transport, Mixer und DAW-Modus.
- weitere UI-/Projekt-/Anwendungsbereiche werden in der nächsten Inventurrunde vollständig ergänzt.

### 2.1 `magda/daw/interfaces`

Kleine, wichtige Abstraktionsschicht mit:

- `clip_interface.hpp`
- `track_interface.hpp`
- `transport_interface.hpp`
- `mixer_interface.hpp`
- `daw_mode_interface.hpp`
- `prompt_interface.hpp`

**Forschungswert:** hoch. Diese Interfaces zeigen, welche fachlichen Operationen MAGDA selbst als Engine-Grenze betrachtet. Sie sind aber nicht automatisch unsere zukünftige API; wir prüfen sie gegen die Bedürfnisse von Composition Studio.

### 2.2 `magda/daw/engine` – Tracktion-Adapter

Zentrale Dateien:

- `AudioEngine.hpp` – abstrakte Engine-Basis.
- `TracktionEngineWrapper.hpp/.cpp` – zentrale Tracktion-Implementierung.
- `TracktionEngineWrapperInit.cpp` – Initialisierung/Device-/Engine-Lebenszyklus.
- `TracktionEngineWrapperTransport.cpp` – Transport/Timing.
- `TracktionEngineWrapperTracks.cpp` – Tracks.
- `TracktionEngineWrapperClips.cpp` – Clips.
- `TracktionEngineWrapperDevices.cpp` – Devices.
- `TracktionEngineWrapperPlugins.cpp` – Plugin-Funktionen.
- `TracktionEngineWrapperRecording.cpp` – Recording.
- `PluginScanner`, `PluginScanCoordinator`, `ScanWorker` – Plugin-Erkennung/Scan.
- `PluginMetadataStore` – Plugin-Metadaten.
- `PluginWindowManager` – Plugin-Fenster.
- `PlaybackPositionTimer` – Positionsaktualisierung.
- `TempoLaneBridge`, `TempoLaneSync`, `TracktionTempoMap` – Tempo-/Map-Anbindung.
- `OfflineRenderHelper` – Offline-Rendering.

**Erste Bewertung:** Dies ist keine eigenständige MAGDA-Audioengine, sondern eine umfangreiche Adapter-/Orchestrierungsschicht um Tracktion Engine plus JUCE. Genau hier müssen wir bei Audio, Transport, Tracks, Clips und Plugins trennen, welche Funktion MAGDA ergänzt und welche Tracktion direkt liefert.

### 2.3 `magda/daw/audio`

Bereits identifizierte Bausteine:

- `AudioBridge` – große Audio-Brückenschicht.
- `MidiBridge` – MIDI-Brücke.
- `AudioBridgeMixer` – Mixer-Anbindung.
- `TrackController` – Track-nahe Steuerung.
- `DeviceMeteringManager`, `MeteringBuffer` – Pegel/Metering.
- `PluginWindowBridge` – Plugin-UI-Brücke.
- `AudioThumbnailManager`, `WaveformPeakCache` – Wellenform/Thumbnail/Peak-Cache.
- `WarpMarkerManager` – Warp-Marker.
- `CompService` – Comping-bezogene Dienste.
- `ClipCommands` – umfangreiche Clip-Operationen.
- Analyse-Unterbereich mit Audio-Tap/Spektrum usw.

**Erste Bewertung:** Der Name `audio` ist breiter als reine Audio-I/O. Dieser Bereich mischt Adapter, Controller, Metering, Clip-Operationen und Darstellungshilfen. Für den eigenen Core sollten diese Verantwortlichkeiten stärker getrennt werden.

### 2.4 `magda/daw/core`

Sehr großer fachlicher Bereich. Bereits im Quellbaum sichtbar:

- `ClipManager` mit sehr großer Implementierung sowie `ClipInfo`, `ClipOperations`, `ClipCommands`, Fades, Occlusion, Lanes usw.
- Automation: `AutomationManager`, `AutomationCommands`, `AutomationCurve`, `AutomationInfo`, State/Types.
- Routing-/Chain-Modelle: `ChainNode`, `ChainNodePath`, `ChainRoutingModel`, Fingerprints.
- Konfiguration/AppPaths.
- Chord-/Progression-bezogene Daten/Commands.
- weitere Track-, Device-, Projekt-, Editier- und Managerstrukturen werden noch vollständig katalogisiert.

**Erste Bewertung:** Hier steckt viel MAGDA-eigene Produktlogik. Gleichzeitig sind mehrere Manager sehr groß. Für Composition Studio ist zu prüfen, welche Teilmodelle wirklich gebraucht werden und welche durch kleinere, testbare Core-Objekte ersetzt werden können.

## 3. `magda/engine` – native Engine

Dieser Bereich ist für unsere neue Strategie besonders interessant. MAGDAs Root-CMake beschreibt `MAGDA_BUILD_NATIVE_ENGINE` ausdrücklich als **native engine**, die derzeit gebaut und getestet, aber nicht in die App gelinkt wird.

Im Quellbaum sind bereits eigenständige Engine-Bausteine sichtbar:

- `clip/ClipAudioSource`
- `clip/ClipMidiSource`
- `clip/ClipSnapshot` und Compiler/Feed
- `clip/MidiClipCompiler`, `MidiEventList`, `ActiveNoteList`
- `clip/ClipVoice`, `ClipVoicePool`
- `clip/EventPlacement`
- `clip/WarpMap`, `ClipStretcher`, Fade/Groove-Funktionen
- `exec/EngineSession`, `EngineDevice`, Offline-Render-Komponenten
- `analysis/TransientDetector`

**Forschungswert: sehr hoch.** Dieser Code zeigt, wie die MAGDA-Entwicklung selbst versucht, sich von Tracktion als Engine zu lösen. Wir dürfen ihn nicht blind übernehmen, aber er ist möglicherweise die wertvollste Referenz für unseren eigenen Composition Studio Core. Er wird getrennt von der Tracktion-basierten `magda/daw/engine` untersucht.

## 4. Vorläufige Modulkarte für Composition Studio

| Forschungsmodul | MAGDA-Referenzbereiche | Haupt-Fremdabhängigkeit | Ziel im Composition Studio |
|---|---|---|---|
| Audio-I/O | `daw/engine/*Init*`, `daw/audio/AudioBridge*` | JUCE + Tracktion | eigener `AudioCore` |
| Transport/Timing | `daw/engine/*Transport*`, Tempo-Klassen | Tracktion/JUCE | eigener `TransportCore` |
| MIDI | `daw/audio/MidiBridge*`, `engine/clip/*Midi*` | JUCE/Tracktion | eigener `MidiCore` |
| Tracks | `daw/core`, `daw/engine/*Tracks*` | Tracktion | eigener Track-Kern |
| Clips | `daw/core/Clip*`, `daw/engine/*Clips*`, `engine/clip` | Tracktion + native MAGDA | eigener `TrackClipCore` |
| Plugins | Scanner/Wrapper/Devices/Window | JUCE + Tracktion | eigener `PluginHost` |
| Mixer/Routing | Interfaces, ChainRouting, AudioBridgeMixer | Tracktion | eigener `MixerCore` |
| Projekt/Persistenz | noch vollständig zu kartieren | JUCE ValueTree/Tracktion | eigenes Projektformat |
| Automation | `daw/core/Automation*` | Tracktion/ValueTree | später eigener Teilkern |
| Recording | `TracktionEngineWrapperRecording` | Tracktion/JUCE | später eigener Recording-Core |
| Stretch/Warp | `engine/clip`, `daw/audio/Warp*` | SoundTouch/Signalsmith | gezielte Bibliotheksnutzung prüfen |
| AI/Scripting | `agents`, `scripting`, `mcp_bridge` | LLM/Lua/MCP | getrennt vom Audio-Core bewerten |

## 5. Untersuchungsmethode pro Modul

Für jedes Modul werden nacheinander dokumentiert:

1. Dateien/Klassen und öffentliche API.
2. Besitzer des Zustands und Objektlebenszeiten.
3. Initialisierung und Shutdown.
4. Datenfluss und Kontrollfluss.
5. Thread-/Realtime-Anforderungen.
6. MAGDA-interne Abhängigkeiten.
7. JUCE-/Tracktion-/sonstige Fremdanteile.
8. bekannte Fehler- und Grenzfälle.
9. isolierter Test.
10. Ergebnis auf dem Intel-Mac, falls Hardware/Plugins nötig sind.
11. Entscheidung für Composition Studio.

## 6. Nächste Inventurschritte

- vollständige Dateigruppen von `daw/core`, `daw/audio`, `daw/engine`, Projekt/Persistenz, UI, agents, scripting und MCP erfassen;
- zentrale Header/Implementierungen lesen, nicht nur Dateinamen;
- Initialisierungspfad von App → Engine → DeviceManager → Edit/Session verfolgen;
- Tracktion- und JUCE-Grenzen markieren;
- native `magda/engine` Architektur separat kartieren;
- danach Test 1: Audio-I/O als isoliertes Forschungsmodul.

Dieser Katalog ist absichtlich ein wachsendes Forschungsdokument. Aussagen werden mit fortschreitender Codeanalyse von „erste Bewertung“ zu „verifiziert“ hochgestuft.
