# Native Notation Studio – technisch geprüfte Testfassung

Stand: 07.11.2026. Eigenständige Datei `Native-Notation-Studio.lua`, Branch `feat/semantic-notation-analysis-20261104`. Keine Integration in Composition Studio, kein Merge und keine Produktionsfreigabe. Die Kennzeichnung `0.1.0-test` bleibt bestehen.

## Verbindliches Ziel und aktueller Umfang

Ein Knopfdruck **Lesbare Notation erstellen** soll eine möglichst gute native REAPER-Notation für die **aktuell im MIDI-/Notationseditor dargestellten Tracks** liefern. Markierte Einzelnoten und Arrangement-Auswahl begrenzen den Auftrag nicht. Das Skript erfasst alle über `MIDIEditor_EnumTakes(editor, index, false)` gemeldeten Takes und deren gesamte Noteninhalte, auch außerhalb des gerade horizontal sichtbaren Ausschnitts. Ausgeblendete Takes sind nicht Ziel. Die tatsächliche Zuordnung der REAPER-Tracklist zur API-Liste muss im Praxistest bestätigt werden.

Die vorhandene Umsetzung interpretiert Einsätze und Dauern anhand der Phrase und echter Taktgrenzen. Pro Note werden Take-Zugehörigkeit, Tonhöhe, Kanal und Velocity übergeben. Ein einziger vorbereiteter KI-Auftrag erzeugt konservativ geprüfte `DISPLAY`-Vorschläge; es gibt keine manuelle Prompt-Eingabe, automatische Wiederholungen oder bezahlte Kontrollanfragen. Native Notationsansicht und proportionale Abstände werden aktiviert. Eigene Anzeigequantisierung und Mindestnotenlänge bleiben erhalten.

Geschrieben werden ausschließlich ergänzte REAPER-Notationsevents (`disp_pos`, `disp_len`), keine Note-On/Off-, Controller-, Pedal-, Velocity-, Tempo- oder anderen Performance-Ereignisse. Bestehende Anzeigeoffsets werden nicht überschrieben. Mehrdeutige identische Anschläge bleiben unangetastet. Notationsmetadaten verändern den rohen MIDI-Puffer; unverändert bleiben die gespielten Ereignisse und deren absolute Zeitpunkte, nicht der Hash des gesamten Puffers.

## Einmalige Einrichtung

1. `Native-Notation-Studio.lua` in den dauerhaften **Scripts**-Ordner des REAPER-Ressourcenverzeichnisses kopieren. Über **Actions → Show action list**, Bereich **MIDI Editor**, **ReaScript → Load** laden. Die Aktion heißt **Native Notation Studio - Lesbare Notation erstellen**; sie kann einem Toolbar-Knopf oder Shortcut zugewiesen werden.
2. REAPER muss die Umgebungsvariable `OPENAI_API_KEY` sehen. Ein Browser-Abonnement ersetzt diesen API-Zugang nicht. Der Schlüssel wird weder in das Skript noch in die erzeugten Dateien geschrieben. Fehlender Schlüssel führt vor einem Netzwerkaufruf zum Abbruch. Standardmodell ist die bereits vorhandene Kennung `gpt-5.4`; bei Bedarf einmalig über die Umgebungsvariable `NATIVE_NOTATION_MODEL` ändern. Verfügbarkeit/Zugriffsrecht wurde nicht live abgefragt.
3. Windows: System-PowerShell und `%SystemRoot%/System32/curl.exe`. macOS: `/bin/sh` und `/usr/bin/curl`. curl muss `--fail-with-body` unterstützen. Bei fehlenden Programmen/Optionen erfolgt ein Fehler ohne Notationsänderung. Keine weiteren REAPER-Erweiterungen erforderlich.

Das Skript greift nicht auf Composition-Studio-Einstellungen zu. Im normalen Ablauf wird direkt die KI aufgerufen. Der ausschließlich für Entwickler bestimmte ExtState `NativeNotationStudio/TestResponseFile` muss leer sein; ein gesetzter Wert ersetzt die API durch eine lokale DISPLAY-Datei.

## Ein einziger abschließender REAPER-Praxistest

In einer gespeicherten Projektkopie eine kurze expressive Passage von etwa vier Takten mit zwei oder drei Tracks (zusammen höchstens 500 Noten) im nativen MIDI-/Notationseditor darstellen. Einen weiteren vorhandenen Track ausgeblendet lassen. Die komplette Darstellung ist Ziel; keine Einzelnoten markieren und keinen Prompt schreiben.

**Einmal die Aktion ausführen**, während der Analyse keine Projektbearbeitung vornehmen. Danach prüfen: Alle dargestellten Tracks sind berücksichtigt, der ausgeblendete Track bleibt unverändert, das Notenbild wirkt rhythmisch nachvollziehbarer, und der Klang ist unverändert. Einmal **Undo**, anschließend **Redo**: Die Notationsänderungen müssen gemeinsam verschwinden und wieder erscheinen; die Performance muss in allen drei Zuständen gleich bleiben. Damit ist der eine gebündelte Praxistest abgeschlossen. Bitte nur Ergebnis und gegebenenfalls einen Screenshot derselben Takte zurückmelden.

Es werden keine weiteren Benutzertests vorausgesetzt. Abbruch, beschädigte Antworten und Schreibfehler wurden automatisiert simuliert.

## Automatisiert nachgewiesen

Reproduzierbarer Einstieg: `python tools/test_native_notation_standalone.py`. Einzelne Lua-Suite: `lua5.4 tests/test_native_notation_standalone.lua`; ohne Lua-CLI auf Linux mit liblua5.4 auch `python tools/run_lua54.py tests/test_native_notation_standalone.lua`. Alle Tests laufen offline.

Am 07.11.2026 bestanden **90 Standalone-Prüfungen unter Lua 5.4** und zusätzlich unter dem vorhandenen TeX-Lua (Lua 5.3). Dazu **drei tatsächlich ausgeführte Unix-Wrapperprüfungen** mit einem lokalen curl-Ersatz und Exitcodes 0, 22 und 28. Keine Netzwerk-/KI-Anfrage. [Vollständiges Prüfprotokoll](NATIVE-NOTATION-STANDALONE-RESULTS.txt).

Geprüft: vollständiges Skript laden, beschädigte Quellpuffer und ungültige Noteninventare vor dem API-Aufruf abweisen, nicht wiederholte Loop-source-Items zulassen, tatsächliche Wiederholungen und mehrere Pool-Verweise erkennen, abgebrochene übergroße Antworten ohne Fehlermeldung verwerfen und bereinigen, alle dargestellten Takes unabhängig von Auswahl, konservative Notenwertprüfung einschließlich 6/8 und Triolen, Unicode/Surrogatpaare/JSON-Escapes und ungültige JSON-Strukturen, Responses-Ausgabestruktur, Teilantworten/Ablehnung/Fehler, Größen- und Zeitgrenzen, asynchroner Abschluss, Abbruch ohne Schreiben, Fokus des Fortschrittsfensters, zwischenzeitlich geändertes Projekt/Takes/Editor/Sichtbarkeit, fehlerhafte Dateien, Schreib-Rücklesevergleich, Zwei-Take-Rollback und explizit gemeldeter Rollbackfehler.

Realistische MIDI-Fixtures enthalten expressive Anschläge, Überlappungen, Note-Off-Velocity, mehrere Kanäle, Pedal, SysEx, Mute-/Selektionsflags, negative Deltas, vorhandene Artikulation und leere Endereignisse. Der Vergleich kontrolliert **alle Nicht-Notationsevents mit absoluten Ticks, Flags und Nachrichtenbytes**. Undo wird als Transaktion simuliert und die Wiederherstellung der Originalpuffer geprüft; das echte REAPER-Undo-System ist damit nicht abgenommen.

## Nur innerhalb realer Komponenten prüfbar

Keine REAPER-Installation und kein PowerShell in dieser Umgebung. Windows-/macOS-Befehlsaufbau und Pfadquotierung sind mit Simulation geprüft; der Unix-Wrapper wurde unter Linux tatsächlich ausgeführt. Das beweist keine native Plattformabnahme. Echter Providerzugang, Modellantwort, sichtbares Notenbild, Wiedergabe, REAPERs Behandlung der Anzeigeoffsets sowie tatsächliches Undo/Redo stehen noch aus. **Keine Produktionsfreigabe aus den Simulationsergebnissen ableiten.**

## Verbleibende Grenzen

- Der Zielanspruch ist bestmögliche Notation aller dargestellten Tracks; die vorhandene technische Umsetzung liefert zunächst konservative **Anzeigeeinsätze und Anzeigedauern**. Sie rekonstruiert keine vollständige druckreife Partitur. Automatische Schlüsselwahl, neue Stimmen-/Handzuweisung, neue Vorschlagsnoten und umfassender Seitenumbruch sind nicht implementiert. Bestehende REAPER-System-/Schlüsselkonfiguration bleibt maßgeblich. Musikalische Ergebnisqualität wurde nicht mit echter KI beurteilt.
- Höchstens 500 Noten pro Gesamtauftrag; bei Überschreitung vollständiger Abbruch vor API-Aufruf, keine stille Teilbearbeitung. Stark abweichende Dauern, sehr kurze Vorschläge und unsichere Vorschläge werden ausgelassen. Geänderte Projektzustände verwerfen das Ergebnis vollständig.
- Tatsächlich wiederholte und gepoolte MIDI-Items sowie Take-Playrate ungleich 1 werden vor der Analyse abgewiesen, um uneindeutige Anzeigeeinheiten und Auswirkungen auf weitere Items zu vermeiden. Die aktivierte Option „Loop source“ allein ist kein Ablehnungsgrund: Nicht wiederholte Items werden anhand von Item-Ausdehnung und Quelllänge erkannt und zugelassen. Loop-Quellen mit eigenem Tempo oder nicht eindeutig lesbarer Länge werden weiterhin abgewiesen.
- Abbrechen per Esc, Fenster schließen oder anklicken verhindert die Übernahme. Ein bereits gesendeter API-Auftrag wird dadurch **nicht serverseitig storniert**; der Hintergrundprozess darf bis zu seinem 90-Sekunden-Limit weiterlaufen und kann Kosten verursachen. Es gibt keinen automatischen Retry. REAPER bleibt währenddessen bedienbar; jede Projektänderung verhindert eine spätere Übernahme.
- Regulärer Prozessabschluss entfernt die temporären Anfragen/Antworten/Wrapper. Bei REAPER-Absturz, erzwungenem Skriptabbruch oder Start-/Zeitlimitfehler können Diagnose-Dateien `NNS-*` verbleiben; diese enthalten keinen API-Schlüssel. Inventar und Prompt bleiben als `NativeNotationStudio-notes.txt` und `NativeNotationStudio-prompt.txt` im Ressourcenverzeichnis und werden beim nächsten Aufruf ersetzt.
- Scheitert selbst die geprüfte Wiederherstellung, wird ausdrücklich auf REAPER Undo hingewiesen; ein fehlgeschlagener Rückschreibvorgang wird niemals als Erfolg gemeldet.

API-Referenz: [offizielle REAPER-ReaScript-Dokumentation](https://www.reaper.fm/sdk/reascript/reascripthelp.html), insbesondere `MIDIEditor_EnumTakes`, `ExecProcess`, `MIDI_GetAllEvts` und die Undo-Funktionen.
