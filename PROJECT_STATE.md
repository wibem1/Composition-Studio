# Projektstand – Composition-Studio

## 01.11.2026 – REAPER-Notenbild-Test 0.2.2: Child-Window-Stack entfernt

**Zweiter echter Windows-Abbruch in Folge:** Nach 0.2.1 meldete REAPER 7.83/x64/Windows:
`Notation Studio - Notenbild Test.lua:199: ImGui_EndChild: Assertion failed: child_window->Flags & ImGuiWindowFlags_ChildWindow`.
Die Version 0.2.1 konnte also trotz gruenem GUI-Mock-Test nicht als funktionsfaehig gelten.

**Ursacheneingrenzung / Richtungswechsel:** Der Fehler deutet auf eine ungueltige/nicht balancierte ReaImGui-Child-Window-Verschachtelung hin; warum der Child-Status im echten Windows-Kontext verloren ging, ist nicht abschliessend nachgewiesen. Nach zwei missglueckten punktuellen API-Fixes wurde der problematische Weg **vollstaendig eliminiert**, statt erneut isolierte Parameter zu aendern: `experimental/score-preview/Notation Studio - Notenbild Test.lua` zeichnet ab `0.2.2-test` direkt in die DrawList des **Hauptfensters** und reserviert Zeichenflaeche mit `ImGui_Dummy`. Keine Aufrufe von `ImGui_BeginChild` oder `ImGui_EndChild` mehr. Die Hauptfenster-Scrollbar uebernimmt die vertikale Navigation. Siehe offizielle Dokumentation https://cfillion.ca/reaper_imgui_doc.html.

**Regressionstests:** `experimental/score-preview/tests/test_gui_mock.lua` laesst beide Child-APIs jetzt bewusst mit Assertion scheitern, fordert zwei aufeinanderfolgende Frames mit balanciertem `ImGui_Begin/End` und zwei gueltigen `ImGui_Dummy`-Canvas-Reservierungen sowie weiterhin **null MIDI-Schreibzugriffe**. CI https://github.com/wibem1/Composition-Studio/actions/runs/41360686013 **success** inkl. Syntax und Score-Modelltests. Das ist ein **Simulationsnachweis**, kein echter REAPER-Grafiktest.

**Auslieferung:** Gespraechsartefakt `Notation_Studio_Notenbild_Test_0.2.2_Windows.zip` mit dem Versionsstand aus GitHub, Startanleitung und unveraendertem Core. ZIP-Integritaet und Git-Blob-Hash der zwei Lua-Dateien geprueft: Hauptscript `0cc0f50d21b30c971c0e73caed87e9e79c37b2db`, Core `3e3d35f872d02c1f483510ee6144e90a0259a4b6`. Das Paket ist **kein** Release des gesamten Composition Studio.

**Naechster Schritt:** Nutzer-Praxistest der 0.2.2 unter REAPER 7.83 Windows, sichtbare Notendarstellung beurteilen. Keine eigenmaechtigen MIDI-Aenderungen, kein Merge, Hauptprogramm/main unveraendert, Draft PR #4.


## 01.11.2026 – REAPER Windows: Notenbild 0.2 Startfehler korrigiert, Testkandidat 0.2.1

**Nutzerbefund:** Screenshot in REAPER 7.83/x64 (Windows), nach Start der Aktion `Notation Studio - Notenbild Test.lua`: `ReaScript Error ... lua:189: bad argument #5 to 'ImGui_BeginChild' (number expected, got boolean)`. Der urspruengliche Testkandidat war damit **im echten REAPER nachgewiesen nicht startfaehig**. Das sichtbare Notenbild im Hintergrund gehoert zum nativen REAPER-Noteneditor, nicht zu unserem ReaImGui-Fenster.

**Ursache:** In `experimental/score-preview/Notation Studio - Notenbild Test.lua` uebergab 0.2.0-test als 5. Argument von `r.ImGui_BeginChild` den booleschen Wert `true`. Die ReaImGui-API ab 0.9 erwartet dort numerische `child_flags`, an Stelle sechs numerische `window_flags` (https://cfillion.ca/reaper_imgui_doc.html). **Fix 0.2.1-test:** Aufruf mit expliziten Zahlen `1,0` (ChildFlags_Borders, WindowFlags_None). Der Fenstertitel und die Lua-Versionsangabe nennen `0.2.1`, um die neue Aktion von 0.2 unterscheiden zu koennen.

**Automatisierte Regression:** `experimental/score-preview/tests/test_gui_mock.lua` prueft die ReaImGui-Argumenttypen streng (5. und 6. Stelle Zahlen, ChildFlags 1). Die fehlerhafte Version wuerde an dieser Assertion scheitern. Syntaxpruefung, Core-Score-Modell und reales Lua-Hauptskript gegen den ReaImGui/REAPER-Mock laufen nach dem Fix erfolgreich: https://github.com/wibem1/Composition-Studio/actions/runs/41359544245 (**success**). Dies ist kein echter Windows-Grafiktest.

**Auslieferung nur als separater Test:** Neues lokal erzeugtes ZIP `Notation_Studio_Notenbild_Test_0.2.1_Windows_Fix.zip`, vollstaendig und Integritaet erfolgreich geprueft. Das enthaltene Lua-Hauptskript stimmt mit GitHub-Blob `3859baeac6c78b01beb2e45924efddbc2809523a` ueberein; Core-Lua stimmt mit `3e3d35f872d02c1f483510ee6144e90a0259a4b6` ueberein. Das ZIP liegt im Chat, nicht als GitHub-Release. Zwei Lua-Dateien muessen **nebeneinander** entpackt und die Aktion neu geladen werden, sonst startet die alte Dateiversion.

**Offen und naechster Schritt:** Version 0.2.1 einmal real in REAPER 7.83/Windows starten und Screenshot/Fehler bei der Grafikdarstellung pruefen. Keine parallele Entwicklung weiterer Notensatzfunktionen vor diesem Beleg. Bestehende produktive Anwendung/Update/main bleiben unveraendert, Draft PR #4.


## 01.11.2026 – Sichtbarer Notenbild-Testkandidat 0.2 fuer REAPER, separates Feature-Branch

**Auftrag:** Nach den bisherigen GPL-Pausendiagnosen moechte der Nutzer endlich einen sichtbar bedienbaren Notenbild-Prototyp. Dieser Schritt implementiert erstmals eine native (ReaImGui) Score-Vorschau, ohne das bestehende Notation Studio zu ersetzen.

**Feature-Branch:** `feat/notation-score-preview-20261101` direkt von `main` erstellt, **separat** vom GPL-Notator-Branch `feat/notator-gpl-rhythm-audit-20261101`. `Notation Studio.lua` v0.1.24 auf main bleibt unveraendert. Neue Dateien unter `experimental/score-preview/`: `Notation Studio - Notenbild Test.lua`, `score_preview_core.lua`, `README.md`, `tests/test_core.lua`, `tests/test_gui_mock.lua`. Der Kern verwendet **keine** kopierten GPL-Notator-Module.

**Funktionsumfang – implementiert:** Oeffnet ein eigenstaendiges natives ReaImGui-Fenster IN REAPER. Liest MIDI-Noten aus den selektierten MIDI-Items (fallback aktiver MIDI-Editor), zeigt getrennte Systeme, Tonhoehen/vereinfachte Notenkoepfe und Notenwerte, Taktstriche und Hilfslinien, zoomt und blaettert taktweise; Buttons fuer **manuelles** 4/4 oder 3/4 als Display-Testgitter und Anzeige 1/16 oder 1/32. Original-MIDI bleibt unangetastet. Keine KI-/Netzwerkaufrufe, keine Aenderung der Nutzer-Einstellungen.

**Grenzen:** Noch KEIN klassischer vollstaendiger Notensatz: fehlende echte Stimmenzuordnung innerhalb einer Orgelmanual-Spur, Balkengruppen, Bindeboegen, korrektes Vorzeichen-Gedaechtnis, korrekte polyphone Pausen, Triole, Noten-/Taktartwechsel-Automatik und MusicXML/PDF. Die farbig helle Darstellungs-Dauerlinie ist keine Bindung. Die Testversion darf nicht als auffuehrungsfertige Partitur gelten.

**Nachweise:**
- Die beiden Lua-Dateien im vom Nutzer herunterladbaren ZIP (Gesprächsartefakt `Notation_Studio_Notenbild_Test_0.2.zip`) sind *bytegleich* mit den GitHub-Versionen (Git-Blob-SHAs beider Seiten abgeglichen).
- Lua 5.3 lokal: `test_core.lua` bestanden, `test_gui_mock.lua` (echtes GUI-Skript, 22 Zeichenvorgaenge, 0 MIDI-Schreib-APIs) bestanden. Tatsaechliche hochgeladene Orgel-MIDI-Datei lokal geparst und als Lua-Modell mit **1.365 Noten, 3 Systemen und 64 4/4-Takten** erfolgreich aufgebaut. Nutzerdaten nicht in GitHub uebernommen.
- GitHub CI `https://github.com/wibem1/Composition-Studio/actions/runs/41358898500` auf Ubuntu Lua 5.4 `success`: beide Core- und GUI-Mocktests.
- **Echter REAPER-ReaImGui-Grafiklauf Windows/Mac noch NICHT getestet**; kein Hauptprogramm-Release, Draft-PR, kein Merge.

**Naechster einzelner Schritt:** Testpaket in echtem REAPER verwenden, drei passende MIDI-Items markieren, Fenster oeffnen und die lesbare Darstellung beurteilen; dann auf Basis des visuellen Befunds gezielt verbessern. Keine weitere Diagnose-Schleife ohne konkreten Fehler.

Stand: 23.10.2026 · Übernahme des allgemeinen Entwicklungsstandards (Dokumentationsänderung)

## Projekt und belegter Dokumentationsstand
Kompositions-/Bearbeitungsebene in REAPER; README dokumentiert v1.1.6 vom 19.10.2026 als TEST CANDIDATE.
Diese Angaben basieren auf den verfügbaren Projektinformationen; bei dieser Umstellung wurden **keine** aktuellen End-to-End-Tests, Releases oder CI-Artefakte geprüft.

## Globale Regeln
https://github.com/wibem1/AI-Development-Standards/blob/main/DEVELOPMENT_STANDARDS.md

## Nächster Schritt
Vor erneuter Entwicklung Branch, letzten Commit, offene Aufgaben und reale Testnachweise ermitteln. Genau einen kleinen nachprüfbaren Arbeitsschritt auswählen. Bestätigte Testergebnisse mit Quelle/Version hier nachtragen. Bis dahin ist die aktuelle Gesamtfunktion **nicht neu verifiziert**.
