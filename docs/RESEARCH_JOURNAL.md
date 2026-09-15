# Composition Studio – Forschungsjournal

Dieses Dokument ist das chronologische Laborbuch. Auch Fehlversuche und widerlegte Annahmen werden festgehalten.

## 2026-09-15 – Strategiewechsel: MAGDA vom Fundament zum Forschungsobjekt

### Ausgangslage

Die Entwicklung über `Composition Studio → EngineBridge → MAGDA` führte bei selbst einfachen Funktionen wiederholt zu Trial-and-Error an MAGDA-/JUCE-/Tracktion-Grenzen. Der V1.0RC war im Praxistest nicht brauchbar. Die MiniDAW wurde deshalb als kleiner technischer Prüfstand aufgebaut.

### Beobachtung

Schon die explizite Audio-Auswahl zeigte die Schwierigkeit: Eine scheinbar kleine Funktion erforderte Kenntnis von MAGDAs Engine-Wrapper, JUCE DeviceManager/AudioIODeviceType, Header-/Typgrenzen und Bridge-Lebenszeiten. Der aktuelle Korrekturcommit des MiniDAW-Zweigs ist `6719a88dedb7f67f9db8cd14320b901353a12832`; der zugehörige CI-Lauf 6 war beim Start dieser Forschungsphase noch in Arbeit.

### Entscheidung

MAGDA wird nicht mehr als langfristig unverzichtbare Engine betrachtet. Es wird systematisch analysiert und als Referenz verwendet. Ziel ist ein eigener modularer Composition Studio Core. Langfristig soll möglichst wenig oder kein MAGDA-Code im Produkt verbleiben.

### Qualitätsziel

Ein MAGDA-Modul gilt nicht als verstanden, weil wir eine aufrufbare Funktion gefunden haben. Wir müssen äußere API, innere Implementierung, Zustand, Lebenszeit, Threads, Datenfluss, Abhängigkeiten und Fehlerfälle so weit beherrschen, dass wir einen Fehler im Originalcode lokalisieren und bei Bedarf gezielt korrigieren könnten.

---

## 2026-09-15 – Inventurrunde 1

### Forschungsbasis

Untersucht wird zunächst exakt der von Composition Studio gepinnte MAGDA-Commit:

`15e9071d657bf9179432c6a0a3a62f8dd686d8a1`

Damit vermeiden wir, Erkenntnisse aus einem neueren MAGDA-Stand mit dem tatsächlich verwendeten Stand zu vermischen.

### Befund 1: MAGDA besteht aus mehreren deutlich trennbaren Systemen

Der eigene Quellbaum unter `magda/` enthält `agents`, `daw`, `engine`, `mcp_bridge` und `scripting`. Die bestehende DAW liegt überwiegend in `magda/daw`; daneben existiert eine neue native Engine unter `magda/engine`.

### Befund 2: Die bestehende DAW-Engine ist stark Tracktion-basiert

`magda/daw/engine` enthält einen `TracktionEngineWrapper` mit getrennten Implementierungen für Init, Transport, Tracks, Clips, Devices, Plugins und Recording. Plugin-Scanner, Plugin-Metadaten, Plugin-Fenster, Tempo-Brücken und Offline-Render liegen in derselben Schicht.

**Konsequenz:** Bei jedem dieser Bereiche muss getrennt werden, was MAGDA selbst leistet und was nur Tracktion/JUCE exponiert oder orchestriert.

### Befund 3: MAGDA besitzt bereits eine zweite, native Engine-Entwicklung

Die Root-Build-Konfiguration bezeichnet `MAGDA_BUILD_NATIVE_ENGINE` ausdrücklich als native Engine, die derzeit gebaut und getestet, aber nicht in die App gelinkt wird. Im Quellbaum existieren bereits eigene Clip-/MIDI-/Voice-/Warp-/EngineSession-Komponenten.

**Konsequenz:** `magda/engine` wird als eigenständiges Forschungsobjekt behandelt. Es kann für unseren eigenen Core informativer sein als der alte Tracktion-Wrapper, darf aber nicht automatisch als fertige Lösung übernommen werden.

### Befund 4: `daw/audio` ist keine saubere Audio-I/O-Schicht

Der Bereich enthält neben `AudioBridge` und `MidiBridge` auch Metering, TrackController, PluginWindowBridge, Waveform/Thumbnail, Warp, Comping und ClipCommands.

**Konsequenz:** Unser eigener Core sollte Verantwortlichkeiten stärker trennen. Ordnernamen in MAGDA werden nicht als Architekturvorgabe übernommen.

### Befund 5: MAGDA hat bereits fachliche Interfaces

`magda/daw/interfaces` definiert Clip-, Track-, Transport-, Mixer- und DAW-Mode-Interfaces. Diese sind nützlich, um MAGDAs gedachte fachliche Grenzen zu verstehen.

**Konsequenz:** Interfaces werden analysiert, aber nicht ungeprüft zur Composition-Studio-Core-API erklärt.

### Nächster Forschungsschritt

Inventur bis auf Klassen-/Implementierungsebene vervollständigen und anschließend den Initialisierungs-/Audio-I/O-Pfad vollständig verfolgen. Der erste isolierte Modultest wird Audio-I/O sein, weil alle späteren hörbaren Tests davon abhängen.
