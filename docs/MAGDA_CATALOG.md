# MAGDA-Katalog für Composition Studio

**Referenz:** `Conceptual-Machines/magda-core` @ `15e9071d657bf9179432c6a0a3a62f8dd686d8a1` (27.08.2026)

**Ziel dieses Dokuments:** vollständige funktionale Katalogisierung der für MAGDAs Arbeitsweise relevanten Module, ihrer Grenzen, Abhängigkeiten und Datenwege. „Vollständig“ bedeutet hier: alle Hauptsysteme und Engine-Module sind erfasst und in ihrer Rolle eingeordnet. Einzelne Hilfsfunktionen werden bei den späteren Modultests weiter bis auf Implementierungsdetails vertieft.

## 1. Systembild

MAGDA besteht am gepinnten Stand aus fünf großen eigenen Systemen:

1. `magda/daw` – produktive, Tracktion-basierte DAW.
2. `magda/engine` – parallel entwickelte native Audioengine, am gepinnten Stand noch nicht die Produktivengine.
3. `magda/agents` – KI-/Agenten- und Automationssystem.
4. `magda/scripting` – Lua-Laufzeit, Sandbox und MAGDA-API-Bindings.
5. `magda/mcp_bridge` – externer MCP/SSE-Kommunikationsprozess.

Basistechnologien: C++20, JUCE, Tracktion Engine, farbot-Realtime-Primitiven, SoundTouch/Signalsmith für Zeit-/Pitchbearbeitung, Lua, SQLite, juce-llm/llama.cpp sowie weitere optionale Plugin-/ML-Bausteine.

### 1.1 Zwei Engine-Generationen

Der wichtigste Architekturpunkt ist die Koexistenz zweier sehr verschiedener Engines:

**Produktivpfad:**
`MAGDA Modell/Commands → AudioEngine/TracktionEngineWrapper → tracktion::Edit/PlaybackContext → Tracktion DeviceManager → JUCE AudioDeviceManager → CoreAudio`

**Native Neuentwicklung:**
`Modell → RenderPlan/ClipSnapshot/PlanValues/TransportSnapshot → EngineSession → PlanExecutor/EngineDevice → AudioBuffer → Host/AudioDevice`

Die native Engine ist nicht bloß ein anderer Wrapper. Sie trennt Modell, unveränderlichen Renderplan, Runtime-Zustand, Transport, Clipdaten und Realtime-Ausführung systematisch.

---

# TEIL A – PRODUKTIVE TRACKTION-DAW

## 2. `magda/daw/interfaces`

Fachliche Interfaces für `track`, `clip`, `transport`, `mixer`, DAW-Modus und Prompt. Sie sollen die Produktlogik vom Backend trennen, verhindern aber die konkrete Tracktion-/JUCE-Kopplung des zentralen Wrappers nicht.

**Composition Studio:** fachliche Schnittstellen sind sinnvoll; keine Übernahme der konkreten MAGDA-Interfaces.

## 3. `magda/daw/engine`

### 3.1 `AudioEngine`

Zentrale virtuelle Fassade. Verantwortet bzw. exponiert Lifecycle, Edit, Transport, Tempo/Takt, Loop, Metronom, Session-Clips, Audio-/MIDI-Devices, Bridges, Plugin Discovery/Scan, Parameteranalyse, Preview, Recording, Offline Render, Projektmedien und weitere Dienste.

**Befund:** God-Interface. JUCE-Typen sind Bestandteil der öffentlichen API. Es ist keine reine Audio-Hardware-Abstraktion.

### 3.2 `TracktionEngineWrapper`

Konkrete Produktivimplementierung. Erbt gleichzeitig von `AudioEngine`, Track-, Clip-, Transport- und Mixer-Interfaces sowie Tracktion-/JUCE-Listenern. Exponiert `tracktion::Engine*` und `tracktion::Edit*`.

**Rolle:** Orchestrator/Fassade für fast die gesamte DAW. Das erklärt, warum externe Integration schnell zu Trial-and-Error führt: viele scheinbar unabhängige Funktionen hängen am Lebenszyklus desselben Zentralobjekts.

### 3.3 Initialisierung und Ownership

Verifizierte Reihenfolge:

`Behaviour → tracktion::Engine → Config → Controllerprofile → Pluginformate/-liste → DeviceManager → Audio-Konfiguration → MIDI-Geräte → Edit + PlaybackContext → AudioBridge/TempoSync/Session-Dienste → MidiBridge → TransportListener`

Physische Hardware gehört nicht `AudioBridge`, sondern:

`TracktionEngineWrapper → tracktion::Engine → tracktion::DeviceManager → juce::AudioDeviceManager → CoreAudio`.

Ein kritischer Fehler im Design: `initialize()` kann erfolgreich sein, obwohl `getCurrentAudioDevice()` null ist; Erfolg wird im Wesentlichen an einer vorhandenen Edit festgemacht. Daher beweist „Engine initialisiert“ keine funktionsfähige Audiokette.

### 3.4 Device Management

MAGDA validiert persistierten Tracktion-Audiozustand, initialisiert Tracktion mit großzügigen Kanalzahlen, setzt bevorzugte JUCE-Gerätenamen, flusht den JUCE Message Loop, aktiviert Hardwarekanäle und synchronisiert danach Tracktion WaveInput/WaveOutputDevices.

Es existieren damit mehrere Zustandsstufen:

`CoreAudio-Gerät ↔ JUCE Device Setup ↔ Tracktion WaveDevices ↔ PlaybackContext ↔ Edit-Graph`.

Ein Fehler in einer Stufe kann eine scheinbar initialisierte, aber stumme Engine erzeugen.

### 3.5 Shutdown

Abbau in umgekehrter Abhängigkeitsrichtung: Listener/Discovery/Testton → Plugin-/Session-Dienste → MidiBridge-Verknüpfung → AudioBridge → Transport/PlaybackContext → Edit → MIDI-Router/-Inputs → MidiBridge/API → DeviceManager close → Tracktion Engine.

**Lehre:** MAGDA besitzt reale Lifetime-Abhängigkeiten, die durch manuelle Reihenfolge abgesichert werden. Composition Studio soll diese in kleineren RAII-Komponenten ausdrücken.

## 4. `magda/daw/audio`

Kein einzelnes Audio-I/O-Modul, sondern Sammelbereich für mehrere Schichten:

- `AudioBridge` – Synchronisation MAGDA-Modell ↔ Tracktion-Edit.
- `MidiBridge` – MIDI-bezogene Brücke zwischen Modell/Engine.
- `AudioBridgeMixer` – Mixer-bezogene Synchronisation.
- `AudioDriverUtils` – Geräte-/Treiberhilfen.
- `AudioEngineOptimizer` – Engine-/Performance-Hilfen.
- Metering – Pegel-/Messdaten.
- `TrackController` – Track-bezogene Steuerung.
- `PluginWindowBridge` – Plugin-GUI-Brücke.
- Thumbnail/Waveform-Peaks – Darstellungsvorbereitung von Audiodateien.
- Warp/Comping – Audio-Editing-Funktionen.
- ClipCommands – Clipoperationen.

**Befund:** Hardware, Model-Sync, Editing und UI-Hilfen liegen im selben Verzeichnis. Für Composition Studio werden sie getrennt.

## 5. `magda/daw/core`

Große fachliche Domänenschicht. Enthält insbesondere:

- App-/Pfad-/Konfigurationshilfen.
- Automation: Commands, Curve, Info, Manager.
- Clip-Modell und umfangreiche Clip-Verwaltung.
- Chain-/Routing-Strukturen.
- Chord-/musikalische Daten.
- Commands und Manager für DAW-Operationen.
- weitere fachliche Zustände, die nicht direkt Audio-Hardware sind.

**Arbeitsweise:** Die Core-Manager verändern das MAGDA-Modell; Bridges/Wrapper übertragen relevante Änderungen in die Tracktion-Edit. Das Modell und Tracktions Edit sind damit zwei gekoppelte Zustandswelten.

**Risiko:** Synchronisationsfehler sind strukturell möglich. Die native Engine reagiert darauf mit Snapshots/Plans statt fortlaufender Objektspiegelung.

## 6. `magda/daw/api`

Öffentliche/fachliche API-Schicht mit getrennten Headern und `*_live`-Implementierungen, u. a. Alias-, Automation- und Clip-API sowie weitere DAW-Funktionsgruppen.

**Arbeitsweise:** API-Vertrag und Live-Backend sind getrennt. Die Live-Implementierungen vermitteln in das laufende MAGDA-System. Das ist ein brauchbares Muster für Composition Studio: externe KI-/Scripting-Funktionen sollen eine fachliche API sehen, nicht Audio-Engine-Objekte.

## 7. `magda/daw/project`

- `ProjectManager` – Projektlebenszyklus und Koordination.
- `ProjectInfo` – Metadaten.
- `MediaCollector` – Projektmedien sammeln/konsolidieren.
- `serialization/` – Persistenz.

**Composition Studio:** eigenes `ProjectCore`; Projektdatei soll Modellzustand, Pluginzustände, Tempo, Routing und Medienreferenzen speichern, aber Hardwarezustand nicht mit Projektmodell vermischen.

## 8. `magda/daw/cli`

CLI-Frontend (`magda_cli_main.cpp`) als alternativer Zugang zum DAW-System. Für Forschung wichtig, weil Funktionen ohne GUI ansprechbar/testbar werden können.

## 9. `magda/daw/device_packs`

Am gepinnten Stand im Wesentlichen `pro_stub`. Kein Fundament der Audioarchitektur; für Composition Studio zunächst ohne Priorität.

---

# TEIL B – NATIVE MAGDA ENGINE

## 10. Grundprinzip

Die native Engine löst die Kopplungsprobleme des alten Wrappers durch drei Ebenen:

1. **Modell-/Publish-Seite (nicht realtime):** strukturelle Änderungen werden in unveränderliche Renderpläne kompiliert; Clips, Werte und Transport werden als getrennte Snapshots veröffentlicht.
2. **Runtime-Bindings:** langlebige Geräte/Quellen werden über IDs/Keys an Plan-Ops gebunden und können Planwechsel überleben.
3. **Audio-Thread:** verarbeitet nur vorbereitete Daten. Kein Lock, keine Allokation, kein Free im Callback.

Das ist der wichtigste technische Lernstoff für unseren eigenen Core.

## 11. `engine/plan`

Zentrale Bausteine: `PlanCompiler`, Renderplan-/Dump-Strukturen, `PlanDiff`, `PlanCrossfade` und Hilfen.

`PlanCompiler.cpp` ist ein großer Compiler: Das veränderliche DAW-Modell wird in eine ausführbare, immutable Topologie übersetzt. Ein struktureller Edit verändert nicht den laufenden Graphen; er erzeugt einen neuen Plan.

`PlanDiff` identifiziert Unterschiede zwischen alter und neuer Topologie. `PlanCrossfade` unterstützt Übergänge, damit strukturelle Änderungen nicht zwangsläufig klicken.

**Composition Studio:** sehr wertvolles Muster. Nicht MAGDA-Code kopieren, aber „mutable project model → compiled immutable render graph“ als Architekturprinzip prüfen.

## 12. `engine/exec`

### 12.1 `EngineSession`

Die Live-Engine. Sie hält den laufenden vorbereiteten Render-Epoch und tauscht ihn über `farbot::RealtimeObject` aus. Vertrag: ein Audio-Thread, ein Publishing-Thread; parallele Publisher wären ein Race.

Der Audio-Thread darf weder warten noch zerstören. Der Publishing-Thread bereitet einen neuen Epoch vor, veröffentlicht ihn blockgrenzensicher und räumt den alten Epoch außerhalb des Callbacks auf.

Vier Datenarten reisen bewusst getrennt:

- **RenderPlan** – Struktur/Topologie, langsam/human-speed.
- **PlanValues** – Mixer-/Parameterwerte, schneller aktualisierbar.
- **TransportSnapshot** – Tempo, Loop, Metronom, Locate/Play-State.
- **ClipSnapshot** – welche Clips wo spielen; Clipbewegung ist keine Topologieänderung.

`EngineSession::process(numSamples, output)` bekommt vom Host nur die verlangte Blockgröße. Die Session bestimmt anhand des Transports, welche Timeline-Segmente gerendert werden. Ohne Plan liefert sie Stille.

### 12.2 `EngineDevice`

Abstraktion eines vorbereiteten Laufzeitgeräts. `prepare()`/`reset()` laufen off-audio-thread; `process(DeviceBlock&)` läuft realtime.

`DeviceBlock` enthält:

- In-place AudioBlock.
- optional MIDI input/output.
- Sidechain.
- Extra-Ausgänge für Multi-Out-Instrumente.
- bereits aufgelöste Parameterströme.
- Block-/Timeline-Info.

MIDI-Speicher wird vorab budgetiert (`kMaxMidiBytesPerPort`), um Realtime-Allokationen zu vermeiden.

### 12.3 Quellen

`EngineAudioSource` und `EngineMidiSource` sind getrennte Laufzeitquellen hinter Plan-Ops. Der Plan besitzt die konkrete Plugin-/Reader-Instanz nicht; der Host bindet langlebige Runtime-Objekte. Dadurch kann z. B. ein Instrument einen strukturellen Planwechsel überleben.

### 12.4 Executor

`PlanExecutor`, `ParallelPlanExecutor`, `PlanBindings`, `RenderThreadPool`, `RuntimeStateStore` bilden Ausführung und Runtime-Bindings. Parallelisierung ist eine Ausführungsoption, nicht ein anderes Datenmodell.

**Composition Studio:** Graphplanung und Runtime-Geräte strikt trennen; zunächst seriellen Executor bauen, Parallelisierung erst nach funktionaler Korrektheit.

## 13. `engine/transport`

Module: `TransportState`, `TransportClock`, `TempoMap`, `ClickGenerator`.

### 13.1 TransportClock

Der zentrale Taktgeber verbindet Samplezeit und musikalische Beatzeit. Er summiert nicht einfach Blockdauern, sondern verwendet einen Anchor aus Timeline-Position und Samplezähler. Dadurch soll die Position unabhängig von Blockteilung driftfrei bleiben.

Loop-Wraps teilen einen Callback in kontinuierliche Segmente; kein Render-Op sieht einen Block, der mitten drin auf eine andere Timelineposition springt. Die öffentliche Playheadposition wird atomar publiziert.

### 13.2 TempoMap

Verantwortet Beat↔Sekunden-Beziehung über Tempoänderungen. TransportClock erkennt Änderungen über Fingerprint und verankert die Samplezeit neu, ohne den musikalischen Beat zu verlieren.

### 13.3 ClickGenerator

Metronom/Count-in ist ein eigener Renderbaustein und nicht Transportzustand selbst.

**Composition Studio:** TransportCore kann sehr ähnlich getrennt werden: `TempoMap + TransportState + sample-accurate Clock`; Metronom als Consumer.

## 14. `engine/clip`

Verifizierte Kernbausteine:

- `ClipSnapshot` – immutable/resolved Clipzustand für Playback.
- `ClipSnapshotCompiler` – Modell → Playback-Snapshot.
- `ClipSnapshotFeed` – Veröffentlichung an laufende Quellen.
- `ClipAudioSource` – Audio-Clip-Rendering.
- `ClipMidiSource` – MIDI-Clip-Rendering.
- `ActiveNoteList` – MIDI-Notenlebensdauer/aktive Noten.
- weitere Dump-/Hilfs- und Voice-Pool-Komponenten.

**Arbeitsweise:** Clipverschieben ist bewusst keine Graph-/Topologieänderung. Ein neuer ClipSnapshot wird publiziert. Audio-/MIDI-Quellen lesen daraus die für ihren Block relevanten Ereignisse/Placements.

**Composition Studio:** Track/Clip-Modell vom Rendergraph trennen; Clippositionen als leichtgewichtigen Playback-Snapshot behandeln.

## 15. `engine/io`

Bausteine: `AudioFileReader`, `FileAudioSource`, `ClipPlacement`, `PrefetchStream`, `PrefetchThread`, `SourceLoopInfo`.

**Rolle:** Datei-/Streaming-I/O, nicht Audio-Hardware. Prefetch verlagert langsames Dateilesen aus dem Realtime-Pfad. ClipPlacement/LoopInfo übersetzen Arrangementplatzierung in Dateiquellenzugriff.

**Composition Studio:** eigener `MediaIOCore`; Disk-I/O niemals im Audio-Callback.

## 16. `engine/param`

Umfangreiches Parameter-/Modulationssystem. Verifiziert sind u. a. `ModAdsr`, `ModFollower`, `ModLfo`, `ModRandom`, `ModRuntime` sowie Parameterblock-/Resolve-Strukturen.

**Arbeitsweise:** Device-Code erhält nicht Rohmodell + Automation + Modulatoren, sondern bereits aufgelöste Parameterwerte/Streams im `DeviceBlock`. Damit liegen Priorität, Clamp, Quantisierung und Modulationskombination zentral in der Parameterebene.

**Composition Studio:** zunächst einfacher ParameterCore (statischer Wert + Automation), Modulatoren später. Wichtig ist die zentrale Auflösung vor dem Device-Prozess.

## 17. `engine/tap`

- `LevelTap` – Pegelbeobachtung.
- `MidiTap` – MIDI-Beobachtung.
- `SampleRing` – lock-/realtime-taugliche Samplehistorie.
- `ValueTap` – Parameter-/Wertbeobachtung.

**Rolle:** Realtime-Daten kontrolliert für UI/Analyse sichtbar machen, ohne den Audio-Thread an GUI/Model zu koppeln. Pointer-Lifetimes bleiben kritisch; EngineSession dokumentiert, dass ValueTap-Pointer durch Publish invalidiert werden können.

**Composition Studio:** Metering/Monitoring über explizite lockfreie Taps/Snapshots, niemals GUI-Zugriff aus Audio-Callback.

## 18. `engine/analysis`

Am gepinnten Stand `TransientDetector`. Separater Analysebaustein, kein Bestandteil des grundlegenden Live-Audiopfads.

**Composition Studio:** späteres `AnalysisCore`; keine Priorität für Basis-DAW.

---

# TEIL C – KI, SCRIPTING UND EXTERNE STEUERUNG

## 19. `magda/agents`

Großes Agentensystem mit `agent_runtime` sowie spezialisierten Agenten/Executors/Parsern, darunter Automation und Chord-Funktionen. Die Agenten sitzen oberhalb der DAW-Fachfunktionen; sie sind keine Realtime-Audio-Komponenten.

**Architekturlehre:** KI sollte über fachliche Operationen/Commands arbeiten, nicht über direkte Pointer in Tracks, Plugins oder Audioengine. Das passt zum MusicChat-Ziel von Composition Studio.

## 20. `magda/scripting`

- `LuaRuntime` – Lua-Laufzeit.
- `LuaController` – Steuerung/Integration.
- `LuaSandbox` – eingeschränkte Ausführungsumgebung.
- `LuaScriptStore` – Skriptverwaltung.
- `MagdaApiLuaBindings` – umfangreiche Bindings der fachlichen MAGDA-API an Lua.

**Arbeitsweise:** Scripting greift über API-Bindings auf DAW-Funktionen zu. Das bestätigt die sinnvolle Trennung `Automation/Scripting → Domain API → Core`, statt Scripting direkt in Audioobjekte greifen zu lassen.

## 21. `magda/mcp_bridge`

Kleiner separater Prozess/Bereich aus `main.cpp`, `sse_parser.hpp`, CMake. Vermittelt MCP-/SSE-Kommunikation nach außen.

**Composition Studio:** nur Referenz für externe Tool-/Agentenanbindung. MusicChat braucht keine Abhängigkeit des Audio-Cores von MCP.

---

# TEIL D – GESAMTARBEITSWEISE UND ABHÄNGIGKEITEN

## 22. Produktive MAGDA-Arbeitsweise

### Steuerweg
`GUI / CLI / Agent / Lua → DAW API / Commands / Manager → MAGDA Model → AudioBridge/Wrapper → Tracktion Edit`

### Playbackweg
`Tracktion Edit → PlaybackContext/Graph → Plugins/Clips/Mixer → Tracktion DeviceManager → JUCE AudioDeviceManager → CoreAudio`

### Rückmeldeweg
`Tracktion/JUCE Listener + Meter/Bridge → MAGDA State/API → GUI/Agent/Scripting`

**Schwachstelle:** Modell und Tracktion-Edit müssen fortlaufend synchron gehalten werden. Devicezustand und PlaybackContext bilden weitere gekoppelte Zustände.

## 23. Native Arbeitsweise

### Steuerweg
`mutable Model → Compiler → immutable RenderPlan / ClipSnapshot / PlanValues / TransportSnapshot`

### Publishweg
`non-RT publishing thread → prepare/bind → farbot realtime swap`

### Playbackweg
`Audio callback → EngineSession.process → TransportClock segments → Executor → Sources/Devices/Params → output buffer → Host device`

### Beobachtung
`Audio thread → Taps/atomare Zustände → UI/Analyse`

**Stärke:** Realtime-Pfad arbeitet auf vorbereiteten immutable Daten und langlebigen Runtime-Objekten; strukturelle Änderungen werden außerhalb des Callbacks kompiliert.

## 24. Threadmodell

Mindestens folgende Klassen von Threads sind architektonisch relevant:

- JUCE Message/Control Thread für Device-/GUI-nahe Operationen.
- Audio callback thread: keine Locks, Allokationen, Datei- oder GUI-Arbeit.
- Publishing/Model thread der nativen Engine: Plan/Snapshot vorbereiten und austauschen.
- RenderThreadPool für optionale parallele Graphausführung.
- PrefetchThread für Datei-I/O.
- Plugin-Discovery/Scan-Prozess bzw. Thread.
- Agent-/LLM-/Scripting-Arbeit außerhalb Realtime.

**Composition Studio:** diese Grenzen werden explizit Teil der Core-Verträge.

## 25. Fremdbibliothek oder MAGDA-Idee?

| Funktion | primäre Herkunft im Produktivsystem | unsere Richtung |
|---|---|---|
| Audio-Hardware/CoreAudio | JUCE über Tracktion | JUCE direkt |
| Track-/Plugin-Playbackgraph | Tracktion | eigener kleiner Graph, JUCE Devices |
| Pluginformate/Instantiation | JUCE/Tracktion-Wrapper | JUCE direkt prüfen |
| DAW Edit-Modell | Tracktion + MAGDA Sync | eigenes Modell |
| Commands/Domain API | MAGDA | eigene API |
| Projektverwaltung | MAGDA + Tracktion | eigenes Format |
| Native RenderPlan | MAGDA-eigene Architektur | Prinzip studieren, unabhängig implementieren |
| TransportClock | MAGDA-eigene native Architektur | Prinzip studieren, unabhängig implementieren |
| ClipSnapshot | MAGDA-eigene native Architektur | Prinzip studieren, unabhängig implementieren |
| Parameter/Modulation | MAGDA-eigene native Architektur | vereinfachtes eigenes System |
| Agenten | MAGDA | eigenes MusicChat-Konzept |
| Lua/MCP | MAGDA + Fremdlibs | optional/später |

---

# TEIL E – COMPOSITION STUDIO CORE

## 26. Zielmodule

1. `AudioDeviceCore` – JUCE/CoreAudio, Geräte, Callback, Kanalsetup, Status/Fehler.
2. `TransportCore` – TempoMap, Play/Stop/Locate/Loop, samplegenaue Clock.
3. `ProjectModel` – Tracks, Clips, Routing, Tempo, Metadaten; keine Hardwareobjekte.
4. `MidiCore` – Events, Import/Export, realtime MIDI, aktive Noten.
5. `MediaIOCore` – Audiofile lesen, Prefetch, später Warp.
6. `PluginHost` – Scan/Registry getrennt von Instantiation/Processing/Editor.
7. `AudioGraphCore` – vorbereiteter Rendergraph; zuerst seriell.
8. `MixerCore` – Gain/Pan/Mute/Solo/Inserts/Routing.
9. `ParameterCore` – Werte/Automation, später Modulation.
10. `ProjectCore` – Laden/Speichern/Medien/Pluginstate.
11. `RecordingCore` – Audio/MIDI Recording.
12. `RenderCore` – Offline Export.
13. `MonitoringCore` – Meter/Taps/Diagnose.
14. `AnalysisCore` – Transienten und spätere Analyse.
15. `MusicChat/Domain API` – KI greift ausschließlich über fachliche Commands auf das Modell zu.

## 27. Was wir ausdrücklich nicht übernehmen

- keinen `AudioEngine`-God-Wrapper;
- keine dauerhafte MAGDA-Abhängigkeit;
- keine zwingende Tracktion-Abhängigkeit;
- keine Doppelhaltung MAGDA-Modell ↔ Tracktion-Edit;
- keine stille Initialisierung bei fehlendem Audiogerät;
- keine Plugin-Discovery oder GUI im DeviceCore;
- keine Datei-/LLM-Arbeit im Realtime-Pfad;
- keine unstrukturierten Fehler nur als DBG-Log.

## 28. Testreihenfolge

Jedes Modul wird isoliert verstanden und getestet, bevor Integration erfolgt:

`AudioDevice → Transport → MIDI → Track/Clip Model → PluginHost → AudioGraph → Mixer/Routing → Project → Automation/Params → Recording/Render → Monitoring/Analysis → MusicChat`.

Für Hardware-/Pluginfunktionen gilt zusätzlich ein realer Intel-Mac-Test. Build-Erfolg ist nur Build-Nachweis.

## 29. Erster Prüfstand: AudioDeviceCore

Muss ohne MAGDA, Tracktion, Track, Clip und Plugin nachweisen: Geräteauflistung → tatsächliches Öffnen → Name/Samplerate/Buffer/Kanäle → Callbackzähler → direkt erzeugter begrenzter Testton → gemessene Sampleenergie → hörbarer Ausgang → sauberer Stop → strukturierte Fehler.

Erst danach wird der nächste Layer aufgesetzt.

---

# TEIL F – KATALOGSTATUS

## 30. Abdeckung

**Vollständig auf System-/Modulebene katalogisiert:**

- produktive DAW-Gesamtarchitektur;
- Engine-/Device-/Edit-Lifecycle;
- Audio-/MIDI-Brücken als Rolle;
- Core/Domain, API, Project, CLI, Device Packs;
- native Engine mit `analysis`, `clip`, `exec`, `io`, `param`, `plan`, `tap`, `transport`;
- Agenten;
- Lua/Scripting;
- MCP Bridge;
- wesentliche Daten-, Ownership- und Threadwege;
- Trennung MAGDA-eigen / JUCE / Tracktion;
- Ableitung der Composition-Studio-Core-Module.

**Bewusst noch nicht als „implementierungsverifiziert“ markiert:** jede einzelne Methode jeder großen Manager-/Compilerdatei. Das ist Gegenstand der nun folgenden Modultests. Der Katalog ist damit als Landkarte abgeschlossen; die nächste Forschungsphase ist die sequenzielle Tiefenprüfung der einzelnen Bausteine.

## 31. Zentrale Schlussfolgerung

MAGDA ist für uns vor allem in zwei Hinsichten wertvoll:

1. Die produktive Tracktion-Architektur zeigt sehr deutlich, **welche Kopplungen wir vermeiden sollten**.
2. Die native Engine zeigt mehrere starke Lösungsprinzipien – immutable Renderpläne, getrennte Snapshots, Runtime-Bindings, samplegenauen Transport, Realtime-Publish und Taps –, die wir verstehen und anschließend **eigenständig und kleiner** für Composition Studio umsetzen können.

Das langfristige Ziel bleibt deshalb: MAGDA als Referenz und Testvergleich, nicht als Fundament. Composition Studio soll auf einem eigenen, modularen Core stehen.
