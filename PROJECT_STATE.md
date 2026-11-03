# Projektstand – Composition-Studio

## 03.11.2026 – Reale Negativmeldung: Einmal-Notationsskript ohne Wirkung; Diagnose vor weiterer Änderung

**Nutzerbefund:** Das angehängte `REAPER Notation - 4 Takte und Instrumentenschluessel.lua` tut im MIDI-Editor nach Nutzerangabe nichts. Start im MIDI-Editor wurde ausdrücklich bestätigt. Dies ist ein negativer Praxisbefund; die früheren Mocktests sind kein Gegenbeleg. Die angehängte Fassung enthält noch nicht die spätere Mehrfach-Item-Öffnung dieses Branches. Ob das den aktuellen Fehler betrifft, ist unbekannt.

**Statisch belegt:** `note()` verwirft jede Meldung, einschließlich des äußeren `pcall(main)`-Fehlers. Die Anzeigeaktionen hängen von exakt englischen Aktionsnamen ab. Das Skript schaltet selbst nicht in den Notationsmodus um. Keine dieser Beobachtungen beweist allein die konkrete lokale Fehlerursache. API-Signaturen wurden mit der offiziellen ReaScript-Dokumentation für REAPER 7.83 abgeglichen (https://www.reaper.fm/sdk/reascript/reascripthelp.html).

**Gezielter nächster Schritt:** `REAPER_Notation_Diagnose.lua` einmal im selben MIDI-Editor ausführen. Das neue Werkzeug liest Version/Plattform, Start-Aktionsbereich, Editor/Takes, Notenzahl, vorhandene SCORE-Zeilen, Taktgrenzen, benötigte API-Funktionen und die echten lokalen Zoom-/Modus-/Proportional-Aktionsnamen. Es führt KEINE Anzeigeaktionen, Schlüssel-/Chunk-/MIDI-Schreiboperationen oder Änderungen an Auswahl/Einstellungen aus. Es öffnet nur für diesen Diagnoseaufruf die Konsole. Der bisherige normale Shortcut bleibt unverändert und fensterlos.

**Prüfung:** `tests/test_notation_diagnose.py`, Lua 5.4/lupa, vier erfolgreiche Ausführungsfälle: normal, anderssprachige Aktionsnamen, fehlender fokussierter Editor, fehlende Aktions-API. Strikter Mock weist jeden unerwarteten/mutierenden API-Aufruf zurück. Noch keine echte Ausführung der Diagnose im Nutzer-REAPER, keine Ursache bestätigt, keine Reparatur-/Releasebehauptung. Kein neuer Composition-Studio-Release und keine automatische CI gestartet.


## 03.11.2026 – Alle markierten MIDI-Items gemeinsam im Noteneditor öffnen (Testkandidat)

**Nutzerwunsch:** Der Einmal-Shortcut soll nicht nur bereits sichtbare Notations-Takes optimieren, sondern auch **alle im Arrangement markierten MIDI-Items** gemeinsam als Notensysteme anzeigen. Vorhandene vier Takte Horizontalzoom, automatischer Vertikalzoom, MIDI-basierte Schlüsselwahl, Proportionalanzeige und Fensterfreiheit bleiben erhalten.

**Implementiert** auf `feat/reaper-notation-one-shot-20261102`, Draft-PR #7: `open_selected_items_if_missing(editor)` prüft `CountSelectedMediaItems`, `GetSelectedMediaItem`, `GetActiveTake` sowie `MIDIEditor_EnumTakes`; fehlen markierte MIDI-Items im geöffneten Editor, werden die nativen REAPER-Aktionen `40896` (ein MIDI-Editor pro Projekt), `40898` (alle ausgewählten MIDI-Items) und `40153` (Open in built-in MIDI editor) ausgeführt. Danach wird `MIDIEditor_GetActive` neu gelesen und das vorhandene Layoutskript auf die tatsächlich offenen Takes angewandt. Sind alle markierten MIDI-Items bereits sichtbar, erfolgt kein Neuöffnen; ohne markierte Items bleibt die bisherige Editoransicht erhalten. Arrangement-Item-Auswahl, MIDI-Noten, CC, Anzeigequantisierung und Schlüsselwahlverfahren werden nicht geändert; keine Popups oder Konsolenausgaben.

**Beleg:** [GitHub Actions Run 41590754707](https://github.com/wibem1/Composition-Studio/actions/runs/41590754707), `success`, Lua-Syntax und **35/35 vollständige Offline-Mocktests**. Neue Fälle: fehlende markierte Takes werden gesammelt geöffnet, REAPER-native Editoroptionen verwendet, Item-Auswahl unverändert, erneuter Aufruf öffnet nichts doppelt, ohne Markierung wird die Editoransicht nicht umgestellt; anschließender Vier-Takte-Zoom bleibt erhalten. **Echter grafischer REAPER-Multitrack-Test noch nicht durchgeführt**. Das Öffnen per REAPER-Aktion hängt von lokalen Einstellungen und der konkreten Notations-Trackliste ab. Ohne diesen Echtbeleg keine endgültige Funktionsfreigabe.

**Nächster einzelner Schritt:** Mehrere MIDI-Items auf unterschiedlichen Tracks im Arrangement markieren, den Shortcut im geöffneten MIDI-Noteneditor einmal ausführen und prüfen, ob alle markierten Items untereinander angezeigt werden, ohne eine zweite Editor-Instanz oder ein Popup. Wenn eine Auswahl nicht sichtbar wird, reale Editor-/Tracklisten-Einstellungen gezielt diagnostizieren; keine unbelegten direkten Chunk-Manipulationen. `Notation Studio.lua` auf `main` bleibt unverändert.

## 03.11.2026 – Shortcut ohne Fenster und Konsolenausgaben

**Nutzerauftrag:** Das ReaScript soll bei jedem Shortcut-Aufruf ohne Popup, REAPER-Konsole, Bestätigungsfenster und Rückfrage laufen. Tatsächlich öffnete der vorherige `note()`-Logger per `reaper.ShowConsoleMsg` bei regulären Statusmeldungen die REAPER-Konsole; das widersprach dem Einmal-Shortcut-Konzept.

**Änderung:** Auf `feat/reaper-notation-one-shot-20261102` ist `note()` nun eine absichtlich stumme Funktion und der Quelltext enthält **keine** `ShowConsoleMsg`-Aufrufe mehr. Auch im Fehlerfall wird keine Konsole durch das Skript geöffnet. Kein UI-Dialog hinzugefügt; Zoom- und Schlüsselalgorithmus unverändert. Explizite Diagnose wäre bei Bedarf über ein separates, erst dann einzurichtendes Werkzeug möglich; dieses ist kein Teil des Shortcuts.

**Prüfung:** Die Regressionstests wurden so verschärft, dass jeder `reaper.ShowConsoleMsg`-Aufruf einen Testfehler auslöst. Der praktische REAPER-Test des vertikalen Zooms aus dem vorherigen Arbeitsschritt steht weiter aus; seine Wirkung wird durch die Entfernung der Ausgabe nicht als bestätigt gewertet. Keine Änderung an `Notation Studio.lua` auf `main`.

## 02.11.2026 – Automatischer vertikaler Zoom im Einmal-Skript (Testkandidat)

**Anforderung und bestätigter Praxisstand:** Der Nutzer hat Vier-Takte-Zoom und MIDI-basierte Notenschlüsselwahl im echten REAPER grundsätzlich als funktionierend bestätigt. REAPERs Seitenansicht füllt den Bildschirm zusätzlich mit leeren Takten hinter dem tatsächlichen Stückende; PDF- und MusicXML-Export enthalten diese überflüssigen Takte nicht. Vertikaler Zoom verdeckt sie nur, entfernt sie nicht. Die Oktavlagen der älteren MIDI-Datei sind ein separat behobenes Problem der LilyPond-App und hier kein Entwicklungsziel.

**Implementiert** auf `feat/reaper-notation-one-shot-20261102`, Draft-PR #7, in `REAPER Notation - 4 Takte und Instrumentenschluessel.lua`: Automatische vertikale Skalierung durch native MIDI-Editor-Aktionen `View: Zoom to content` (Ausgangslage) und eine begrenzte Zahl `View: Zoom in vertically`. Der alte Notation-Studio-Code 0.1.24 verwendet bereits die Zoom-in-Aktion, aber ohne geeignete Wiederholungslogik. Angepasste Zahl der Zoomschritte aus der Anzahl Takte der sichtbaren MIDI-Items / vier sowie der sichtbaren Spuren: 2–5 Schritte (bei vielen Spuren bis ein Schritt). `View: Zoom to project loop selection` wird bewusst zuletzt ausgeführt, damit das real bestätigte Vier-Takte-Verhalten erhalten bleibt. Keine Dialoge, MIDI-Notenänderungen, zusätzlichen Plugins oder Anzeigequantisierung. Falls native Zoom-Aktionen fehlen, wird der vertikale Zustand nicht verändert.

**Nachweis:** [GitHub Actions Run 41525473203](https://github.com/wibem1/Composition-Studio/actions/runs/41525473203) `success`; Syntax + **28/28 vollständige Lua-Mocktests** inkl. vertikalem Reset, erneuter identischer Zoomstufe bei wiederholtem Shortcut, anderen Item-Längen, fehlenden Aktionen, finalem horizontalem Vier-Takte-Zoom und vorheriger Schlüsselwahl/Proportionalanzeige. **Noch kein realer REAPER-Test des neuen Vertikalzoom-Verhaltens**; insbesondere ist ein eindeutiger vertikaler Reset durch `View: Zoom to content` im offenen Noteneditor noch zu bestätigen. Die API stellt keine dokumentierte exakte Notensystemhöhe oder Renderer-Fensterhöhe zur Verfügung; der Ansatz ist eine Näherung, kein pixelgenaues Einpassen der musikalischen Systeme.

**Nächster einzelner Schritt:** Mit dem aktualisierten Skript in REAPER Seitenansicht einmal starten, kontrollieren, ob größere Notensysteme erscheinen, Vier-Takte-Zoom erhalten bleibt und zwei aufeinanderfolgende Aufrufe dieselbe vertikale Größe ergeben. Bei fehlendem vertikalen Reset keine weiteren erratenen Aktionen; mit gezieltem Befund die Strategie korrigieren. `Notation Studio.lua` auf `main` bleibt unverändert.

## 02.11.2026 – Schlüsselsteuerung aus dem früheren Notation Studio übernommen

**Klarstellung des Nutzers:** Die Schlüsselwahl war bereits im bisherigen Notationsskript implementiert und nach seiner Erinnerung erfolgreich. Die mehrfachen Neuentwicklungen mit geratenen `SCORE`-Zahlen waren unnötig. Belegter Quellstand: `Notation Studio.lua` **v0.1.17**, Commit [4bd09ff](https://github.com/wibem1/Composition-Studio/commit/4bd09ffac5419740695f7d732020568dd2b13497), korrigierte numerische Schlüsselwerte; unverändert in **v0.1.24** auf `main` (Blob `48274e5767c8d756543bf7fa3a0b9108b639a272`).

**Technik aus dem Altbestand:** G-/Violinschlüssel `SCORE 0 1 0 0`, F-/Bassschlüssel `SCORE 0 2 0 0`, Alt-C `SCORE 0 3 0 0`, Tenor-C `SCORE 0 4 0 0`. Standard-Verfahren: vorhandene SCORE-Zeile im Track-State-Chunk ersetzen bzw. falls sie fehlt, nach der `VU`-Zeile einsetzen, dann `SetTrackStateChunk`. Diese Zuordnung **ersetzt** die zuvor fehlerhafte, um eins verschobene Zuordnung `grand=1,treble=2,bass=3,alto=4` des Einmal-Skripts. `grand` bleibt unberührt, weil die alte Methode hierfür bewusst keinen belegten numerischen SCORE-Wert verwendete.

**Aktuelle Implementierung:** Weiterhin auf Branch `feat/reaper-notation-one-shot-20261102`, Draft-PR #7. Neue musikalische MIDI-Hilfslinien-Analyse ist **vollständig unabhängig von Tracknamen**; Schlüssel-Schreibmethode und Werte wurden gezielt an v0.1.24 angeglichen. Unbekanntes SCORE-Format, mehrdeutige Tonlage, zu wenige Noten oder erforderliche zweizeilige Klaviernotation werden nicht überschrieben. Vier-Takte-Zoom und Proportionalanzeige bleiben unverändert, keine Quantisierung/Notenbearbeitung/Popup. Ausdrücklich kein ungeprüfter neuer Zahlenwert für das Klaviersystem.

**Objektiver Nachweis:** [GitHub Actions Run 41500680401](https://github.com/wibem1/Composition-Studio/actions/runs/41500680401) `success`: Lua-5.4-Syntax und **20/20 echte Quelldatei-Mocktests** bestanden (irreführende Namen haben keinerlei Wirkung, G/Alt/F anhand Noten, geringe und mehrdeutige Tonumfänge, Polyphonie, kein Grand-Schreibcode, unveränderte Proportionalanzeige/Zoom/Loop-Auswahl, originale SCORE-Werte und fehlende SCORE-Zeile nach `VU` eingefügt). Das belegt **noch nicht**, dass die laufende REAPER-Notationsengine die Schlüssel im offenen Editor grafisch übernimmt.

**Nächster einzelner Schritt:** Ein einziger Praxistest der aktualisierten Kurz-Skriptdatei an der vorhandenen REAPER-Testpartitur auf Projektkopie. Falls dort weiterhin die Schlüssel unverändert bleiben, den realen REAPER-SCORE-/Editor-Zustand diagnostizieren statt erneut an Werten zu raten. Produktivversion `Notation Studio.lua` auf `main` nicht verändert.

## 02.11.2026 – Einmal-ReaScript aktiviert zusätzlich proportionale Notenabstände

**Neue Nutzeranforderung:** Vorhandenes schlankes Shortcut-Skript um `Notation: Proportional (musical) note spacing` ergänzen. Keine zusätzliche Palette, keine Klicks, keine Darstellungsquantisierung, keine Änderung an Vier-Takte-Zoom und Schlüsselautomatik.

**Implementiert** auf `feat/reaper-notation-one-shot-20261102`, Draft-PR #7, Datei `REAPER Notation - 4 Takte und Instrumentenschluessel.lua`: Liest den Action-Toggle-Zustand über `GetToggleCommandStateEx(32060, cmd)`. Schaltet **nur** von eindeutig AUS (0) nach EIN; bei EIN (1) erfolgt keine Aktion. Bei unbekanntem Toggle (-1), fehlender Notationsaktion oder nicht bestätigter Aktivierung wird kein zweiter blinder Toggle ausgelöst, Fehler nur in REAPER-Konsole; der Vier-Takte-Zoom läuft trotzdem. Schlüsselwahl und Notenquantisierung nicht geändert. Wiederholte Shortcut-Ausführung lässt Proportionalanzeige aktiv.

**Prüfung:** [GitHub Actions Run 41497275745](https://github.com/wibem1/Composition-Studio/actions/runs/41497275745) `success`: Produktionsskript-Syntax und **16 von 16** Lua-Offline-Regressionen erfolgreich, u. a. AUS→EIN, bereits EIN bleibt EIN, unbekannter Zustand bleibt unverändert, fehlende Aktion blockiert Zoom nicht und nicht bestätigte Aktivierung führt zu keinem weiteren Toggle. Kein kostenpflichtiger API-Aufruf. **Kein echter REAPER-Grafiktest für diese neue Aktion**; bisher vom Nutzer real bestätigt nur der Vier-Takte-Zoom. Auch die zuletzt korrigierten Schlüsselwerte bedürfen weiterhin grafischer Bestätigung.

**Nächster einzelner Schritt:** Ein Test auf gesicherter REAPER-Projektkopie mit dem aktualisierten Shortcut. Kurz prüfen, ob die Proportionalanzeige eingeschaltet bleibt und die Schlüssel korrekt angezeigt werden; bei abweichendem Schlüsselbild echte REAPER-Daten erheben statt neue SCORE-Werte zu raten.

## 02.11.2026 – Reale Rückmeldung und Korrektur der Einmal-Notation

**Realer Anwenderbericht:** Das Einmal-Skript aus PR #7 zoomt nach Ausführung **erfolgreich auf vier Takte**. Die Schlüsselwahl ist **falsch**. Bestätigte Funktion (Zoom) unverändert lassen; Schlüsselwahl nicht als erfolgreich abnehmen.

**Ursache mit früherem realen Beleg:** Ein Nutzervergleich am 01.11. hatte gezeigt, dass `SCORE 0 4 0 0` im REAPER-Notation-Editor **Alt-C-Schlüssel** statt Treble erzeugt. Im neuen Skript wurde `4` dennoch irrtümlich wieder als Treble gesetzt und `2` als Bass, `3` als Alto. Das ist eine konkrete falsche Mapping-Tabelle, obwohl die Mocktests zuvor grün waren; diese testeten nur dieselbe falsche Annahme.

**Korrektur auf Entwicklungsbranch `feat/reaper-notation-one-shot-20261102`:** `grand=1`, `treble=2`, `bass=3`, `alto=4` (Reihenfolge der REAPER-Default-Clef-Auswahl; Alto=4 mit Nutzertest gestützt; Bass=3 und Treble=2 in der aktuellen Kombination noch **nicht** nachträglich grafisch bestätigt). Weiterhin ein einziger Shortcut ohne GUI/Rückfrage, keine Quantisierung, kein MIDI-Schreiben. Nach `SetTrackStateChunk` wird der Wert nun nochmals aus REAPER ausgelesen; Spur/Schlüssel/Wert und Fehler werden in der Konsole protokolliert. `MIDI_RefreshEditors` wurde bereits vorher auf sichtbare Takes angewendet; Zoom-Algorithmus unverändert.

**Prüfungen:** [GitHub Actions Run 41496467842](https://github.com/wibem1/Composition-Studio/actions/runs/41496467842) `success`: Lua-Syntax und 10/10 Mocktests erfolgreich (neue Tabelle, Zoom, Loop-Restore, Undo, Refresh, Idempotenz). **Keine** aktuelle reale REAPER-Kontrolle der korrigierten drei Schlüssel. `Notation Studio.lua` auf `main` unverändert; PR #7 bleibt Draft.

**Ein einziger weiterer sinnvoller Test:** In einer Projektkopie korrigierten Shortcut einmal ausführen, danach die tatsächlichen Schlüssel der drei Spuren betrachten. Wenn trotz im Chunk nachgewiesener Werte das Notenbild unverändert bleibt, liegt ein zusätzlicher REAPER-Refresh-/Chunk-Problem vor: echte RPP/SCORE-Information auslesen und spezifisch korrigieren, keine weitere numerische Blindsuche.

## 02.11.2026 – Einmal-Script statt Notation-Studio-Palette (neue Nutzerentscheidung)

**Neue verbindliche Anforderung:** Die bisherige ReaImGui-Bedienpalette ist für die Notations-Grundeinstellung unnötig kompliziert. Stattdessen EIN einfaches ReaScript, das nach einmaliger Shortcut-Zuordnung im MIDI-Editor **ohne Nachfrage** ausgeführt wird: aktuell sichtbare Instrumentensysteme erhalten passende Default-Clefs; die Notenansicht wird auf **vier vollständige Takte** ab Bearbeitungscursor gezoomt. **Keine** automatische Anzeigequantisierung, KI, Fenster, Buttons oder aufwendige Anwenderaktionen. Die alte Palette bleibt für andere Zwecke separat und unverändert, wird aber für diesen Workflow nicht mehr benötigt.

**Implementierung:** Branch `feat/reaper-notation-one-shot-20261102`, Draft PR #7 gegen `main`. Neues eigenständiges `REAPER Notation - 4 Takte und Instrumentenschluessel.lua`. REAPER-MIDI-Editor-`EnumTakes(...,false)` und deduplizierte Tracknamen, Instrument-Schlüssel-Tabelle, gezielter `SCORE`-Track-State-Eingriff nur auf einfache Zeilen, Einfügen der Zeile nur in sicheren TRACK-Header, Undo-Block, Aktualisierung von MIDI-Editoren; ein MIDI-Editor-Zoom auf vorübergehend gesetzte vier Takte umfassende Projekt-Loop-Auswahl (REAPER-Aktion `View: Zoom to project loop selection`), danach Wiederherstellung von Loop- und Zeitauswahl. Der Shortcut enthält keinen REAPER-Bestätigungsdialog, kein ReaImGui/SWS, keine MIDI-Note-on/off-Schreiboperationen und keine Quantisierung. Nicht erkannte Tracknamen werden übersprungen.

**Clef-Zuordnung:** Auf explizite Nutzerangabe `SCORE 0 4 0 0` für Violine/Treble; initiale Basistabelle `grand=1, bass=2, alto=3, treble=4`. **Achtung:** Zu `SCORE` gab es widersprüchliche ältere Praxisaussagen und keine vollständig dokumentierte REAPER-API. Bass/Alt-C-Mapping im realen REAPER noch ungeprüft. Diese Werte nicht als endgültig bewiesen kennzeichnen.

**Automatisierter Nachweis:** [GitHub Actions Run 41488463631](https://github.com/wibem1/Composition-Studio/actions/runs/41488463631) `success`: vollständige Lua-Syntaxprüfung; **10/10** Mock-Integrationstests bestanden (drei sichtbare Tracks, SCORE-Wert-Schreibvorgänge, ein Zoom-Command auf vier Takte, Rücksetzung von Loop-/Zeitauswahl, einmaliger Undo-Block, wiederholter Shortcut idempotent, unbekanntes Instrument bleibt unberührt). Keine kostenpflichtigen API-Aufrufe. [Kurzanleitung](docs/REAPER-NOTATION-SHORTCUT-4-TAKTE.md).

**Evidenzgrenze:** Kein echter Test dieses neuen Einmal-Skripts in REAPER 7.83 auf Mac/Windows; die visuelle Zuordnung der Notenschlüssel und die richtige Darstellung von vier Takten ist noch nicht bestätigt. **Keine Produktfreigabe/kein Merge**, nur isolierter Kandidat. Das Originalskript `Notation Studio.lua` v0.1.24 auf `main` bleibt unverändert.

**Nächster einziger Schritt:** Ein praktischer Kurztest auf gesicherter Kopie der bestehenden REAPER-Notation-8-Takt-MIDI; nach exakt einem Shortcut: G, Alt-C, F und Vier-Takte-Zoom kontrollieren. Bei Abweichung echte Werte ermitteln und einmal gezielt korrigieren, nicht weitere Blindexperimente.

## 02.11.2026 – Vollständige statische Bestandsaufnahme Notation Studio v0.1.24

**Nutzerentscheidung:** Das vorhandene Native-REAPER-Notation-/Notation-Studio-Skript wird **weiterentwickelt, nicht ersetzt**. Das Grundkonzept der direkt mit dem REAPER-MIDI-Noteneditor verbundenen ReaImGui-Palette inklusive KI-Anbindung bleibt erhalten. Der Nutzer berichtet, dass `Lesbarkeit verbessern` die Lesbarkeit verschlechtert.

**Quellprüfung:** Aktuelle Datei `Notation Studio.lua` v0.1.24 auf `main`, 729 Zeilen, 38 lokale Funktionsdefinitionen, Blob `48274e5767c8d756543bf7fa3a0b9108b639a272`. Vollständiger Bericht: [docs/NOTATION-STUDIO-0.1.24-CODE-AUDIT-2026-11-02.md](docs/NOTATION-STUDIO-0.1.24-CODE-AUDIT-2026-11-02.md). Quellcode, bestehende Notationsberichte und Anforderungen geprüft, keine neue REAPER-Laufzeitprüfung.

**Kernbefunde:** `cleanup_notation()` ist eine unkontrollierte Kombination von neun Einstellungen/Zoom-/Schlüsselmaßnahmen ohne musikalische Analyse, sichere Rücknahme oder garantierte Wirkung. Zusätzlich: unscharfe Aktionsauswahl, fehlende Behandlung unbekannter Toggle-Zustände, undokumentiertes `SCORE`-Chunk-Schreiben, problematische ImGui-Begin/End-Paarung, veralteter MIDI-Editor-Zeiger, nur heuristische Zoom-/Instrumentenwahl. KI sendet ausgewählte Noten an Anbieter und zeigt Text, **ändert keine Noten**; Provider-/Modellwahl in dieser Palette fehlt, Artikulation/Dynamik/SWAM-Gruppen sind nur Platzhalter. Update-/KI-Transporte benötigen robuste Plattform-, Fehler- und Sicherheitsbehandlung. Im Code werden keine direkten Note-on/off-Schreibfunktionen aufgerufen; unerkannte native REAPER-Aktionen sind trotzdem nicht automatisch sicher.

**Evidenzgrenze:** Alle neuen Ergebnisse sind statisch geprüft, nicht in der laufenden REAPER-Anwendung getestet. Keine neue Skriptversion, keine Programmänderung, kein kostenpflichtiger KI-Aufruf, keine GitHub Actions. `main`-Quellcode v0.1.24 bleibt unverändert.

**Nächster EINZELNER Entwicklungsschritt:** Lesbarkeitsfunktion isoliert entschärfen und mittels Mock-/Regressionstests absichern: sichere Action-Auflösung/Toggle-Behandlung, keine automatische `SCORE`-Chunk-Mutation, kein mehrfacher Zwangszoom, stabile ImGui-Begin/End-Paarung und gültigen Editorhandle beachten; danach **ein** gezielter Vorher-/Nachher-Praxistest (ggf. eine fokussierte Nachprüfung) ohne MIDI-Event-Änderungen. Umsetzung erst auf separatem Branch, v0.1.24 als unveränderte Referenz.

## 02.11.2026 – Schnittstellenprüfung: Welche Notationsanweisungen kann REAPER wirklich umsetzen?

**Anlass:** Der Nutzer weist zutreffend darauf hin, dass vor einer musikalischen Vorinterpretation zunächst genau geklärt sein muss, welche **Steuerungsmöglichkeiten und -grenzen** REAPERs interne Notationsengine hat.

**Neu erstellt:** [docs/REAPER-NOTATION-STEUERBARKEIT-2026-11-02.md](docs/REAPER-NOTATION-STEUERBARKEIT-2026-11-02.md). Quellgrundlage: REAPER User Guide v7.84 Kap. 14.5–14.9, offizielle ReaScript-API aus REAPER v7.83, ReaTeam/juliansader-Skripte, eigener `Notation Studio.lua` v0.1.24.

**Technisch abgesicherte Erkenntnisse:**
- **GUI-seitig belegbar:** Displayquantisierung und Mindestnotenlänge pro Track / Projekt, Default- und Wechsel-Schlüssel, High-/Low-Stimmen, Beaming / Tie-Minimierung, auto triplet, proportional spacing, MIDI-Trackliste und mehrspurig continuous layout.
- **ReaScript-seitig belegt:** Aufruf von MIDI-Editor-Aktionen, Steuerung der Editor-Horizontal-Skalierung (`pixels_per_timebase_unit`), Zugriff auf Takes/Tracks/MIDI-Events und Notationsmetadaten Typ 15, z. B. individuelles `disp_len` (als Offset zur MIDI-Länge), gespeicherte `staff`-/`voice`-Metadaten. **Keine** in `MIDIEditor_SetSetting_int` dokumentierte direkte pro-Track-Quantisierung/Schlüssel-Setter; native Aktionen/Chunk-Hacks sind nicht gleich verifizierte dauerhafte Steuerbarkeit.
- **Nicht direkt steuerbar:** Erzeugte grafische Pausen einzeln entfernen, horizontalen Engraving-/Kollisionsalgorithmus mit beliebigen X-Werten ersetzen, beliebige Mehrspur-Systemumbrüche durchsetzen; daher kein blindes Versprechen für Ziele 1/2.
- **Neue wichtige Sicherheitseinschränkung:** Manuell angelegte/edierte Tuplets können laut Handbuch echte MIDI-Note-On-/Note-Off-Positionen verändern! Nur automatische Anzeigeerkennung für unverändertes MIDI zulassen, ohne ausdrückliche Zustimmung zum echten Edit.
- **Eigene bekannte Problemstellen:** `cleanup_notation()` benutzt unscharfe Action-Textsuche, unterscheidet unbekannte Toggle-Zustände teilweise nicht, schreibt `SCORE` über undokumentierten Track-Chunk und beeinflusst keine internen Glyph-/Abstandsberechnungen.

**Entscheidung:** Die Notations-Vorinterpretation ist **bedingt technisch plausibel**, nicht bewiesen. Vorerst Dokumentation statt neuer Code; bei Umsetzung höchstens ein gebündelter kontrollierter REAPER-Praxistest der acht Takte (plus höchstens eine Nachprüfung); keine Serie manueller Experimente.


## 02.11.2026 – Kontrollierte 8-Takt-Referenz-MIDI erzeugt und offline geprueft

**Ausloeser:** Nutzer schlaegt statt zufaellig gewaehlter Musik eine gezielt aufgebaute Test-MIDI-Datei vor, um die vier Kriterien ohne lange Testserie objektiv zu pruefen.

**Konkretes Artefakt (Chat):** `REAPER_Notation_Gezielter_Machbarkeitstest_8_Takte.mid`, MIDI SMF Type 1, PPQ 960, g-Moll, 4/4, 96 BPM, 8 Takte, 1451 Byte, SHA-256 `f55ec9c9f2d8a18174959ef7acdfcb4e703a9fe69c657d5d0bf2d49de638fbbf`, 3 Instrumentalspuren mit 117 Noten: Violine (62, G-Schluessel), Bratsche (36, Alt-C-Schluessel), Violoncello (19, F-Schluessel), plus eine Metaspur. Dazu wurden `REAPER_Notation_Testanleitung.txt` und `REAPER_Notation_Testreferenz.json` erstellt; ein ZIP-Gesamtpaket `REAPER_Notation_Machbarkeitstest_Komplettpaket.zip` liegt ebenfalls im Chat.

**Testfaelle:** Takte 1–2 exakt gerasterte Kontrolle; 3–4 **exakt dieselben Onsets/Tonhoehen**, aber MIDI-Note-offs um 1–55 Ticks frueher (bewusst kunstliche Minipausen); 5–6 echte Achtel-/Sechzehntel-/Viertelpausen, die **nicht** entfernt werden duerfen; 7 exakt 320-Tick-Achteltriolen und leicht humanisierte Viola-Onsets; 8 echte Polyphonie in Violine/Bratsche. Bewusst ein *einziger* 8-Takt-Datensatz fuer alle vier Ziele.

**Nachweise:** Die erzeugte MIDI-Datei wurde unmittelbar mit einem getrennten mido-Datei-Parser wieder eingelesen; alle 117 Noten, ihre Start-/Endzeiten, Tonhoehen, Anschlagsstaerken und die spezifischen 1–55-Tick-Luecken, 320-Tick-Triolen und ueberlappenden Stimmen wurden gegen die vorgabeseitig gebildete Goldstandard-Referenz geprueft. Ebenso wurde ZIP-Integritaet/Dateigleichheit geprueft. **Dies belegt nur MIDI-Dateistruktur und Testfaelle, keinen REAPER-Grafiktest und noch keine Verbesserung.** Standard-MIDI speichert Schluessel nicht verbindlich; Zuordnung muss im nativen REAPER-Editor erfolgen.

**GitHub-Dokumentation:** [tests/fixtures/reaper-notation/README.md](tests/fixtures/reaper-notation/README.md) enthaelt Kurzspezifikation, Sollbedingungen, Pruefstatus und SHA. Die MIDI-Binaerdatei/JSON sind weiterhin **nur Chat-Artefakte**, nicht ins Repo hochgeladen. **Keine Veraenderung an Notation Studio 0.1.24, keine neue App-Version, kein Nutzer-Praxistest.**

**Naechster Schritt:** Die vier eigentlichen Darstellungsalgorithmen/Notationsmetadaten gegen diese kontrollierten Faelle offline absichern und erst danach **einen** gebuendelten REAPER-7.83-Praxistest fuer die native Notation organisieren. Keine neue Testserie.


## 02.11.2026 – Verbindliche Testdisziplin: Keine Testserien beim Nutzer

**Nutzerentscheidung:** Zur Ermittlung der REAPER-Notationsmachbarkeit und zu einer eventuellen kleinen Implementierung darf kein Prozess mit Dutzenden manuellen Versuchen und immer neuen Testpaketen entstehen. Der Assistent organisiert Quellenanalyse, präzise Hypothesen und sichere automatisierte Offline-Pruefungen; der Nutzer soll nur fuer die wenigen unvermeidbaren Beobachtungen der **echten REAPER-Notationsoberflaeche** einbezogen werden.

**Vorgehensweise ohne neue Entwicklungsfreigabe:**
1. **Vollstaendige Vorarbeit vor einem Praxistest:** Dokumentierte ReaScript-Metadaten (`disp_len`, `voice`, `staff`), gebundene Anzeigeaktionen und konkrete Auswirkung auf einen klein gewaehlten Problemfall abgleichen. Proprietäre Implementierungsdetails von REAPER-Notator nicht kopieren; sein öffentlich beschriebenes Funktionsprinzip darf nur als Ausgangspunkt fuer eine unabhängige Architektur dienen.
2. **Offline-Checks selbst:** An vorhandener Test-MIDI mit Fallbeispielen für Tiny-Gaps, echte Pausen, Polyphonie, Triolen und Instrumentenzuordnung Verhaltensmodell/Regeln pruefen. Statische Lua-Prüfung, deterministische Unit-/Mocktests, Beweis dass Note-on/-off, Velocity, CC und Tempo unberührt bleiben. Diese Tests beweisen **nicht** die reale grafische Wirkung des eingebauten REAPER-Editors.
3. **Höchstens ein gebündelter erster Nutzer-Praxistest:** Ein vorbereitetes, unverändertes/gesichertes REAPER-Projekt und ein kurzer konkreter Vorher-/Nachhervergleich im nativen Notationseditor mit den vier Qualitaetsmerkmalen. Bei Bedarf nur **eine weitere gezielte Nachprüfung** fuer eine klar benannte Ungewissheit; keine offene Folge neuer Testversionen. Laufzeit-/Plattformtests können nicht allein aus Lua-Mocks als nachgewiesen bezeichnet werden.
4. **Stopregel:** Nach spätestens zwei gezielten fehlgeschlagenen realen Versuchen keine neue Paketserie; technische Grenzen anerkennen und vorhandene Alternativen empfehlen bzw. REAPER-API-Grenze dokumentieren. `main` und der letzte bestaetigte Stand bleiben unangetastet, bis Tests gelingen.

**Status:** Nur Prozess-/Qualitaetsentscheidung dokumentiert, keine Softwareaenderung, keine neue Version, kein REAPER-Echttest. Entwicklungsrichtung weiterhin: musikalische Analyse -> native REAPER-Notationseigenschaften, nie eigenes Notenfenster.


## 02.11.2026 – Sieben ReaTeam-Notationsskripte vollständig quellengeprueft, Wiederverwendungskonzept

**Benutzerauftrag:** Zunaechst recherchieren und eine belastbare Uebersicht erstellen, **welche Teile welcher bereits existierenden Entwicklungen** unsere vier Ziele im nativen REAPER-Noteneditor unterstuetzen und wo konkrete Modifikationen erforderlich waeren. **Keine neue Testversion und keine Softwareprogrammierung.**

**Neuer Recherchebericht:** [docs/REAPER-NATIVE-NOTATION-REUSE-AUDIT-2026-11-02.md](docs/REAPER-NATIVE-NOTATION-REUSE-AUDIT-2026-11-02.md), anhand der **Quelltexte aller sieben** `js_Notation`-Skripte unter `ReaTeam/ReaScripts/MIDI Editor/` inkl. Git-Blob-SHAs, REAPER-Handbuch 7.84 und `Notation Studio.lua` 0.1.24. Einzelne Skripte gelten nicht als nachweislich an der Nutzer-Orgel getestet.

**Prioritaeten:**
- **A / zentral:** `Set displayed length ... custom value` (Notationsmetadata `disp_len` als Delta gegen originale MIDI-Laenge, Reset vorhanden); `Select all notes that have customized display lengths or positions` (Audit von `disp_len`, `disp_pos`).
- **A/B / relevant:** `Set beaming ... custom rhythm` (manuelle rhythmische Balkengruppen, aktuelle Selection zurueckstellen und Takt-/Stimmenkontext beachten).
- **B / Diagnose:** `Select notes by notation keywords` (vorhandene Staff-/Voice-Metadaten, keine eigene Stimmtrennung).
- **C / redundant bzw. eingeschraenkt:** `Select notes by user-supplied notation text` (weitgehend alternative Variante, nutzt aeltere Take-Ermittlung); `Set display length ... double + staccato` und `... quadruple + staccatissimo` (fuer musikalisch echte kurze Artikulation, nicht fuer pauschale Orgel-Legato-Mikroluecken; ueberschreiben vorhandene Artikulation).
- **Keines der sieben** ersetzt REAPERs horizontalen Engravingalgorithmus oder erzeugt automatisch Instrumentenzeilen; hier sind nur native REAPER-Funktionen/Track-Profile relevant.
- Drei getrennte nutzbare Ansatzgebiete: native Darstellungsprofile, punktuelle `disp_len`-Korrektur mit Audit, optionale Beaming-Gliederung; dazu native Track-/Clef-Zuordnung. Der **fehlende, riskante Baustein** waere musikalische Erkennung unnoetiger Kurzpausen je Stimme.
- **Lizenzvorsicht:** Der gepruefte Upstream `ReaTeam/ReaScripts`-Root enthaelt keine globale LICENSE-Datei, in den sieben Script-Headern keine explizite Lizenz. Vor Quellcode-Copying/Weiterverteilung Rechte klaeren; unabhängige ReaPack-Installation oder eigene Implementierung nur anhand dokumentierter ReaScript-APIs als Zwischenweg.

**Urteil:** Begrenzte Verbesserung des eingebauten Editors ist plausibel, **nicht bewiesen fuer alle vier Ziele zusammen**. Der bestehende Problemfall muss mit einem einzigen reversiblen `disp_len`-Eingriff die Wirkung im **echten** REAPER nachweisen, bevor automatisierte Pausenbearbeitung sinnvoll ist. Kein neues Fenster, kein Notator-Nachbau. Projektcode, Nutzer-MIDI und aktive App unveraendert; nur Dokumentation geaendert.


## 02.11.2026 – Machbarkeitsbewertung: Vier REAPER-native Notationsziele NICHT bereits erreicht

**Nutzerfeedback:** Die fruehere Schaltflaeche `Lesbarkeit verbessern` und unsere ersten Konfigurationsversuche haben Notenabstaende, Minipausen, Darstellung und Instrumentenzeilen **nicht gemeinsam auf ein arbeitsfaehiges Niveau** gebracht. Das ist als negatives reales Ergebnis zu respektieren. Keine erneute Schleife der bekannten Sammelaktion.

**Quellen:** Aktuelles offizielles REAPER-Handbuch v7.84 (Nov. 2026) als HTML https://dlx.reaper.fm/userguide/html/, Kapitel 14.5–14.7, aktueller `Notation Studio.lua` v0.1.24 auf main sowie bestehendes ReaTeam-/juliansader-Skript `js_Notation - Set displayed length of selected notes to custom value.lua` auf https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Set%20displayed%20length%20of%20selected%20notes%20to%20custom%20value.lua.

**Einzelurteil:**
1. Notenabstaende: bedingt machbar durch REAPER `Proportional (musical) note spacing` und Zoom; keine bekannte ReaScript-Steuerung des internen Kollision-/Engravingalgorithmus, Erfolg bei dichter Mehrstimmigkeit offen.
2. Minipausen: **groesstes technisches Risiko**. Display quantization/minimum note length ist KEIN allgemeines musikalisch intelligentes Pausenkorrekturwerkzeug. Gezielte visuelle Notenlaengen-Aenderungen per `NOTE ... disp_len` sind durch existierendes ReaTeam-Skript real belegt und reversibel. Nur optische Darstellung, aber Metadaten im MIDI-Take werden geaendert; unveraenderte Note-on/-off-Ereignisse/Wiedergabe sind Bedingung. Bei mehreren Stimmen muss vorher die musikalische Zugehoerigkeit der kurzen Luecke klar sein.
3. Displayquantisierung: REAPER nativ und je Track vorhanden; MIDI-Performance bleibt bei reiner Anzeigequantisierung unveraendert. Technisch machbar, richtige Rasterwahl bei Triolen/kurzen Noten individuell.
4. Separate Notenzeilen und Schluessel: REAPER kann mehrere MIDI-Tracks mit je eigenem `Default clef` darstellen. Wichtige Grenze: Bei mehr als einem sichtbaren Track erfolgt nur horizontale kontinuierliche Ansicht, keine mehrzeilige Satzseite.

**Entscheidung:** Einfache und maessig polyphone Arbeitsnotation erscheint technisch plausibel, aber weder fuer dichte Orgelpolyphonie noch fuer alle vier Anforderungen gleichzeitig bisher nachgewiesen. Keine neue Version/keine neue App/kein weiterer Renderer. **Einzig sinnvoller naechster Test:** einmaliger enger Wirkungsnachweis der bestehenden `disp_len`-Funktion an einer problematischen Kurzpausenstelle der echten REAPER-Notation, mit Vorher/Nachher-Bild und identischen Note-on/-off-Ereignissen, reversibel und auf Kopie. Gegebenenfalls danach die dreispurige Ansicht gegenpruefen. Scheitert dies, ausdruecklich No-Go fuer weitere Eigenautomatik ohne neue REAPER-Schnittstelle und Nutzung bereits fertiger Alternativen erwägen.

**Ausfuehrlichere technische Einordnung:** `NOTATION-MODULE.md`, `Technische Machbarkeit der vier Ziele – 02.11.2026`. Stand ausschliesslich Quell-/Handbuchanalyse, KEIN neuer realer Nutzer-Praxistest.


## 02.11.2026 – Vier konkrete Qualitätskriterien vom Nutzer festgelegt

**Verbindlicher Schwerpunkt:** (1) Optimierung musikalischer Notenabstände, (2) Beseitigung **unsinniger** Minipausen bei Erhalt echter Pausen, (3) reine Displayquantisierung unabhängig von MIDI, (4) separate Notensysteme/Notenzeilen mit zum Instrument passenden Schlüsseln. Konkretisiert im dauerhaften `NOTATION-MODULE.md` unter `Vier verbindliche Qualitätsanforderungen – 02.11.2026`.

**Machbarkeitsbelege aus REAPER-Handbuch:** Proportional musical note spacing; Display quantization + Minimum note length getrennt von MIDI; mehrere sichtbare MIDI-Tracks als getrennte Notenzeilen; `Default clef` je Track/Staff. Mehrere gleichzeitig sichtbare Tracks erzwingen eine kontinuierliche links-rechts Notationsansicht; mehrzeilige Seitenansicht gilt nur beim einzelnen Track. Das ist eine reale Layoutgrenze, die wir mit dem Nutzer abgleichen muessen. Bereits vorhandenes `Notation Studio.lua` v0.1.24 bietet mehrere Aktionen, nicht jedoch einen verifizierten automatischen 4-Punkte-Modus.

**Erster Test:** Native REAPER-Notation der Orgelphantasie mit getrennten sichtbar geschalteten Spuren Manual I/II und Pedal, geeigneten Schlüsseln, proportionalem musikalischem Spacing und **nur** einer vorsichtigen Displayquantisierungs-Testeinstellung (z.B. 1/16, Mindestnotenlänge 1/32). Bildvergleich derselben Takte mit Originalansicht. Keine MIDI-Event-Bearbeitung, keine neue Version, kein eigener Renderer, kein Start von CI- oder API-Tests. Entscheidung erst nach sichtbarer REAPER-Praxis.


## 02.11.2026 – Erste Bestandsaufnahme REAPER-nativer Notationsfunktionen (ohne neuen Code)

**Nutzerziel bestaetigt:** Herausfinden, wie viel sich aus dem **vorhandenen REAPER-Noteneditor** als tatsaechlich lesbare Arbeitsnotation herausholen laesst. Vor Eigenentwicklung und weiteren Releases steht ein begrenzter A/B-Vergleich.

**Quellen:** REAPER User Guide Notation Editor Kapitel 14.5–14.8 (Cockos, https://www.reaper.fm/userguide.php; untersuchte Anleitung u.a. v7.40/v7.50), aktuelles Repository `Notation Studio.lua` v0.1.24 (main, Blob `48274e5767c8d756543bf7fa3a0b9108b639a272`).

**Native REAPER-Funktionen belegt:** proportional (musical) note spacing; Anzeigequantisierung (1/8, 1/16, 1/32, 1/64); Mindestnotenlaenge der Anzeige getrennt vom MIDI-Timing; automatische Erkennung von Triolen, automatische Stimmenzuordnung ueberlappender Noten, Optionen zur Minimierung von Bindungen und rhythmischer Balkensetzung; zoombare/mehrzeilige Darstellung und gezielte Notations-Eigenschaften. Reine Anzeigequantisierung/Mindestlaenge beeinflussen MIDI-Tonereignisse laut REAPER-Handbuch nicht.

**Kritischer Codebefund:** `Notation Studio.lua` besitzt den Button `Lesbarkeit verbessern`, dessen Funktion `cleanup_notation()` bereits ein Paket aus Anzeigeaktionen, Triolenerkennung, automatischer Voice-Umschaltung, Skalierung und Schluesselzuordnung ausfuehrt. **Nicht unkritisch einsetzen**: `set_default_clef_chunk()` ruft `GetTrackStateChunk` und `SetTrackStateChunk` auf, setzt bzw. ersetzt darin `SCORE`-Metadaten, also mehr als bloss den Zoom. Zudem aktiviert die Sammelfunktion ausnahmslos die Triolenerkennung und setzt die Mindestnotenlaenge 1/64, auch wenn das im konkreten Beispiel ggf. unerwuenschte winzige Notenreste sichtbar laesst. Der Button ist **nicht als harmloser A/B-Anzeigeschalter freigegeben**. Vermeide auch `Quantize MIDI notes`, `Correct overlapping notes` als Bearbeitung der eigentlichen Events.

**Empfohlene Testreihenfolge, klein und nachvollziehbar:** Die vorhandene REAPER-Orgelpartitur ist bereits als problematischer Lesbarkeitsfall im Nutzer-Screenshot dokumentiert. In Kopie des Projekts, **im nativen Noteneditor**, zuerst identischen 4-Takt-Ausschnitt anzeigen; dann `Proportional (musical) note spacing` EIN und Displayquantisierung 1/16, Mindestnotenlaenge probeweise 1/32 statt 1/64 vergleichen (nur wenn keine musikalischen 1/64-Noten vorliegen). Weitere aendernde Optionen wie automatische Stimme, Schluessel, Noten-Offsets erst nach diesem reinen Anzeigetest isoliert pruefen. Mit A/B-Bild und ggf. MIDI-Hash/Notenvergleich beurteilen. Nicht mit unserem experimentellen ReaImGui-Fenster verwechseln.

**Stand:** Dokumentations-/Code-Audit, KEIN Realtest dieser Einstellungskombination, keine neue Version, kein produktiver Code geaendert. Nächster Schritt ist genau **ein** A/B-Vergleich am echten REAPER-Notenbild; danach die konkrete darstellungsbedingte Engstelle priorisieren.


## 02.11.2026 – Verbindliche Prioritaet: Bestehenden REAPER-Noteneditor brauchbar machen (kein neuer Renderer)

**Entscheidung des Projektinhabers:** Zuerst klären, ob der bereits in REAPER 7.83 vorhandene Notationseditor mit vertretbarem Aufwand eine **hinreichend lesbare und korrigierbare Arbeitsnotation** liefern kann. Kein Nachbau von REAPER-Notator, kein monatelanges Eigenrendering, kein Anspruch an perfekte Druckpartitur. Ein erfolgreiches Ergebnis braucht nachvollziehbare Rhythmen und Stimmen, ausreichende Abstaende und unveraendertes MIDI.

**Korrektur bisheriger Entwicklungsrichtung:** Separater ReaImGui-Score-Preview `feat/notation-score-preview-20261101`/Draft PR #4 (v0.2.0–0.2.3-test) als Entwicklungsweg **angehalten/verworfener Ansatz**. Nach Nutzer-Screenshot war v0.2.2 zwar als eigenes Fenster unter Windows real sichtbar, aber noch kein brauchbarer Notensatz. Diese experimentellen Dateien werden nicht nach `main` uebernommen. GPL-Engraver-Audit `feat/notator-gpl-rhythm-audit-20261101`/Draft PR #3 bleibt isoliert; keine Entwicklungsverpflichtung, ihn zu einem Ersatzeditor umzubauen.

**Aktuelle Codebasis auf `main` (geprüft, nicht erneut unter Windows freigegeben):** `Notation Studio.lua` v0.1.24, Git-Blob `48274e5767c8d756543bf7fa3a0b9108b639a272`. Bereits implementiert sind REAPER-Aktionsaufrufe zur `Proportional (musical) note spacing`, Displayquantisierung 1/8–1/32, Zoom, Auswahl/Inhalt einpassen und `Lesbarkeit verbessern` inkl. Aktionen fuer Anzeige- und Mindestnotenlaengen. Das sind wichtige bestehende Ausgangspunkte, keine Garantie fuer die grafische Wirkung.

**Naechster einzelner Schritt:** Ein kurzer A/B-Machbarkeitstest auf denselben 2 exemplarischen Ausschnitten (eine Solo-/Melodiepassage, eine mehrstimmige Passage) **in REAPERs eigenem MIDI-Noteneditor**, mit geprueften Einstellungen fuer Darstellung/Abstand/Stimmen. Dokumentiere nur sichtbare Vorher-/Nachher-Verbesserung und unveraendertes MIDI. Danach Go/No-Go. **Keine neue Softwareversion, kein neues Testfenster** vor dieser sachlichen Entscheidung.

**Dauerhaftes Pflichtenheft und durch fruehere Architekturabschnitte nicht mehr aufgehobene Vorgabe:** `NOTATION-MODULE.md`, Abschnitt `Verbindliche Zielkorrektur – 02.11.2026`. Code oder bestehendes Benutzerprojekt wurde nicht veraendert.

Stand: 23.10.2026 · Übernahme des allgemeinen Entwicklungsstandards (Dokumentationsänderung)

## Projekt und belegter Dokumentationsstand
Kompositions-/Bearbeitungsebene in REAPER; README dokumentiert v1.1.6 vom 19.10.2026 als TEST CANDIDATE.
Diese Angaben basieren auf den verfügbaren Projektinformationen; bei dieser Umstellung wurden **keine** aktuellen End-to-End-Tests, Releases oder CI-Artefakte geprüft.

## Globale Regeln
https://github.com/wibem1/AI-Development-Standards/blob/main/DEVELOPMENT_STANDARDS.md

## Nächster Schritt
Vor erneuter Entwicklung Branch, letzten Commit, offene Aufgaben und reale Testnachweise ermitteln. Genau einen kleinen nachprüfbaren Arbeitsschritt auswählen. Bestätigte Testergebnisse mit Quelle/Version hier nachtragen. Bis dahin ist die aktuelle Gesamtfunktion **nicht neu verifiziert**.
