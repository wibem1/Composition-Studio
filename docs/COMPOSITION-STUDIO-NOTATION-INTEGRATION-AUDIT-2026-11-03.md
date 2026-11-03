# Composition Studio v1.1.6 – Bestandsaufnahme und Notenansicht-Integration
Stand: 03.11.2026 · Branch `feat/notation-selection-integration-20261103` · Draft-PR #8

## Verbindlicher Quellstand
- `Composition Studio.lua` auf `main`, v1.1.6, vor Änderungen vollständig eingelesen. Das ist die bestehende KI-/MIDI-Kompositionssteuerung.
- `Notation Studio.lua` auf `main`, v0.1.24, ist ein **anderes** REAPER-ReaScript und wurde bei dieser Aufgabe nicht verändert.
- Das neue Einmal-Notation-Shortcut-Skript (Vier-Takte-Zoom, Schlüssel, vertikaler Zoom, ausgewählte MIDI-Items) liegt in separat entwickeltem Draft-PR #7. Es ist nicht identisch mit Composition Studio.
- Projektregeln aus `wibem1/AI-Development-Standards`, `AGENTS.md`, `PROJECT_STATE.md` berücksichtigt.

## Was der bisherige Hauptcode tatsächlich kann

| Bereich | Befund | Grenze |
| --- | --- | --- |
| KI-Gespräch | Freie Aufträge, Modell-/Denkstufenauswahl, Kommunikation mit Anbietern | Wirksamkeit/Antwortqualität hängt vom Modell und API ab |
| Auswahl und Kontext | Markierte MIDI-Items und Spuren aus dem REAPER-Arrangement, Noten/Timing/Velocity aus Takes, Tempo und Zeitauswahl | Vor PR #8 keine zuverlässige Unterscheidung einzelner markierter Noten im MIDI-Noteneditor |
| Analyse | Liest MIDI-Kontext aus und fordert musikalische Textanalyse an; speichert Analyse | Keine automatische fachliche Wahrheitsprüfung; Notationsangaben und CC/Artikulation nicht vollständig im Analysekontext |
| Komposition/Fortsetzung | Mehrere Kompositionspfade (CS-/JSON-/LilyPond), Fortsetzung, Übersetzung in MIDI | Komplexe Transport-/Übersetzungsketten; vollständige Ausgabe nicht durch Syntaxprüfung garantiert |
| Bearbeitung | `MIDI_SetNote` für Item-Transposition, neue Varianten; `MIDI_InsertNote` für neue Items | Item-Transposition betrifft im Altcode **sämtliche ungemuteten Noten**; nicht einzelne notierte Auswahl |
| Neue Instrumentalspuren | `InsertTrackAtIndex`, neue MIDI-Items, Program Changes | Neues Instrument wird erzeugt, aber ein passendes reales VST/Plugin nicht automatisch garantiert |
| Vorschlag/Übernahme | Dauerhafte Workflow-Historie, Originalbindung via Projekt-Chunk-Prüfung, vorgeschlagene MIDI-Änderungen vor expliziter Übernahme, Undo | Sofort-Controller-Aktionen `ACTION|` sind im Altcode für Item-Operationen weiterhin ausgenommen |
| REAPER-Notenbild | REAPER-native MIDI-Notation nutzbar | Notenabstände, Umbrüche und Minipausen liegen wesentlich in REAPERs Renderer; Composition Studio ist kein eigener Notensatz |

## Stabilitätsurteil (vor neuer Integration)
**Architektur: mittleres bis erhöhtes Risiko; keine pauschale Produktfreigabe.** Der produktive Hauptcode ist eine große, stark gekoppelte Lua-Datei mit UI, KI-Transport, Parsing, Projektpersistenz und MIDI-Mutation. Vorhanden sind Original-/GUID-Bindungen, Undo-Blöcke, einige fachliche Prüfungen, Wiederherstellung/Sicherungslogik und Teiltests. Unvollständig sind eine kleine, isoliert testbare Trennung der Schichten, die präzise Noten-Auswahl-Schnittstelle, End-to-End-Tests mit REAPER für alle Kompositionspfade und Garantien für komplexe KI-Ergebnisse. Eine stabile Lua-Syntax oder bestandener Mock ist **kein** Beweis für korrekte grafische Notenansicht oder musikalische Qualität.

Besonders zu beachten:
1. Vorherige `selected_items()` betrachtete Arrangement-Item-Auswahl. Der MIDI-Editor kann einzelne Noten auswählen, ohne das Item im Arrangement zu markieren.
2. Die vorhandene `ACTION|TRANSPOSE`-Routine schreibt alle ungemuteten Noten eines Items und ist keine Auswahloperation.
3. `CS|target`/andere CS-Kompositionsjobs erzeugen neue MIDI-Items und sind kein kontrolliertes In-place-Patching eines beliebigen Teils eines alten Items.
4. Die Prüfung der gespeicherten `source_guard` über den gesamten Projektzustand ist sicherheitsorientiert, kann bei sehr großen Projekten aber merkliche Rechenzeit kosten.
5. Der vorhandene REAPER-Noteneditor zeigt bei mehreren Spuren möglicherweise nur kontinuierliche Notensysteme, nicht das professionelle Seitenlayout.

## Umsetzung in PR #8 – begrenzter, sicherer Entwicklungsschritt

- Neue `notation_selection_items(with_notes)` liest **aus dem aktiven nativen MIDI-/Noteneditor** über `MIDIEditor_EnumTakes(...,true)` alle editierbaren MIDI-Takes und pro Take die tatsächlich markierten, nicht gemuteten Noten. Die Quelle wird durch Item-GUID, Notenindex, PPQ-Start/-Ende, Kanal, Tonhöhe und Velocity bezeichnet.
- `selected_items()` bevorzugt eine existierende Einzelnotenauswahl, sonst fällt es auf die herkömmliche Item-Auswahl zurück. Fortsetzungen beziehen sich zur Sicherheit weiterhin auf vollständige Items (`scope="items"`).
- Controller-/Analyse-/Kompositionsaufrufe bekommen die **zum Auftragseingang eingefrorene** Notenauswahl, inklusive Spuren, Kontext und Quellbindung. Ein Wechsel der Auswahl während der asynchronen KI-Bearbeitung ändert den ursprünglichen Auftrag nicht.
- KI-Änderungen aus einer Notenauswahl erzeugen **nur separate Varianten (`CS|revised`) oder neue Stimmen (`CS|new`)**; `CS|target`, `CS|track` und direkte Whole-Item-Sofortaktionen werden im Auswahlpfad gesperrt. Unmarkierte Noten werden nicht automatisch überschrieben.
- Neu: Der explizite Auftrag **„Transponiere die markierten Noten um 2 Halbtöne“** erzeugt ohne zusätzlichen KI-Aufruf einen *Vorschlag*. Erst nach „Änderungen anwenden“ wird transponiert. Vorher kontrolliert das Skript Projektstand, alle Quellnoten/-indizes und MIDI-Grenzen. Ausgeführt wird in einem Undo-Block mit `MIDI_SetNote` nur für die ursprünglich markierten Noten; alle anderen Noten, Zeitpositionen, Notenlängen und Velocity bleiben unverändert.
- Keine neue UI, keine Änderung an `main`, keine Versionsnummererhöhung, keine automatische Installation.

## Fokuswechsel und Performance (nachträglich geprüft)

Die offizielle REAPER-API beschreibt `MIDIEditor_GetActive()` ausdrücklich als **fokussiertes** MIDI-Editor-Fenster. Deshalb merkt sich der laufende Composition-Studio-`defer`-Loop nun den zuletzt fokussierten MIDI-Editor. Wenn der Nutzer zum Studio-Eingabefeld wechselt, wird der zwischengespeicherte Editor nur nach erfolgreicher `MIDIEditor_GetTake`-/`ValidatePtr2`-Prüfung erneut benutzt; bei geschlossenem Editor fällt die Auswahl sicher auf „nicht verfügbar“ zurück. In REAPER noch nicht grafisch bestätigt.

Weil die Studio-Oberfläche laufend aktualisiert wird, verwendet die Auswahlfunktion bevorzugt das native `MIDI_EnumSelNotes(take, lastIndex)`, um **nur markierte Events** zu lesen; ein vollständiger Note-Scan dient nur als Fallback. Dieser Performance-Fix ist ebenfalls im Offline-Produktionsfunktionstest enthalten.

Bei Aufträgen, die ausdrücklich „markierte Noten“ verlangen, aber **keine** editierbaren markierten Noten im MIDI-Editor erkennen lassen, erfolgt eine klare Fehlermeldung statt einer gefährlichen Interpretation als Gesamt-Item-Auftrag.

## Nachweise
- GitHub Actions `Composition Studio notation selection regression` Run [41593334412](https://github.com/wibem1/Composition-Studio/actions/runs/41593334412) erfolgreich: `luac5.4 -p` für vollständige Produktionsdatei und neuen Test; isolierte Tests des **echten Produktions-Funktionsquellcodes** für mehrere editierbare Takes, nur markierte Noten, stummgeschaltete und nicht markierte Noten, gespeicherte PPQ-Identitäten, genehmigte Transposition, unveränderte Begleitnoten, Undo, stale selection, Grenzprüfung, Fokuswechsel bei weiterhin geöffnetem Editor sowie native Enumeration ausschließlich ausgewählter Events.
- **Nicht belegt:** Im echten REAPER wurde diese Änderung weder grafisch noch mit realen API-Anbietern oder mehrspuriger Partitur getestet. Das ist ein Entwicklungskandidat, keine fertige Releaseversion.

## Offene Aufgaben und reale Prüfung
1. In einem gesicherten REAPER-Projekt 2–3 Noten aus mindestens zwei MIDI-Spuren im Noteneditor markieren, Composition Studio öffnen bzw. dort vorhandenen Auftrag eingeben: „Analysiere die markierten Noten“. Kontrollieren, ob die Analyse nur die markierten Noten erfasst.
2. Dieselbe Art Auswahl: „Transponiere die markierten Noten um 2 Halbtöne“, Vorschlag ansehen, „Änderungen anwenden“; prüfen, ob exakt diese Noten im REAPER-Noteneditor verändert wurden und Undo die Änderungen zurücknimmt.
3. Erst danach gezielte freie KI-Überarbeitung **innerhalb** des ursprünglichen MIDI-Items mit Schutz der unmarkierten Noten implementieren. Das erfordert eine sichere, von `CS|revised` getrennte Teilbereich-Übernahmeroutine, Prüfung von Überschneidungen/Polyphonie, MIDI-Events/Artikulation und eigenem Regressionstest; nicht mit ungesicherter KI-Ausgabe pauschal Note-on/off überschreiben.
4. Entscheidung über Freigabe/PR-Merge erst nach dem sehr begrenzten realen REAPER-Praxistest. Bei zwei gezielten Fehlversuchen zuerst Ursache klären, nicht weitere Testpakete produzieren.
