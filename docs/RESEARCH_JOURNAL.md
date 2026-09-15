# Composition Studio – Forschungsjournal

Dieses Dokument ist das chronologische Laborbuch. Auch Fehlversuche und widerlegte Annahmen werden festgehalten.

## 2026-09-15 – Strategiewechsel: MAGDA vom Fundament zum Forschungsobjekt

### Ausgangslage

Die Entwicklung über `Composition Studio → EngineBridge → MAGDA` führte bei selbst einfachen Funktionen wiederholt zu Trial-and-Error an MAGDA-/JUCE-/Tracktion-Grenzen. Der V1.0RC war im Praxistest nicht brauchbar. Die MiniDAW wurde deshalb als kleiner technischer Prüfstand aufgebaut.

### Entscheidung

MAGDA wird nicht mehr als langfristig unverzichtbare Engine betrachtet. Es wird systematisch analysiert und als Referenz verwendet. Ziel ist ein eigener modularer Composition Studio Core. Langfristig soll möglichst wenig oder kein MAGDA-Code im Produkt verbleiben.

### Qualitätsziel

Ein MAGDA-Modul gilt nicht als verstanden, weil wir eine aufrufbare Funktion gefunden haben. Wir müssen äußere API, innere Implementierung, Zustand, Lebenszeit, Threads, Datenfluss, Abhängigkeiten und Fehlerfälle so weit beherrschen, dass wir einen Fehler im Originalcode lokalisieren und bei Bedarf gezielt korrigieren könnten.

---

## 2026-09-15 – Inventurrunde 1

### Forschungsbasis

Untersucht wird exakt der von Composition Studio gepinnte MAGDA-Commit `15e9071d657bf9179432c6a0a3a62f8dd686d8a1`.

### Befunde

- MAGDA enthält getrennte Systeme `agents`, `daw`, `engine`, `mcp_bridge`, `scripting`.
- `magda/daw/engine` ist stark Tracktion-basiert.
- Daneben existiert `magda/engine` als native Engine-Entwicklung.
- `daw/audio` ist keine reine Audio-I/O-Schicht.
- `daw/interfaces` definiert fachliche Clip-/Track-/Transport-/Mixer-Grenzen, die als Referenz dienen, aber nicht ungeprüft übernommen werden.

---

## 2026-09-15 – Inventurrunde 2: Produktionsengine und Audio-Initialisierung

### Fragestellung

Wo liegt im gepinnten MAGDA-Stand tatsächlich die Verantwortung für physische Audio-Hardware, wie wird die Produktionsengine erzeugt, und welche Kopplungen müssen wir bei einem eigenen Composition-Studio-Core vermeiden?

### Untersuchte Dateien

- `magda/daw/engine/AudioEngine.hpp`
- `magda/daw/engine/TracktionEngineWrapper.hpp`
- `magda/daw/engine/TracktionEngineWrapperInit.cpp`
- Verzeichnisse `magda/daw/audio`, `magda/daw/interfaces`, `magda/daw/project`
- native Engine-Verzeichnisse `magda/engine/io` und `magda/engine/exec`

### Befund 1 – `AudioEngine` ist kein kleines Audiointerface

Die abstrakte Klasse vereinigt Lifecycle, Transport, Session-Clips, Tempo, Loop, Metronom, Audio-Devices, MIDI, Bridges, Anwendungservices, Plugin-Scan, Pluginparameter, Offline-Render, Projektmedien und MIDI Preview.

**Schlussfolgerung:** Für Composition Studio nicht nachbauen. Wir brauchen mehrere kleine Core-Grenzen statt eines zentralen DAW-Service-Facades.

### Befund 2 – TracktionEngineWrapper bündelt noch mehr Rollen

Der konkrete Wrapper erbt gleichzeitig von AudioEngine, TransportInterface, TrackInterface, ClipInterface, MixerInterface sowie Tracktion- und JUCE-Listenern. Zusätzlich exponiert er Tracktions `Engine` und `Edit` direkt.

**Schlussfolgerung:** Die alten MAGDA-Interfaces reduzieren die reale Kopplung nur begrenzt. Der eigene Core muss Ownership und Verantwortlichkeiten konsequenter trennen.

### Befund 3 – AudioBridge besitzt nicht die Hardware

Die physische Audio-Hardware wird über Tracktions DeviceManager und dessen JUCE AudioDeviceManager initialisiert. `AudioBridge` entsteht erst nach dem Erzeugen einer Tracktion-Edit und synchronisiert MAGDA-/Tracktion-Zustand.

**Korrektur einer bisherigen Arbeitshypothese:** Ein eigener AudioCore darf nicht als Nachbau von `AudioBridge` gedacht werden. Das erste eigene Modul ist vielmehr ein kleiner `AudioDeviceCore` direkt über JUCE/CoreAudio.

### Befund 4 – tatsächlicher Device-Initialisierungspfad

MAGDA lässt Tracktion/JUCE verfügbare Device-Typen scannen, validiert persistierten Audiozustand, initialisiert bis zu 256 angeforderte Kanäle, setzt bevorzugte Geräte über JUCE, aktiviert anschließend alle real vorhandenen Hardwarekanäle und wendet danach MAGDAs Kanalpräferenzen auf Tracktion-WaveDevices an.

Ein besonders wichtiger Kommentar im Originalcode beschreibt einen macOS/CoreAudio-Fehlerfall: Ein gespeicherter Zustand, in dem nur Input oder nur Output benannt ist, kann beim Öffnen eines halb konfigurierten Aggregate-Devices hängen. MAGDA entfernt deshalb einen solchen gespeicherten Zustand vor der Tracktion-Initialisierung.

**Nutzen für Composition Studio:** Dieser Fehlerfall gehört in unsere spätere AudioDevice-Testmatrix, auch wenn wir MAGDAs konkrete Implementierung nicht übernehmen.

### Befund 5 – Message-Thread-Kopplung

Nach `setAudioDeviceSetup()` ruft MAGDA explizit `juce::MessageManager::runDispatchLoopUntil(0)` auf, damit asynchrone Device-/Wave-Rescans abgeschlossen werden.

**Schlussfolgerung:** Device-Konfiguration ist Control-/Message-Thread-Arbeit. Der spätere Realtime-Audiopfad muss davon strikt getrennt werden.

### Befund 6 – Fehlerbehandlung ist verbesserungswürdig

Mehrere Initialisierungsfehler werden lediglich mit `DBG` protokolliert oder führen zu frühem Return. Ein fehlendes Audio-Gerät verhindert nicht zwingend das Weiterlaufen der Engine-Initialisierung.

**Composition-Studio-Entscheidung:** Der eigene AudioDeviceCore soll strukturierte Ergebnisse liefern, z. B. Erfolg, kein Gerät, ungültige gespeicherte Konfiguration, Öffnungsfehler, nicht unterstützte Sample Rate/Buffergröße. Logging ist Zusatz, nicht Fehler-API.

### Befund 7 – native Engine ist bereits sauberer zerlegt

`magda/engine` besitzt getrennte Bereiche `analysis`, `clip`, `exec`, `io`, `param`, `plan`, `tap`, `transport`. `engine/io` behandelt vor allem Datei-/Prefetch-I/O; `engine/exec` enthält EngineSession, EngineDevice, OfflineRender und PlanExecutor/ParallelPlanExecutor.

**Schlussfolgerung:** Für unsere Architektur ist die native Engine als Referenz interessanter als der monolithische TracktionEngineWrapper. Sie wird trotzdem nur analysiert, nicht übernommen.

### Nächster Forschungsschritt

Audio-I/O-Deep-Dive fortsetzen: vollständige `initialize()`-/`shutdown()`-Reihenfolge, Device-Rescan, Channel Enable, Callback-/Threadweg und Ownership untersuchen. Parallel `EngineSession`/`EngineDevice` der nativen Engine lesen, um zu sehen, wie MAGDA selbst die alte Zentralarchitektur aufbricht.

### Dokumentationsstand

Der ausführliche technische Befund wurde in `docs/MAGDA_CATALOG.md` eingearbeitet. Commit der Katalogerweiterung: `594963635cd52bdd33d9f5c50ff5773ef163d26a`.
