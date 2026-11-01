# Notation Studio – Notenbild-Test 0.2.3 (experimentell)

## Sichtbarer Echtlauf und Korrektur 0.2.3 (02.11.2026)

REAPER 7.83 Windows hat 0.2.2 **real gerendert**, jedoch nur mit einem selektierten Item (Church Organ, 759 Noten). Noch keine Aussage zur Darstellung aller drei Orgelspuren.

0.2.3 verbessert gezielt die Tonhoehen- und Akkorddarstellung: Eb-Schreibweise korrigiert, g-Moll-Vorzeichnung (Bb/Eb) statt permanent wiederholter Vorzeichen, gleichzeitige Toene mit einem vereinfachten gemeinsamen Notenhals, Spurbezeichnung oberhalb der Linien, Anzeigehinweis bei nur einem ausgewaehlten Item.

**Test:** [GitHub Actions 41361239737](https://github.com/wibem1/Composition-Studio/actions/runs/41361239737) erfolgreich (Core/G-Moll/Chord-Tests und REAPER-ImGui-Mock). Die 0.2.3 selbst ist **noch nicht** unter echtem Windows-ReaImGui grafisch bestaetigt. Im neuen ZIP die beiden Lua-Dateien im selben Ordner halten und das neue Skript als neue REAPER-Aktion laden; im Fenstertitel `0.2.3 TEST` kontrollieren.

**Keine Vollpartitur:** Clefs sind weiterhin G/F-Platzhalter, keine polyphonen Stimmen, Balken, Pausen/Bindungen oder automatische Tonart/Taktart; feste Testtonart g-Moll. Die Daten werden unveraendert gelesen. Hauptprogramm unberuehrt.



## ReaImGui Windows-Korrektur 0.2.2 (01.11.2026)

Die reale REAPER-Windows-Version 0.2.1 schlug mit `ImGui_EndChild: Assertion failed: child_window->Flags & ImGuiWindowFlags_ChildWindow` fehl. Die urspruengliche Fenster-Verschachtelung wurde entfernt; die Partitur wird **direkt im Hauptfenster** gezeichnet, `ImGui_Dummy` reserviert die Zeichenflaeche. Neue Tests verbieten Child-Window-Aufrufe und validieren zwei aufeinanderfolgende balancierte GUI-Frames. [CI erfolgreich](https://github.com/wibem1/Composition-Studio/actions/runs/41360686013). **Echter Windows-Praxistest dieser Korrektur steht noch aus.**

Das vollstaendige Testpaket `Notation_Studio_Notenbild_Test_0.2.2_Windows.zip` enthaelt Hauptscript, unveraenderten Core und eine Startanleitung. Beide Lua-Dateien in einen Ordner entpacken und **das Skript aus diesem Ordner** als neue REAPER-Aktion laden. Im Fenstertitel muss `Notenbild 0.2.2 TEST` stehen.



## Windows-ReaImGui-Startkorrektur (0.2.1-test, 01.11.2026)

**Echter Nutzer-Praxistest:** Unter REAPER 7.83/x64/Windows bricht der Score-Preview bei `Notation Studio - Notenbild Test.lua:189` ab: `bad argument #5 to 'ImGui_BeginChild' (number expected, got boolean)`. Das native REAPER-Notenbild im Hintergrund ist **nicht** unsere Score-Vorschau.

**Ursache und Fix:** Version 0.2.0-test rief `r.ImGui_BeginChild(ctx,'score_canvas',0,height,true)` auf und uebergab ein altes `bool border` als 5. Parameter. Laut offizieller ReaImGui API Version 0.9+ hat `BeginChild` die Signatur `(ctx,id,size_w,size_h,child_flags:int,window_flags:int)`; die neue `0.2.1-test` verwendet numerische Flags `1,0` (Borders, keine WindowFlags). Fenster- und Versionsbeschriftung tragen `0.2.1 TEST`, damit alte REAPER-Aktionen erkennbar bleiben.

**Testfaehigkeit verbessert:** Der Simulations-Mock prueft jetzt Argumenttypen und den Zahlenwert der ChildFlags, sodass der vorherige Fehler reproduzierbar als fehlgeschlagener Test erfasst wird. Syntax/Core/GUI-Simulation liefen unter Lua 5.4 in GitHub Actions [41359544245](https://github.com/wibem1/Composition-Studio/actions/runs/41359544245) mit Status **success**. Die beiden Lua-Dateien der aktualisierten ZIP `Notation_Studio_Notenbild_Test_0.2.1_Windows_Fix.zip` wurden ueber Git-Blob-SHA mit den aktuellen GitHub-Quelldateien abgeglichen.

**Noch offen:** Echtlauf der gefixten 0.2.1 unter Windows REAPER, Bildqualitaet/Notationsvaliditaet. Noch keine neue Produktversion/kein Release, keine MIDI-Aenderung.


**Status:** Sichtbarer, eigenständiger REAPER-ReaImGui-Testkandidat; keine veröffentlichte Hauptprogrammversion. `main`, `Notation Studio.lua` v0.1.24 und die vorhandene Updatefunktion bleiben unverändert. Keine Integration in den GPL-Notator-Branch oder Nutzung seines Quellcodes.

## Ausführen

1. ReaImGui in REAPER installieren; ist Voraussetzung wie für Notation Studio.
2. Die beiden Lua-Dateien aus diesem Ordner **unverändert nebeneinander** lokal ablegen.
3. Im Arrangement die zusammengehörigen MIDI-Items auswählen (für Orgel: Manual I / Manual II / Pedal). Ein MIDI-Item genügt für einen Einzeltest.
4. Über REAPER-Aktionsliste (Taste `?`, Sektion Main) → New Action → Load ReaScript → `Notation Studio - Notenbild Test.lua` öffnen und starten.
5. Das eigene Notenfenster zeigt die ausgewählten Noten; per Buttons durch Takte blättern, Zoom, 4/4/3/4 und Anzeige 1/16/1/32 vergleichen. Auswahl neu einlesen bei Änderung.

## Umfang und Einschränkungen

- Liest ausschließlich REAPER MIDI-Items und zeichnet Notenlinien, vereinfachte Notenköpfe, Vorzeichen, Notenlängen-Indikatoren, Taktstriche und Hilfslinien. Erste Spur standardmäßig Violinschlüssel-Skala, weitere Bassschlüssel-Skala.
- Keine echte mehrstimmige Notationsengravur, keine vollständige Tonart-/Vorzeichenlogik, keine korrekten Pausen, Balken, Bindebögen, Triolen oder Exportfunktion. Das `R` kennzeichnet im Prototyp lediglich vollständig leere angezeigte Takte. Angezeigter 4/4-Takt ist ein **manuell gewähltes Vorschau-Raster**, keine Auslesung der REAPER-Taktart.
- Grau dargestellte Tonlängelinien sind Anzeigehilfen, **keine** Bindebögen.
- Keine Schreibaufrufe für MIDI/Arrangement, keine KI-/Netzwerkaufrufe; ursprüngliches MIDI-Timing bleibt bestehen. Nicht als aufführungsfertige Partitur verwenden.
- Die projektbezogenen GPL-Notator-Tests laufen getrennt auf `feat/notator-gpl-rhythm-audit-20261101`.

## Tests

- `tests/test_core.lua`: echte Lua-Modelltests, quantisierte Kandidaten, drei getrennte Systeme, originale Noten unverändert.
- `tests/test_gui_mock.lua`: echter Lua-Fensterdurchlauf gegen REAPER-API-ReaImGui-Mock, Zeichenvorgänge bestätigt, **0 MIDI-Schreibaufrufe**.
- [GitHub Actions 41358898500](https://github.com/wibem1/Composition-Studio/actions/runs/41358898500): beide Tests **success**.
- Zusätzlich lokal aus der Nutzer-MIDI-Datei `phantasie-in-g-moll-orgel(1).mid` unter Lua 5.3 das Modell mit **1.365 Noten, drei Systemen, 64 4/4-Takten** aufgebaut. Die MIDI-Datei wurde nicht ins Repository hochgeladen.
- **Echter visueller Test unter REAPER Windows/Mac ist noch offen.** Keine Freigabe einer Vollversion vor Nutzerprüfung.

## Nächster Schritt

Den sichtbaren Notenbild-Test mit drei ausgewählten MIDI-Items in REAPER durchführen, Lesbarkeit und Systemzuordnung beurteilen. Danach gezielt Stimmen-/Rhythmusengravur verbessern; nicht weiter endlos Pausen-Diagnose durchführen.
