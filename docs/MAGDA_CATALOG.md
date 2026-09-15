# MAGDA-Katalog für Composition Studio

**Untersuchter Referenzstand:** `Conceptual-Machines/magda-core` commit `15e9071d657bf9179432c6a0a3a62f8dd686d8a1` (27.08.2026)

**Zweck:** MAGDA wird als Forschungs- und Referenzsystem untersucht. Dieser Katalog zerlegt das System so weit, dass jeder für Composition Studio relevante Baustein verstanden, isoliert getestet und anschließend bewusst ersetzt, vereinfacht oder nur als Referenz verwendet werden kann.

## 1. Gesamtarchitektur

Der MAGDA-Quellbaum gliedert sich auf oberster Ebene in fünf eigene Bereiche:

- `magda/agents` – Agent-/KI-System.
- `magda/daw` – bestehende DAW-Anwendung und Tracktion-basierte Produktionsengine.
- `magda/engine` – parallel entwickelte native Engine.
- `magda/mcp_bridge` – MCP-Anbindung.
- `magda/scripting` – Lua-/Scripting-System.

Wichtige Basistechnologien sind JUCE, Tracktion Engine, SoundTouch, Signalsmith Stretch, juce-llm, llama.cpp, Lua und SQLite. Für Composition Studio wird deshalb bei jedem Baustein getrennt: MAGDA-eigene Produktlogik, Fremdbibliotheksfunktion und reine Adapter-/Orchestrierungslogik.

## 2. `magda/daw` – bestehendes DAW-System

Unterbereiche: `api`, `audio`, `cli`, `core`, `device_packs`, `engine`, `interfaces`, Projekt- und UI-Bereiche sowie zentrale Commands.

### 2.1 `daw/interfaces` – fachliche Grenzflächen

Dateien: `clip_interface.hpp`, `track_interface.hpp`, `transport_interface.hpp`, `mixer_interface.hpp`, `daw_mode_interface.hpp`, `prompt_interface.hpp`.

**Status:** inventarisiert. Diese Interfaces zeigen MAGDAs gedachte fachliche Grenzen, werden aber nicht automatisch zur Composition-Studio-Core-API.

### 2.2 `daw/engine/AudioEngine.hpp` – verifizierte Produktionsengine-Grenze

`AudioEngine` ist nicht nur eine Audio-I/O-Abstraktion. Die Klasse bündelt mindestens folgende Verantwortlichkeiten in einer einzigen virtuellen Schnittstelle:

- Lifecycle: `initialize`, `shutdown`, Edit-Zustand und Edit-Datei.
- Transport: Play/Stop/Pause/Record/Locate, Positionsabfrage, Session-Clip-Zustände und audio-thread-synchronisierte Transportposition.
- Tempo/Takt/TempoMap.
- Loop, Metronom, Count-in.
- Device Management über einen direkt herausgegebenen `juce::AudioDeviceManager*`, Wave-Channel-Aktivierung und Device-Rescan.
- Zugriff auf `AudioBridge` und `MidiBridge`.
- Anwendungsspezifische Dienste (`MagdaApi`, Plugin-Fenster, Insert-Render-Capture).
- Plugin Discovery, Scan, Exclusions und Parameteranalyse.
- Groove Templates.
- Offline Rendering.
- Projektmedien und Tempo-Ripple-Commands.
- MIDI Preview und Recording Preview.

**Architekturdiagnose:** `AudioEngine` ist faktisch ein DAW-Service-Facade/God-Interface und keine schmale Audioengine-Grenze. Das ist für Composition Studio ausdrücklich kein Vorbild. Der eigene Core sollte AudioDevice, Transport, Session, PluginHost, Render und Projektservices in getrennte Module zerlegen.

**Wichtige Kopplung:** Obwohl die Klasse abstrakt ist, erscheinen JUCE-Typen direkt in der öffentlichen API (`AudioDeviceManager`, `BigInteger`, `PluginDescription`, `File`, `String`). Die Abstraktion trennt damit Tracktion teilweise, aber nicht JUCE.

### 2.3 `TracktionEngineWrapper` – verifizierte Mehrfachrolle

`TracktionEngineWrapper` erbt gleichzeitig von:

- `AudioEngine`
- `TransportInterface`
- `TrackInterface`
- `ClipInterface`
- `MixerInterface`
- `tracktion::TransportControl::Listener`
- `juce::ChangeListener`

Damit ist die zentrale Produktionsklasse zugleich Engine, Transportadapter, Track-/Clip-/Mixer-Fassade und Listener für Tracktion/JUCE. Sie exponiert zusätzlich direkt `tracktion::Engine*` und `tracktion::Edit*`.

**Konsequenz:** Die scheinbaren Interface-Grenzen verhindern keine starke konkrete Kopplung. Für Composition Studio soll kein vergleichbares Zentralobjekt entstehen. Ownership und Lebenszyklen werden in kleinere Core-Komponenten zerlegt.

### 2.4 `TracktionEngineWrapperInit.cpp` – Initialisierungspfad, verifiziert

Der Initialisierungscode zeigt den tatsächlichen Audio-/DAW-Lebenszyklus:

1. `createDefaultAudioEngine()` erzeugt konkret einen `TracktionEngineWrapper` und setzt optional Headless-Betrieb.
2. Pluginformate werden über Tracktions PluginManager registriert; Scan läuft laut Code in separatem Prozess. Persistierte Pluginliste wird geladen und bereinigt.
3. Audio-Hardware läuft über `engine_->getDeviceManager()` und dessen eingebetteten JUCE `deviceManager`.
4. Vor Device-Initialisierung wird gespeicherter Tracktion-Audiozustand validiert. Ein halb konfigurierter gespeicherter Input-/Output-Zustand wird entfernt, weil er laut Kommentar CoreAudio beim Öffnen eines unvollständigen Aggregate-Setups blockieren kann.
5. Tracktion DeviceManager wird mit bis zu 256 angeforderten Ein- und Ausgangskanälen initialisiert; JUCE begrenzt auf die reale Hardware.
6. Bevorzugte Geräte werden aus MAGDAs `Config` gelesen, dann über `juce::AudioDeviceManager::setAudioDeviceSetup()` gesetzt.
7. Nach einem Device-Wechsel werden alle real vorhandenen Hardwarekanäle explizit aktiviert; danach werden MAGDAs gespeicherte Kanalpräferenzen auf Tracktions WaveInput-/WaveOutputDevices angewendet.
8. MIDI-Geräte werden zunächst auf JUCE-Ebene aktiviert, anschließend lässt MAGDA Tracktion die MIDI-Liste neu scannen und aktiviert Tracktion-MIDI-Inputs.
9. `createEditAndBridges()` erzeugt eine temporäre Tracktion-Edit-Datei, setzt Defaulttempo 120 BPM und erzwingt einen Playback Context.
10. Danach entstehen `AudioBridge`, `TempoLaneSync` und im Nicht-Headless-Betrieb Session-Scheduler, Session-Recorder und PluginWindowManager.

**Ownership, soweit verifiziert:** `TracktionEngineWrapper` besitzt Tracktion Engine/Edit und mehrere Bridge-/Serviceobjekte über Member/`unique_ptr`; `AudioBridge` erhält Referenzen auf Engine und Edit. Damit muss Edit/Engine die Bridge überleben. Die genaue Shutdown-Reihenfolge wird separat verifiziert.

**Thread-/Message-Loop-Hinweis:** Device-Setup ruft explizit `juce::MessageManager::runDispatchLoopUntil(0)` auf, um asynchrone Device-/Wave-Rescans zu flushen. Audio-Device-Konfiguration ist damit nicht als beliebig thread-neutrale Core-Operation zu betrachten. Für unseren `AudioCore` brauchen wir eine klar definierte Control-/Message-Thread-Grenze.

**Fehlerpfade:** Mehrere Device-Fehler werden nur geloggt (`DBG`) und nicht als strukturierte Fehler an den Aufrufer propagiert. `initializeDeviceManager()` kann ohne geöffnetes Gerät weiterlaufen. `configureAudioDevices()` kann bei fehlendem Gerät/Typ oder ungültiger Präferenz still zurückkehren. Das ist für einen robusten Composition-Studio-Core zu schwach; dort sollen Device-Operationen explizite Status-/Fehlerobjekte liefern.

### 2.5 Audio-I/O: wichtige Trennung

Die bisherige Analyse korrigiert eine mögliche Fehlannahme: `magda/daw/audio/AudioBridge` ist **nicht** der Besitzer der physischen Audio-Hardware. Die Hardware wird im Tracktion/JUCE-DeviceManager initialisiert. `AudioBridge` wird erst nach Erzeugung der Tracktion-Edit angelegt und dient vor allem der Synchronisation/Brücke zwischen MAGDA-Zustand und Tracktion-Edit.

Für Composition Studio ergibt sich daher als erstes eigenes Zielmodul:

`AudioDeviceCore (JUCE/CoreAudio) → Audio callback / engine endpoint`

und nicht eine Nachbildung von MAGDAs `AudioBridge`.

### 2.6 `daw/audio`

Enthält u. a. `AudioBridge`, `MidiBridge`, `AudioBridgeMixer`, `AudioDriverUtils`, `AudioEngineOptimizer`, Metering, TrackController, PluginWindowBridge, AudioThumbnail/Waveform-Peak, Warp, Comping und ClipCommands.

**Bewertung:** Der Bereich mischt Hardware-nahe Hilfen, Engine-Brücken, fachliche Controller und UI-nahe Daten. Composition Studio trennt diese Verantwortlichkeiten.

### 2.7 `daw/project`

Verifizierte Hauptbausteine:

- `ProjectManager.hpp/.cpp` – umfangreiche Projektverwaltung.
- `ProjectInfo.hpp` – Projektmetadaten.
- `MediaCollector.hpp/.cpp` – Projektmedien sammeln/konsolidieren.
- `serialization/` – eigene Serialisierungsschicht.

**Forschungsentscheidung:** Projekt/Persistenz bleibt ein eigenes Modul und wird nicht in AudioEngine/Track-Modell versteckt. Deep Dive folgt nach Audio/Transport/Track-Clip-Grundlagen.

### 2.8 `daw/core`

Großer fachlicher Bereich mit u. a. AppPaths, AutomationCommands/-Curve/-Info/-Manager, Clip-/Routing-/Command-/Managerlogik. Schon die Dateigrößen zeigen mehrere umfangreiche Manager (z. B. AutomationManager). Die vollständige Klassengruppierung wird weitergeführt.

## 3. `magda/engine` – native Engine als getrenntes Forschungsobjekt

Top-Level-Module des gepinnten Stands sind verifiziert:

- `analysis`
- `clip`
- `exec`
- `io`
- `param`
- `plan`
- `tap`
- `transport`

Diese Architektur ist deutlich modularer als der alte `TracktionEngineWrapper` und deshalb als Referenz besonders interessant.

### 3.1 `engine/io`

Verifizierte Dateien umfassen:

- `AudioFileReader`
- `FileAudioSource`
- `ClipPlacement`
- `PrefetchStream`
- `PrefetchThread`
- `SourceLoopInfo`

**Wichtige Abgrenzung:** Dieses `io`-Modul ist primär Datei-/Streaming-I/O, nicht das physische Audio-Device-Management. Es löst damit eine andere Aufgabe als unser geplantes `AudioDeviceCore`.

### 3.2 `engine/exec`

Verifizierte Bausteine:

- `EngineDevice`
- `EngineSession`
- `OfflineRender`
- `PlanExecutor`
- `ParallelPlanExecutor`
- `PlanBindings`

Die native Engine trennt Ausführungsplanung und Session wesentlich stärker von Datei-I/O und Clip-Modell. Das ist ein wichtiges Architekturmotiv für Composition Studio: Datenmodell/Planung/Realtime-Ausführung nicht in einem zentralen Wrapper vermischen.

## 4. Composition-Studio-Core – aktualisierte Modulkarte

| Zielmodul | MAGDA-Referenz | Fremdbasis | aktuelle Entscheidung |
|---|---|---|---|
| `AudioDeviceCore` | `TracktionEngineWrapperInit`, Tracktion DeviceManager | JUCE/CoreAudio | **direkt und klein selbst entwickeln; MAGDA nur Referenz** |
| `AudioGraph/ExecutionCore` | `magda/engine/exec`, Tracktion Playback Context | JUCE + eigene Logik | native MAGDA-Architektur studieren, unabhängig entwerfen |
| `TransportCore` | `daw/engine/*Transport*`, `engine/transport` | JUCE/eigene Timinglogik | separat analysieren/neu entwerfen |
| `MidiCore` | `daw/audio/MidiBridge`, native Clip-MIDI | JUCE | unabhängig entwerfen |
| `TrackCore` | `daw/core`, `*Tracks*` | möglichst wenig Tracktion | eigenes Datenmodell |
| `ClipCore` | `daw/core/Clip*`, `*Clips*`, `engine/clip` | JUCE + Stretch libs | eigenes Modell, native Engine als Referenz |
| `PluginHost` | PluginManager/Scanner/Devices/Window | JUCE AudioProcessor/Formats | JUCE-direkten Weg prüfen |
| `MixerCore` | MixerInterface, ChainRouting, AudioBridgeMixer | eigene Graphlogik/JUCE | eigenes Modul |
| `ProjectCore` | `daw/project`, serialization | JUCE/Standardformate | eigenes Projektformat |
| `AutomationCore` | `daw/core/Automation*`, `engine/param` | eigene Logik | später eigenständig |
| `RecordingCore` | WrapperRecording, SessionRecorder | JUCE/AudioDeviceCore | später eigenständig |
| `RenderCore` | OfflineRender alt + native | JUCE | separat von Live-Device-Core |
| `AI/MusicChat` | agents/scripting/MCP | LLM APIs | strikt außerhalb Realtime-Audio-Core |

## 5. Architekturregeln, die sich bereits aus der MAGDA-Analyse ergeben

1. Kein neues God-Interface nach Art von `AudioEngine`.
2. Physische Audio-Hardware ist ein eigenes Modul.
3. Device-Control/Message-Thread und Realtime-Audio-Thread erhalten explizite Grenzen.
4. Track/Clip-Projektzustand wird nicht vom Hardware-Device-Objekt besessen.
5. Plugin-Scan und Plugin-Fenster gehören nicht in die AudioDevice-Schnittstelle.
6. Fehler werden strukturiert zurückgegeben, nicht nur geloggt.
7. Fremdtypen dürfen intern verwendet werden, sollen aber nur bewusst Teil öffentlicher Core-APIs werden.
8. Hardware-unabhängige Tests und Hardware-Mac-Tests werden getrennt dokumentiert.

## 6. Untersuchungsmethode pro Modul

Für jedes Modul: Dateien/Klassen/API → Ownership/Lebenszeiten → Init/Shutdown → Daten-/Kontrollfluss → Threads/Realtime → interne und externe Abhängigkeiten → Fehlerfälle → isolierter Test → Intel-Mac-Test falls nötig → Composition-Studio-Entscheidung.

## 7. Nächste konkrete Deep Dives

1. Audio-I/O abschließen: `initialize()`/`shutdown()`, Device-Rescan, Channel Enable, Callback-/Threadweg und Fehlerfälle vollständig verfolgen.
2. Native `EngineSession`/`EngineDevice` lesen und gegen Tracktion-Playback-Context vergleichen.
3. Transport alt vs. native Engine kartieren.
4. Track/Clip-Datenmodell und Ownership kartieren.
5. Plugin-Hosting getrennt von Plugin-Scanning analysieren.
6. Erst danach isolierten `AudioDeviceCore`-Prototyp/Test für Composition Studio erstellen.

Aussagen werden im Katalog als inventarisiert, verifiziert oder noch offen behandelt; Dateinamen allein gelten nicht als Verständnisnachweis.
