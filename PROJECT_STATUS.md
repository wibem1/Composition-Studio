# Composition Studio – verbindlicher Projektstatus

**Stand:** 15. September 2026 – Beginn der systematischen MAGDA-Forschungsphase

> Diese Datei ist zusammen mit dem aktuellen Repository-Stand die technische Wahrheit. Bei Widersprüchen mit Chats oder älteren Notizen gilt GitHub.

## 1. Aktive Strategie

Die Entwicklung wird nicht direkt von der MiniDAW zu einer großen DAW erweitert. Zuerst wird MAGDA systematisch zerlegt, verstanden und getestet.

Die frühere langfristige Zielarchitektur

`Composition Studio → EngineBridge → MAGDA`

ist aufgegeben.

Das neue langfristige Ziel lautet:

`Composition Studio → Composition Studio Core → gezielt gewählte Basistechnologien`

MAGDA dient als **Forschungsobjekt, Referenzimplementierung und technische Anregung**. Langfristig soll möglichst wenig oder kein MAGDA-Code im Composition-Studio-Core verbleiben.

Die Basis-DAW wird später als Labor und Integrationsnachweis für die eigenen Core-Module aufgebaut. Sie ist kein Wegwerfprodukt.

## 2. Verbindliche Forschungsdokumente

- `AGENTS.md` – dauerhafte Arbeits-/Forschungsregeln und neue Engine-Strategie.
- `docs/RESEARCH_ROADMAP.md` – abzuarbeitende Forschungs- und Entwicklungs-To-do-Liste.
- `docs/MAGDA_CATALOG.md` – wachsender systematischer MAGDA-Katalog.
- `docs/RESEARCH_JOURNAL.md` – chronologisches Laborbuch inklusive Fehlversuchen.

Forschungsbasis ist exakt der bisher von Composition Studio gepinnte MAGDA-Commit:

`15e9071d657bf9179432c6a0a3a62f8dd686d8a1`

## 3. Qualitätskriterium „Modul beherrscht“

Ein Modul gilt erst als beherrscht, wenn äußere API, innere Implementierung, Zustände/Lebenszeiten, Abhängigkeiten, Daten-/Kontrollfluss und Thread-/Realtime-Anforderungen verstanden sind, ein reproduzierbarer isolierter Test existiert und wir einen Fehler im betreffenden Originalcode lokalisieren und nötigenfalls gezielt korrigieren könnten.

Danach wird entschieden: Referenz / vorübergehend kapseln / vereinfachen / selbst neu implementieren / nicht benötigt.

## 4. MAGDA – Inventurstand

Erste Systemkartierung abgeschlossen:

- `magda/agents` – Agent-/KI-System.
- `magda/daw` – bestehende DAW und Tracktion-basierte Engine-Schicht.
- `magda/engine` – neue native MAGDA-Engine, laut Root-Build derzeit gebaut/getestet, aber nicht in die App gelinkt.
- `magda/mcp_bridge` – MCP.
- `magda/scripting` – Lua/Scripting.

Für Composition Studio besonders relevante Bereiche sind bereits identifiziert:

- `daw/interfaces`: Clip, Track, Transport, Mixer, DAW-Mode.
- `daw/engine`: `TracktionEngineWrapper` plus getrennte Init-, Transport-, Track-, Clip-, Device-, Plugin- und Recording-Implementierungen; Plugin-Scan, Plugin-Metadaten/-Fenster, Tempo und Offline-Render.
- `daw/audio`: AudioBridge, MidiBridge, Metering, TrackController, PluginWindowBridge, Waveform/Peak, Warp, Comping und ClipCommands.
- `daw/core`: umfangreiche Clip-, Automation-, Routing-, Command- und Managerlogik.
- `magda/engine`: eigenständige native Clip-/MIDI-/Voice-/Warp-/EngineSession-Komponenten; für die eigene Core-Entwicklung besonders wichtige Referenz.

Root-Abhängigkeiten umfassen u. a. JUCE, Tracktion Engine, SoundTouch, Signalsmith Stretch, juce-llm, llama.cpp, Lua, SQLite und optional ONNX Runtime. Die Forschung trennt deshalb konsequent MAGDA-eigene Logik von Fremdbibliotheksfunktionalität.

Die Inventur ist **begonnen, aber noch nicht vollständig bis auf Klassen-/Implementierungsebene abgeschlossen**.

## 5. MiniDAW – letzter technischer Stand

Aktiver MiniDAW-Branch: `minidaw-proof-v1-final`.

Nach zwei fehlgeschlagenen Audio-Auswahl-Builds wurde der konkrete Compilefehler in `MiniDAWBridge.cpp` lokalisiert: JUCE-Audio-Device-Typen waren nur unvollständig deklariert. Korrektur: vollständigen JUCE-Audio-Devices-Header einbinden.

- Korrekturcommit: `6719a88dedb7f67f9db8cd14320b901353a12832`
- Workflow: `Build MiniDAW Proof`
- Run: `34984103280` / Run 6
- Ergebnis: **SUCCESS**
- Artefakt: `MiniDAW-Proof-Intel`
- Artifact ID: `10403543590`
- Größe: 26,788,915 Bytes
- SHA-256: `84471dbceef3d2a12a36070c5252d53051139bb80828190a5b76e52d7cf32e01`

Der Build beweist Kompilierung/Paketierung des korrigierten Stands. Er beweist **nicht** die tatsächliche lokale Audio-/Plugin-Funktion auf dem Intel-Mac.

Der MiniDAW-Strang bleibt als technischer Referenzstand erhalten, ist aber nicht mehr der unmittelbare Ausbaupfad zu einer großen DAW.

## 6. Verbindliches GUI-Ziel

Der freigegebene helle Composition-Studio-GUI-Entwurf bleibt unverändert das visuelle Ziel: hell, freundlich, kontrastreich, klar gegliedert, Arrangement deutlich abgesetzt, dezente Farben, links MusicChat, Mitte Arrangement, rechts Browser, unten Inspector/Routing/Piano-Roll/Notation/Transport; Branding **COMPOSITION STUDIO by Klangwerke**.

Die Forschungs- und Basis-DAW-Oberflächen sind keine neuen GUI-Entwürfe.

## 7. Nächste Arbeitsschritte

1. MAGDA-Inventur bis auf relevante Klassen-/Implementierungsebene vervollständigen.
2. Fremdabhängigkeiten/Lizenzgrenzen und Modul-Abhängigkeitsgraph erfassen.
3. Initialisierung, Lebenszyklus, Zustandsverwaltung und Threadmodell kartieren.
4. danach **Audio-I/O als erstes isoliertes Forschungsmodul** vollständig analysieren und testen.
5. daraus den ersten eigenen Composition-Studio-Core-Baustein ableiten.
6. anschließend Transport, MIDI, Tracks/Clips, Plugin-Hosting, Mixer/Routing und Projektverwaltung in derselben Weise abarbeiten.

Die vollständige Reihenfolge steht in `docs/RESEARCH_ROADMAP.md`.
