# MAGDA-Katalog für Composition Studio

**Untersuchter Referenzstand:** `Conceptual-Machines/magda-core` commit `15e9071d657bf9179432c6a0a3a62f8dd686d8a1` (27.08.2026)

**Zweck:** MAGDA wird als Forschungs- und Referenzsystem untersucht. Dieser Katalog zerlegt das System so weit, dass jeder für Composition Studio relevante Baustein verstanden, isoliert getestet und anschließend bewusst ersetzt, vereinfacht oder nur als Referenz verwendet werden kann.

## 1. Gesamtarchitektur

Der MAGDA-Quellbaum gliedert sich auf oberster Ebene in fünf eigene Bereiche: `magda/agents`, `magda/daw`, `magda/engine`, `magda/mcp_bridge`, `magda/scripting`.

Wichtige Basistechnologien sind JUCE, Tracktion Engine, SoundTouch, Signalsmith Stretch, juce-llm, llama.cpp, Lua und SQLite. Für Composition Studio wird deshalb bei jedem Baustein getrennt: MAGDA-eigene Produktlogik, Fremdbibliotheksfunktion und reine Adapter-/Orchestrierungslogik.

## 2. `magda/daw` – bestehendes DAW-System

### 2.1 Fachliche Interfaces

`daw/interfaces` definiert Clip-, Track-, Transport-, Mixer-, DAW-Mode- und Prompt-Grenzen. Sie zeigen MAGDAs gedachte fachliche Grenzen, werden aber nicht automatisch zur Composition-Studio-Core-API.

### 2.2 `AudioEngine` – verifizierte Produktionsengine-Grenze

`AudioEngine` bündelt Lifecycle, Transport, Session-Clips, Tempo/Takt, Loop, Metronom, Device Management, AudioBridge, MidiBridge, Plugin Discovery, Pluginparameter, Offline Rendering, Projektmedien, MIDI Preview und Recording Preview.

**Diagnose:** faktisch ein DAW-Service-Facade/God-Interface. JUCE-Typen (`AudioDeviceManager`, `BigInteger`, `PluginDescription`, `File`, `String`) treten direkt in der öffentlichen API auf. Tracktion wird teilweise abstrahiert, JUCE nicht.

**Composition-Studio-Regel:** AudioDevice, Transport, Session, PluginHost, Render und Projektservices werden getrennte Core-Module.

### 2.3 `TracktionEngineWrapper` – verifizierte Mehrfachrolle

Der Wrapper erbt gleichzeitig von `AudioEngine`, `TransportInterface`, `TrackInterface`, `ClipInterface`, `MixerInterface`, `tracktion::TransportControl::Listener` und `juce::ChangeListener`. Zusätzlich exponiert er direkt `tracktion::Engine*` und `tracktion::Edit*`.

**Diagnose:** Die Interface-Grenzen verhindern keine starke konkrete Kopplung. Für Composition Studio entsteht kein vergleichbares Zentralobjekt.

## 3. Audio-I/O Deep Dive

### 3.1 Tatsächliche Ownership-Kette

Die physische Audio-Hardware gehört **nicht** dem `AudioBridge`. Die verifizierte Kette lautet:

`TracktionEngineWrapper` → besitzt `tracktion::Engine` → dessen `tracktion::DeviceManager` → dessen `juce::AudioDeviceManager` → CoreAudio-Gerät auf macOS.

Erst nach Engine-, Device- und Edit-Erzeugung wird `AudioBridge` konstruiert. Er synchronisiert MAGDA-Zustand mit Tracktion und ist keine Hardware-Abstraktion.

### 3.2 Verifizierte Initialisierungsreihenfolge

`TracktionEngineWrapper::initialize()` arbeitet in dieser Reihenfolge:

1. `MagdaUIBehaviour` und `MagdaEngineBehaviour` erzeugen.
2. `tracktion::Engine` erzeugen.
3. MAGDA `Config` laden.
4. Controllerprofile laden.
5. Pluginformate initialisieren und gespeicherte Pluginliste laden/bereinigen.
6. Im Nicht-Headless-Betrieb `initializeDeviceManager()`.
7. Danach `configureAudioDevices()`.
8. Danach `setupMidiDevices()`.
9. `createEditAndBridges()`.
10. Falls der asynchrone Device-Callback nicht kam, `devicesLoading_` zwangsweise auf false setzen.
11. Erfolg wird ausschließlich daran gemessen, ob `currentEdit_ != nullptr` ist.

**Kritischer Befund:** `initialize()` kann `true` liefern, obwohl kein Audio-Gerät geöffnet wurde. `initializeDeviceManager()` loggt ein fehlendes Gerät nur als Warnung. Damit bedeutet **Engine initialisiert nicht Audio funktionsfähig**. Das ist für unseren fehlgeschlagenen MiniDAW-Test besonders relevant: ein erfolgreicher Build und sogar ein erfolgreiches `initialize()` beweisen keine hörbare Audiokette.

### 3.3 Device-Initialisierung

`initializeDeviceManager()`:

- fragt alle JUCE AudioDeviceTypes und Geräte ab;
- validiert Tracktions persistierten Device-Zustand;
- entfernt einen halb gesetzten Input-/Output-Zustand, weil dieser laut MAGDA-Kommentar CoreAudio beim Öffnen eines unvollständigen Aggregate-Setups blockieren kann;
- fordert bei Tracktion bis zu 256 Input- und 256 Output-Kanäle an; JUCE begrenzt auf Hardware;
- akzeptiert anschließend ausdrücklich den Zustand `getCurrentAudioDevice() == nullptr` und loggt nur eine Warnung.

### 3.4 Bevorzugtes Gerät / Kanalaktivierung

`configureAudioDevices()` liest MAGDAs gespeicherte Input-/Output-Präferenzen. Es verwendet den ersten verfügbaren JUCE DeviceType (auf macOS erwartbar CoreAudio), scannt Geräte und setzt gefundene Namen über `juce::AudioDeviceManager::setAudioDeviceSetup()`.

Danach wird der JUCE Message Loop mit `runDispatchLoopUntil(0)` geflusht. Anschließend aktiviert MAGDA explizit alle Hardwarekanäle auf JUCE-Ebene und danach gespeicherte Kanalzahlen auf Tracktions WaveInput-/WaveOutputDevices.

**Threadregel:** Device-Konfiguration und Rescan hängen am JUCE Message/Control Thread und dürfen nicht als Realtime-Audio-Operation behandelt werden.

### 3.5 Device-Wechsel und Rescan

`TracktionEngineWrapperDevices.cpp` bestätigt einen zweiten Synchronisationslayer:

- JUCE meldet Device-Änderungen über Tracktions DeviceManager/ChangeBroadcaster.
- MAGDA vergleicht Gerätename und Anzahl der MIDI-/Wave-Geräte.
- Bei Hardwarewechsel werden JUCE Input-/Output-Kanäle neu gesetzt.
- Danach wird der Tracktion Playback Context mit `ctx->reallocate()` neu aufgebaut.
- `rescanWaveDevices()` ruft Tracktions `rescanWaveDeviceList()`, flusht erneut den JUCE Message Loop und aktiviert anschließend Tracktion WaveDevices.

Damit existieren mindestens drei Zustände, die konsistent gehalten werden müssen: physisches/JUCE-Gerät, Tracktion WaveDevices und Edit Playback Context.

### 3.6 Semantik von `setEnabledWaveChannels`

Die Methode arbeitet nicht kanalgenau auf Tracktion-Ebene: Ein Tracktion WaveDevice wird aktiviert, sobald **mindestens einer** seiner Kanäle in der übergebenen Bitmaske gesetzt ist. `getEnabledWaveChannels()` liefert umgekehrt alle Kanäle eines aktivierten WaveDevice als gesetzt.

**Konsequenz:** Diese API ist eher eine WaveDevice-Aktivierungsfassade mit Kanalmaske als ein präziser per-channel Router. Für Composition Studio müssen physische Kanalwahl und logisches Routing getrennt modelliert werden.

### 3.7 Edit und Playback Context

`createEditAndBridges()`:

- erzeugt eine temporäre `.tracktionedit`;
- setzt 120 BPM;
- ruft `ensureContextAllocated()` für Live-MIDI/Playback auf;
- akzeptiert auch hier einen weiterhin nullen Playback Context zunächst nur mit Warnlog;
- erzeugt anschließend `AudioBridge`, TempoLaneSync sowie im GUI-Betrieb SessionScheduler, SessionRecorder, PluginWindowManager und InsertRenderCapture;
- erzeugt danach `MidiBridge` und registriert den Wrapper als TransportListener.

Damit hängt die hörbare Wiedergabe nicht nur am geöffneten Hardwaregerät, sondern zusätzlich an einem gültigen Tracktion Playback Context und dessen Graph/Routing.

### 3.8 Verifizierte Shutdown-Reihenfolge

Der Shutdown ist auffallend streng und zeigt die tatsächlichen Lebenszeitabhängigkeiten:

1. `aliveFlag_` deaktivieren und Plugin-Discovery-Thread joinen.
2. Testton-Plugin freigeben.
3. TransportListener und DeviceManager-Listener entfernen.
4. Pluginfenster schließen und Raw-Pointer im AudioBridge lösen.
5. InsertRenderCapture und TempoLaneSync zerstören.
6. SessionScheduler zerstören.
7. ProjectManager-Callbacks entfernen.
8. MidiBridge vom AudioBridge lösen.
9. **AudioBridge zerstören, solange Edit und Engine noch leben.**
10. Transport stoppen und **Playback Context freigeben**.
11. Edit zerstören.
12. MIDI Learn/ControllerRouter stoppen; MIDI-Inputs stoppen; MidiBridge zerstören.
13. MagdaApi zerstören.
14. Tracktion DeviceManager `closeDevices()`.
15. Tracktion Engine zerstören.

**Ownership-Regel:** Bridge/Session/Plugin-Dienste referenzieren langlebigere Engine-/Edit-Objekte. Playback Context muss vor Edit und Hardware-Devices freigegeben werden. MIDI-Callbacks müssen beendet werden, solange die MIDI-Geräte noch existieren.

**Composition-Studio-Regel:** Diese Abhängigkeiten sollen in RAII-Komponenten mit kleinerem Scope und expliziten Start/Stop-Zuständen abgebildet werden, nicht in einem langen manuellen Zentral-Shutdown.

### 3.9 Fehlerbild der MiniDAW – neue Hypothesen, noch nicht als Ursache bewiesen

Der Praxistest „App startet, kein Ton“ passt zu mehreren vom MAGDA-Code zugelassenen Zuständen:

- kein `currentAudioDevice`, aber `initialize()` trotzdem erfolgreich;
- JUCE-Gerät offen, Tracktion WaveOutputDevice aber nicht wirksam aktiviert;
- WaveDevices vorhanden, Playback Context jedoch nicht korrekt/allokiert;
- Playback Context vorhanden, aber Instrument-/Track-Graph liefert kein Audio;
- Plugin/MIDI-Seite funktioniert nicht, obwohl Hardwareseite offen ist.

Diese Punkte sind **Diagnosehypothesen**, keine nachträgliche Behauptung über die konkrete Ursache. Der neue AudioDeviceCore-Test muss sie einzeln messbar machen.

## 4. `daw/audio`

Enthält u. a. `AudioBridge`, `MidiBridge`, `AudioBridgeMixer`, `AudioDriverUtils`, `AudioEngineOptimizer`, Metering, TrackController, PluginWindowBridge, Waveform/Thumbnail, Warp, Comping und ClipCommands.

**Bewertung:** Der Bereich mischt Hardware-nahe Hilfen, Engine-Brücken, fachliche Controller und UI-nahe Daten. Composition Studio trennt diese Verantwortlichkeiten.

## 5. `daw/project`

Hauptbausteine: `ProjectManager`, `ProjectInfo`, `MediaCollector`, `serialization/`. Projekt/Persistenz bleibt ein eigenes Core-Modul.

## 6. `daw/core`

Großer fachlicher Bereich mit Automation-, Clip-, Routing-, Command- und Managerlogik. Vollständige Klassengruppierung folgt nach den fundamentalen Enginepfaden.

## 7. `magda/engine` – native Engine als getrenntes Forschungsobjekt

Top-Level: `analysis`, `clip`, `exec`, `io`, `param`, `plan`, `tap`, `transport`.

### 7.1 `engine/io`

Verifizierte Bausteine umfassen `AudioFileReader`, `FileAudioSource`, `ClipPlacement`, `PrefetchStream`, `PrefetchThread`, `SourceLoopInfo`. Dieses Modul ist Datei-/Streaming-I/O, nicht Hardware-Device-I/O.

### 7.2 `engine/exec`

Verifizierte Bausteine: `EngineDevice`, `EngineSession`, `OfflineRender`, `PlanExecutor`, `ParallelPlanExecutor`, `PlanBindings`.

Die native Engine trennt Ausführungsplanung und Session deutlich stärker von Datei-I/O und Clip-Modell. Diese Trennung wird als Architekturreferenz untersucht, nicht übernommen.

## 8. Composition-Studio-Core – Modulkarte

| Zielmodul | MAGDA-Referenz | Fremdbasis | Entscheidung |
|---|---|---|---|
| `AudioDeviceCore` | Wrapper Init/Devices | JUCE/CoreAudio | **direkt klein selbst entwickeln; MAGDA nur Referenz** |
| `AudioGraphCore` | native `engine/exec`, Tracktion Playback Context | JUCE/eigene Logik | unabhängig entwerfen |
| `TransportCore` | alter Wrapper + `engine/transport` | eigene Timinglogik/JUCE | separat neu entwerfen |
| `MidiCore` | MidiBridge + native MIDI | JUCE | unabhängig entwerfen |
| `TrackCore` | daw/core + WrapperTracks | möglichst wenig Tracktion | eigenes Datenmodell |
| `ClipCore` | daw/core/Clip + native engine/clip | JUCE/Stretch | eigenes Modell |
| `PluginHost` | PluginManager/Scanner/Devices/Window | JUCE AudioProcessor | JUCE-direkten Weg prüfen |
| `MixerCore` | MixerInterface/ChainRouting | eigene Graphlogik | eigenes Modul |
| `ProjectCore` | daw/project | JUCE/Standardformate | eigenes Format |
| `AutomationCore` | Automation* + engine/param | eigene Logik | später eigenständig |
| `RecordingCore` | WrapperRecording/SessionRecorder | JUCE | später eigenständig |
| `RenderCore` | OfflineRender alt/native | JUCE | getrennt von Live Device Core |
| `AI/MusicChat` | agents/scripting/MCP | LLM APIs | außerhalb Realtime-Core |

## 9. Spezifikation des ersten isolierten `AudioDeviceCore`-Tests

Der Test darf noch keine Tracks, Clips, Plugins, MAGDA oder Tracktion benötigen. Er muss auf dem Intel-Mac einzeln nachweisen:

1. JUCE/CoreAudio initialisiert.
2. verfügbare Output-Geräte werden aufgelistet.
3. Default/gewähltes Output-Gerät wird tatsächlich geöffnet.
4. Name, Sample-Rate, Buffergröße und aktive Outputkanäle werden angezeigt.
5. ein eigener minimaler Audio-Callback läuft und zählt Callback-Blöcke.
6. Callback schreibt einen einfachen, pegelbegrenzten Testton direkt auf Output 1/2.
7. Peak/RMS bzw. erzeugte Sample-Energie wird diagnostisch gemessen.
8. Stop entfernt Callback und schließt Gerät sauber.
9. jeder Fehler liefert einen strukturierten Status statt nur Logtext.

**Abnahmekriterium:** Build-Erfolg reicht nicht. Der Test gilt erst als bestanden, wenn der Intel-Mac ein reales Gerät meldet, Callback-Aktivität nachweist und der Testton hörbar ist. Erst danach darf Plugin-/Track-/Transportlogik auf diese Schicht gesetzt werden.

## 10. Architekturregeln

1. Kein God-Interface nach Art von `AudioEngine`.
2. Physische Audio-Hardware ist ein eigenes Modul.
3. Message/Control Thread und Realtime Audio Thread haben explizite Grenzen.
4. Track/Clip-Projektzustand gehört nicht dem Hardwareobjekt.
5. Plugin-Scan/Fenster gehören nicht in AudioDeviceCore.
6. Fehler werden strukturiert zurückgegeben.
7. Fremdtypen werden nur bewusst Teil öffentlicher Core-APIs.
8. Hardware-unabhängige und Hardware-Mac-Tests werden getrennt dokumentiert.
9. Ein erfolgreicher Engine-Init darf niemals stillschweigend „Audio funktioniert“ bedeuten.

## 11. Nächste Deep Dives

1. Callback-/Audio-Graph-Weg Tracktion Playback Context → Hardware verfolgen.
2. Native `EngineSession`/`EngineDevice` vollständig lesen und mit Tracktion vergleichen.
3. Transport alt vs. native kartieren.
4. Track/Clip-Modell und Ownership kartieren.
5. Plugin-Hosting getrennt von Plugin-Scanning analysieren.
6. Danach isolierten `AudioDeviceCore`-Test implementieren.

Aussagen werden als inventarisiert, verifiziert oder offen behandelt; Dateinamen allein gelten nicht als Verständnisnachweis.
