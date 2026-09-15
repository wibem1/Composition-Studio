# Composition Studio – Forschungsjournal

Dieses Dokument ist das chronologische Laborbuch. Auch Fehlversuche und widerlegte Annahmen werden festgehalten.

## 2026-09-15 – Strategiewechsel: MAGDA vom Fundament zum Forschungsobjekt

Die Entwicklung über `Composition Studio → EngineBridge → MAGDA` führte bei einfachen Funktionen wiederholt zu Trial-and-Error an MAGDA-/JUCE-/Tracktion-Grenzen. V1.0RC war praktisch nicht brauchbar; der MiniDAW-Prüfstand blieb trotz erfolgreichem Build im lokalen Test stumm.

**Entscheidung:** MAGDA ist Referenz, nicht langfristiges Fundament. Ziel ist ein eigener modularer Composition Studio Core. Ein Modul gilt erst als beherrscht, wenn API, Implementierung, Zustand, Lifetime, Threads, Datenfluss, Abhängigkeiten und Fehlerpfade verstanden und testbar sind.

---

## 2026-09-15 – Inventurrunden 1–2: Produktionsengine und Audio

Untersuchungsbasis ist exakt MAGDA `15e9071d657bf9179432c6a0a3a62f8dd686d8a1`.

Befunde:

- fünf Hauptsysteme: `daw`, native `engine`, `agents`, `scripting`, `mcp_bridge`;
- produktive DAW ist Tracktion-basiert;
- `AudioEngine` ist eine breite DAW-Fassade, kein kleines Audiointerface;
- `TracktionEngineWrapper` bündelt Engine, Transport, Track, Clip, Mixer und Listener;
- Hardware gehört nicht AudioBridge, sondern Tracktion DeviceManager/JUCE AudioDeviceManager/CoreAudio;
- Device-Konfiguration benötigt Message-Thread-Verarbeitung;
- mehrere Fehlerpfade werden nur geloggt;
- Engine-Init kann erfolgreich erscheinen, obwohl kein physisches Audiogerät offen ist;
- native Engine ist bereits deutlich stärker modularisiert.

Diese Befunde führten zur Entscheidung, `AudioDeviceCore` direkt über JUCE/CoreAudio und unabhängig von MAGDA/Tracktion zu testen.

---

## 2026-09-15 – Inventurrunde 3: vollständige System-/Modullandkarte

### Fragestellung

Welche funktionalen Module enthält MAGDA insgesamt, wie arbeiten die produktive und die native Engine, und welche Teile sind MAGDA-eigene Architektur gegenüber JUCE/Tracktion-Funktionalität?

### Untersuchte Bereiche

- `magda/daw`: `interfaces`, `engine`, `audio`, `core`, `api`, `project`, `cli`, `device_packs`.
- `magda/engine`: `analysis`, `clip`, `exec`, `io`, `param`, `plan`, `tap`, `transport`.
- `magda/agents`.
- `magda/scripting`.
- `magda/mcp_bridge`.
- Schlüsselquellen: `EngineSession.hpp`, `EngineDevice.hpp`, `TransportClock.hpp` sowie die bereits untersuchten Tracktion-Wrapper-Dateien.

### Befund A – MAGDA enthält zwei verschiedene Engine-Architekturen

Die Produktivengine hält MAGDA-Modell und Tracktion-Edit synchron und hängt für Playback an Tracktions PlaybackContext/DeviceManager. Die native Engine verwendet dagegen vorbereitete unveränderliche Renderpläne und getrennte Snapshots.

### Befund B – native Engine arbeitet mit Publish statt Objektspiegelung

`EngineSession` trennt RenderPlan, PlanValues, TransportSnapshot und ClipSnapshot. Strukturelle Änderungen werden off-audio-thread kompiliert und als neuer vorbereiteter Epoch publiziert. Der Audio-Thread wartet, allokiert und zerstört nicht. Runtime-Objekte können einen Planwechsel überleben.

### Befund C – Geräte und Plan sind getrennt

`EngineDevice` definiert die Runtime-Schnittstelle für Audio/MIDI-Geräte. Der Renderplan besitzt kein Pluginobjekt. Der Host bindet langlebige Devices/Sources an Plan-Identitäten. `prepare/reset` laufen außerhalb des Audio-Threads, `process` realtime.

### Befund D – Transport ist samplebasiert und driftarm konstruiert

`TransportClock` verbindet Samplezähler und Beatposition über einen Anchor. Loop-Wraps schneiden Callbacks in kontinuierliche Segmente. Eine Blockteilung darf dadurch die resultierende Timelineposition nicht verändern. Playheadzustand wird atomar publiziert.

### Befund E – Clipänderungen sind keine Graphänderungen

`ClipSnapshot`/`ClipSnapshotCompiler` lösen Arrangementzustand separat vom Renderplan auf. Ein verschobener Clip benötigt keinen kompletten Graph-Neubau. Audio-/MIDI-Clipquellen lesen den publizierten Snapshot.

### Befund F – Datei-I/O ist vom Realtime-Pfad getrennt

`engine/io` besitzt Reader, FileAudioSource, PrefetchStream/-Thread und Placement-/Loop-Daten. Langsames Dateilesen wird vorgepuffert und gehört nicht in den Callback.

### Befund G – Parameter werden vor dem Device zentral aufgelöst

`engine/param` enthält Automation-/Modulationsruntime einschließlich ADSR, Follower, LFO und Random. `DeviceBlock` liefert dem Device bereits aufgelöste Parameterströme. Device-Code muss nicht selbst Stored Value, Automation und Modulatoren zusammenführen.

### Befund H – Taps sind die Beobachtungsgrenze

`LevelTap`, `MidiTap`, `SampleRing`, `ValueTap` transportieren Realtime-Daten kontrolliert Richtung UI/Analyse. Das vermeidet GUI-Zugriffe aus dem Audio-Thread, verlangt aber klare Lifetime-Regeln.

### Befund I – KI/Scripting liegt oberhalb der Domain-API

Agents und Lua-Bindings arbeiten auf fachlichen Operationen. `mcp_bridge` ist ein separater Kommunikationsbaustein. Keines dieser Systeme sollte Teil des Realtime-Audio-Cores sein.

### Ergebnis

Die System-/Modullandkarte ist in `docs/MAGDA_CATALOG.md` abgeschlossen. Sie unterscheidet Produktiv-Tracktion-Pfad, native Engine, Domain/API, Projekt, Agenten, Scripting und MCP und leitet daraus 15 eigene Composition-Studio-Core-Module ab.

**Commit:** `13b2ec08ad08627cb297fdfd57a0524b5fafdcf0`.

### Nächste Forschungsphase

Die Katalogisierung ist als Landkarte abgeschlossen. Nun folgt keine weitere breite Inventur, sondern sequenzielle Implementierungsprüfung und Modultest in dieser Reihenfolge:

`AudioDevice → Transport → MIDI → Track/Clip → PluginHost → AudioGraph → Mixer/Routing → Project → Parameter/Automation → Recording/Render → Monitoring/Analysis → MusicChat`.

Jeder Schritt erhält einen isolierten Test. Ein Haken bedeutet nicht „kompiliert“, sondern „verstanden, reproduzierbar getestet und Fehler lokalisierbar“.
