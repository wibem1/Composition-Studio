# Composition Studio – Forschungs- und Entwicklungs-Roadmap

**Forschungsbasis MAGDA:** `Conceptual-Machines/magda-core` @ `15e9071d657bf9179432c6a0a3a62f8dd686d8a1`

Diese Liste wird tatsächlich abgearbeitet. Ein Punkt wird nicht allein wegen eines erfolgreichen Builds abgehakt. Ein Modul gilt erst als beherrscht, wenn Implementierung, Abhängigkeiten und Laufzeitverhalten verstanden sind und ein reproduzierbarer Test existiert.

## Phase A – Forschungsgrundlage

- [x] Neue Strategie festlegen: MAGDA ist Referenz-/Forschungssystem, nicht langfristiges Fundament.
- [x] Dauerhafte Arbeitsregeln in `AGENTS.md` anpassen.
- [x] Forschungs-Roadmap anlegen.
- [x] Forschungsjournal anlegen.
- [x] MAGDA-Katalog anlegen und erste Systemstruktur erfassen.
- [ ] Vollständigen MAGDA-Quellbaum bis auf relevante Klassen-/Dateiebene katalogisieren.
- [ ] Fremdabhängigkeiten und Lizenzen vollständig erfassen.
- [ ] Modul-Abhängigkeitsgraph erstellen.
- [ ] Initialisierung, Lebenszyklus, Zustandsverwaltung und Threadmodell vollständig kartieren.

## Phase B – isolierte Kernmodule

- [ ] **Audio-I/O:** Geräteerkennung, Auswahl, Sample Rate, Buffer, Callback, Start/Stop, Fehlerfälle; MAGDA/JUCE-Anteile trennen; eigenen `AudioCore` ableiten.
- [ ] **Transport/Timing:** Play, Stop, Pause, Position, Seek, Tempo, Taktart, Beat-/Zeitumrechnung, Audio-Thread-Synchronität; eigenen `TransportCore` ableiten.
- [ ] **MIDI:** Datenmodell, Note On/Off, Velocity, CC, Program Change, Pitch Bend, Import/Export, Echtzeit-MIDI, Timing; eigenen `MidiCore` ableiten.
- [ ] **Tracks/Clips:** Lebenszyklus, MIDI-/Audio-Tracks, Clip-Modell, Position/Länge/Editierung, Mehrspur; MAGDA/Tracktion-Anteile trennen; eigenen `TrackClipCore` ableiten.
- [ ] **Plugin-Hosting:** Scan, VST3/AU, Instanziierung, MIDI→Plugin→Audio, Editor, Parameter, State/Preset, Fehlerfälle; eigenen `PluginHost` ableiten.
- [ ] **Mixer/Routing:** Signalwege, Gain/Pan, Mute/Solo, Inserts, Sends/Busses, MIDI-/Audio-Routing; eigenen `MixerCore` ableiten.
- [ ] **Projekt/Persistenz:** Projektformat, Tracks/Clips/Plugins, Plugin-State, Tempo, Laden/Speichern, Fehlerbehandlung; eigenes Projektformat entwerfen.

## Phase C – weitere DAW-Bausteine

- [ ] Automation und Parameter.
- [ ] Recording.
- [ ] Audio-Clips, Fades, Warping/Stretching.
- [ ] Undo/Redo und Command-System.
- [ ] Arrangement/Session-Modell.
- [ ] Piano-Roll-/Noten-bezogene Funktionen.
- [ ] Offline Render/Export.
- [ ] Metering/Analyse.
- [ ] Medien-/Dateiverwaltung nur soweit Composition Studio sie benötigt.
- [ ] Scripting/Agent/MCP-System untersuchen und Nutzen für MusicChat bewerten.

## Phase D – MAGDA-Unabhängigkeit

Für jedes beherrschte Modul:

- [ ] Entscheidung dokumentieren: Referenz / vorübergehend kapseln / vereinfachen / neu implementieren / nicht benötigt.
- [ ] eigenes Core-Modul mit klarer API definieren.
- [ ] isolierte Unit-/Integrationstests erstellen.
- [ ] vorhandene MAGDA-Abhängigkeit schrittweise ersetzen.
- [ ] Regressionstest gegen bekannten Referenzfall durchführen.
- [ ] Lizenz-/Provenienzgrenze dokumentieren: eigener Code vs. Fremdbibliothek vs. MAGDA-Referenz.

## Phase E – Basis-DAW aus dem eigenen Core

- [ ] 2–4 echte Spuren.
- [ ] MIDI importieren/exportieren.
- [ ] Clips im Arrangement darstellen und auswählen.
- [ ] Instrument pro Spur laden.
- [ ] mehrere Spuren gemeinsam hörbar wiedergeben.
- [ ] Play/Stop/Seek und sichtbare Position.
- [ ] Projekt speichern/laden.
- [ ] reproduzierbarer Intel-Mac-Praxistest.

## Phase F – Composition Studio

Erst auf dem nachgewiesenen Core:

- [ ] freigegebenes Composition-Studio-GUI integrieren.
- [ ] Arrangement, Browser und Inspector.
- [ ] Mixer/Routing.
- [ ] Piano Roll und Notendarstellung.
- [ ] MusicChat/KI-Integration.
- [ ] weitere Funktionen nach belastbaren Funktionsketten.

## Abnahmekriterium für ein Forschungsmodul

Ein Modul darf als **beherrscht** markiert werden, wenn alle folgenden Fragen mit Ja beantwortet sind:

1. Kennen wir seine Aufgabe und Grenzen?
2. Kennen wir zentrale Klassen, Datenstrukturen und Zustände?
3. Kennen wir seine Abhängigkeiten und Lebenszeiten?
4. Kennen wir Thread-/Realtime-Anforderungen?
5. Können wir den Daten- und Kontrollfluss erklären?
6. Gibt es einen isolierten reproduzierbaren Test?
7. Sind Fehlerfälle getestet oder ausdrücklich dokumentiert?
8. Könnten wir einen Fehler im betreffenden Originalcode lokalisieren und gezielt korrigieren?
9. Ist entschieden, was davon im eigenen Composition Studio Core benötigt wird?
10. Ist das Ergebnis im Katalog und Forschungsjournal dokumentiert?
