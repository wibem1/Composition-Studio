# Projektstand – Composition-Studio

## REAPER-Vergleich: 1/32 + Minimum 1/64 ist schlechter lesbar (01.11.2026)

- **Vom Nutzer in REAPER 7.83/OSX64 manuell eingestellt und per Screenshot bestaetigt:** `Quantize notes/rests = 1/32`, `Minimum note length = 1/64`; beide Checkboxen `Use project default` sind ausgeschaltet, Spur `Revolt Patchable Synth`.
- Das Notenbild der Takte 1–4 zeigt bei diesen Werten deutlich mehr sehr kurze Noten/Pausen, zersplitterte Balkengruppen sowie komplexere Bindungen als die vorherige groebere Darstellung. **Dieser Praxistest ist fuer das Ziel Lesbarkeit negativ.** Die MIDI-Daten wurden fuer diesen Vergleich nicht absichtlich veraendert.
- **Wichtig:** Die manuelle Kontrolle belegt die Werte 1/32 und 1/64 im Dialog, nicht dass die vorherigen Skriptbefehle 41030/41212 individuelle Track-Overrides gesetzt haben. Im frueheren Dialog waren trotz gesendeter Befehle 1/8 und 1/32 sichtbar. Diese technische Frage bleibt offen.
- **Konsequenz:** Keine feinere Quantisierung allein als Loesung, nicht blind MIDI-Noten verschieben/verlaengern. Fuer diesen Titel zuerst zur zuvor besser lesbaren Anzeige 1/8 und Minimum 1/32 zurueckkehren. Danach musikalisch begruendete, nur fuer den Notensatz gueltige Notenlaengen/Voice-Zuordnung separat erproben (moegliche REAPER-Notationsevents `disp_len`), mit Original-Performance und Undo-Absicherung; erst nach selektivem Test automatisieren.
- **Naechster einzelner Schritt:** Zunaechst eine klar abgegrenzte Passage der rechten Hand darauf pruefen, welche der kurzen MIDI-Luecken in der Notation besser als laengere Note/Staccato oder echte Pause dargestellt werden sollen. Keine Aenderung an `main`, keine Release-Freigabe.

## REAPER-Praxistest: MIDI-Rhythmusdiagnose bestaetigt (01.11.2026)

**Realer REAPER-Test (Nutzer, 7.83/OSX64):** `tools/notation_midi_readonly_diagnose.lua` lief auf Track `Revolt Patchable Synth`, MIDI-Take mit 238 Noten. Ausgewertet wurden die ersten vier Takte, 61 MIDI-Noten: 31 Anfaenge und 30 Enden mehr als 0,04 Viertel von einem 1/16-Raster entfernt; 14 Noten kuerzer als 1/16. Register ab MIDI 60: 24 tatsaechliche Abdeckungsluecken bis zu einer Viertelnote, Summe 4,75 Viertel; Beispiele wiederholt 0,135 Viertel. Unter MIDI 60: keine solchen Luecken. In der Einzelnote-Liste wiederkehrend Startabweichung 0,125 Viertel sowie Notenlaengen 0,240, 0,365 und 0,677 Viertel.

**Interpretation:** 0,125 Viertel ist ein 1/32-Raster-Schritt; wiederkehrende 0,135-Viertel-Luecken liegen nahe einem 1/32-Wert und sind mit echten MIDI Note-Off/On-Abstaenden vereinbar. 1/16-Displayquantisierung kann daher rhythmische Details zu grob abbilden; 1/32-Displayquantisierung ist ein naheliegender **zu testender** Vergleich, aber noch kein garantierter musikalischer Fix. Die Lueckenstatistik ab MIDI 60 ist keine saubere Stimmtrennung und beweist nicht, dass jede notierte Pause falsch ist; ggf. absichtliche Artikulation.

**Weiterer offener Punkt:** Voriger Quantisierungs-Dialog zeigte mit deaktivierten Track-Projekt-Defaults 1/8 und 1/32, obwohl Skript 1/16 und 1/64 aufrief. Somit darf eine Erfolgsmeldung ueber gesendete Aktionen nicht als wirksame Uebernahme gewertet werden.

**Naechster isolierter Schritt:** Zunaechst in einer Projektkopie im nativen Dialog des richtigen Tracks die Displayquantisierung **manuell auf 1/32**, Mindestnotenlaenge **1/64** setzen und dieselben vier Takte visuell gegenueber 1/16 vergleichen. Die echte MIDI-Performance bleibt unangetastet. Erst anhand des Vergleichs entscheiden, ob pro Note ausschliesslich die angezeigte Laenge (`disp_len`) korrigiert werden soll. Keine automatische Ausdehnung kurzer Noten / Entfernung von Pausen und kein Merge vor Test.


## REAPER-Screenshot Notenbild Takte 1–4 (01.11.2026)

- Im Nutzer-Screenshot nach dem Aktionslauf ist die zweisystemige, mehrzeilige Klaviernotation gegenueber frueheren Versionen wesentlich lesbarer. In der rechten Hand gibt es dennoch sehr viele kurze Pausen und wiederholte getrennte Balkengruppen, deren musikalische Notwendigkeit am Bild alleine nicht erkennbar ist. Die linke Hand wirkt lesbarer, ihr MIDI-Timing ist aber nicht bekannt.
- **Korrektur einer vorigen Schlussfolgerung:** Auf dem unmittelbar vorherigen Screenshot des nativen Quantisierungsdialogs waren nach Ausfuehrung des Skripts im Track `Revolt Patchable Synth` die Zahlen **1/8 und 1/32** sichtbar, nicht 1/16 und 1/64. Falls dieser Screenshot den Zustand unmittelbar nach der Ausfuehrung zeigt, haben die beiden Aktionen den aktuellen Track-Override offenbar **nicht** auf die gewuenschten Werte gesetzt. Die Ursache (Projektvorgabe vs. Track-Override vs. Aktionskontext) ist offen. Ein gesendeter Befehl ist kein Erfolgstest.
- Die REAPER-Dokumentation bestaetigt, dass Anzeigequantisierung und Mindestnotenlaenge die zugrundeliegenden MIDI-Events nicht veraendern. Komplexe notierte Pausen koennen trotzdem aus kurzen echten MIDI-Notenlaengen oder voneinander abweichenden Note-On/Off-Zeiten kommen.
- **Separater naechster Diagnoseschritt:** `tools/notation_midi_readonly_diagnose.lua` ermittelt fuer die ersten vier Takte des aktiven MIDI-Takes kurze Noten, Start-/End-Abweichungen vom Sechzehntelraster und Luecken im oberen/unteren Register. Nur lesend; keine Track-/Projekt-/Notation-/MIDI-Aenderung. Lokale Lua-5.4-Syntaxpruefung und simulierter Lauf mit MIDI-Noten bestanden; realer REAPER-Lauf noch offen.
- **Keine Freigabe:** Noch keine Automatik fuer das Entfernen vermeintlich ueberfluessiger Pausen, keine Aenderung an Notenlaengen/Notenschluesseln, `main` unveraendert.

## REAPER-Praxistest – Folgebeobachtung nach deaktivierten Projekt-Defaults (01.11.2026)

- Nutzer zeigte einen zweiten Screenshot des nativen `Notation Display Quantization`-Dialogs nach dem isolierten Skriptlauf. Beim ausgewaehlten Track `Revolt Patchable Synth` sind jetzt **beide `Use project default`-Checkboxen deaktiviert**; die Regler sind aktiv. Dadurch liegt ein Track-Override vor, anders als beim ersten Screenshot.
- Die beiden numerischen Anzeigefelder neben den Reglern erscheinen im Screenshot **leer**. Die exakten Werte (1/16 und 1/64 oder vorherige Alternativen) koennen **nicht sicher abgelesen** werden. Auch die Richtung/Endposition der Regler ist ohne Kalibrierung kein belastbarer Nachweis einer konkreten Notenlaenge.
- **Belegstand:** Der Aufruf der IDs 41030, 41212 ist in echtem REAPER bestaetigt, beide Track-Overrides sind deaktiviert von den Projektvorgaben, tatsaechliche Werte nach Aktion **noch nicht verifiziert**. Keine Freigabe und kein Merge.
- **Naechster Schritt:** Eine kontrollierte Vorher-/Nachher-Pruefung mit sichtbaren Werten oder ein rein lesender Vergleich des gespeicherten Projekt-/Track-Zustands; keine weiteren unkontrollierten Schreibversuche am `SCORE`-Eintrag.

## REAPER-Praxistest: native Aktionen gesendet, Track erbt Projektvorgaben (01.11.2026)

- Nutzer hat `tools/notation_quantization_test.lua` in REAPER **7.83/OSX64** ausgefuehrt. Konsolenausgabe bestaetigt, dass MIDIEditor_OnCommand mit **41030** (Anzeige 1/16) und **41212** (Minimum 1/64) ohne Skriptfehler aufgerufen und danach der native Quantisierungsdialog geoeffnet wurde.
- Screenshot des Dialogs: Beide Kontrollkaestchen **Use project default** sind aktiviert. Die individuellen Eingabefelder sind deshalb deaktiviert. Der Screenshot belegt **nicht**, dass fuer die ausgewaehlte Spur individuelle Quantisierungswerte 1/16 und 1/64 gespeichert wurden; er beweist aber auch nicht, dass die wirksamen Projekt-Defaults falsch sind (REAPER-Handbuch nennt 1/16 und 1/64 als Standards).
- **Status:** Aktionsaufrufe in echtem REAPER bestaetigt; wirksame Werte bzw. Override-Verhalten **noch nicht bestaetigt**. Keine Freigabe/kein Merge.
- **Naechster einzelner Test:** In einer Projektkopie beide `Use project default`-Haekchen bewusst deaktivieren und abweichende Werte einstellen, die beiden Aktionsaufrufe erneut ausfuehren und im Dialog kontrollieren, ob sie auf 1/16 bzw. 1/64 zurueckgesetzt werden. Kein MIDI-Noten-Editing; Ergebnis festhalten, dann den gezielten Fix auswaehlen.

## Notation Studio – Quantisierungsaufrufe auf Basis REAPER 7.83 (01.11.2026)

**Durch den Nutzer in realem REAPER 7.83/OSX64 bestaetigt:** MIDI-Editor-Bereich 32060 enthaelt 1840 Aktionen. Gesuchte Befehle: Anzeige 1/16 = **41030**, Minimum 1/64 = **41212**, Minimum 1/16 = **41214**, proportionale Abstaende = **41131**. Der native Einstellungsdialog `Notation: Adjust display quantization...` hat **41745**. Diese Ergebnisse sind ein echter Nachweis der Verfuegbarkeit, **noch kein Nachweis einer erfolgreichen automatischen Einstellungsuebernahme**.

**Auf Branch `fix/notation-quant-actions-20261101` implementiert:**
- In `Notation Studio.lua` werden fuer Anzeige 1/16 und Minimum 1/64 die konkreten IDs verwendet, die vor Ausfuehrung jeweils gegen den vollen Befehlsnamen verifiziert werden; keine unscharfe Namenssuche mehr fuer diese zwei Optionen.
- Vor den beiden Aufrufen werden beide IDs validiert; wenn eine fehlt, erfolgt kein Aufruf. REAPERs `MIDIEditor_OnCommand` wird im gesicherten Aufruf verwendet. Rueckmeldung nennt deshalb bewusst nur **gesendet**, nicht **sichtbar uebernommen**.
- Separater Knopf `Test: 1/16 + Mindestlaenge 1/64` im Bereich Darstellung/Quantisierung, dazu `REAPER-Quantisierung kontrollieren...` fuer den nativen Dialog, ebenfalls explizit ueber verifizierte ID 41745. Der vorhandene `Lesbarkeit verbessern`-Ablauf verwendet jetzt dieselben verifizierten beiden Aktionen, andere Schritte bleiben unberuehrt.
- Eigenstaendiges `tools/notation_quantization_test.lua` kann die beiden Notationsaktionen unabhaengig vom Hauptfenster ausloesen und danach den nativen REAPER-Kontrolldialog oeffnen. Dieser Test aendert **keine MIDI-Notenpositionen oder Notenlaengen**, wohl aber die gewollten Notations-Anzeigeeinstellungen.

**Pruefung:** Standalone-Testskript mit liblua 5.4 syntaktisch geladen; Simulationen: Erfolgspfad (41030, 41212, 41745 in Reihenfolge), kein MIDI-Editor, geaenderte Aktionskennung und Ausfuehrungsfehler bestanden. Strukturchecks fuer den aktualisierten App-Code bestanden (gesicherte IDs, UI, unveraenderte Notenschluesselzuordnung und App-Versionsbezeichnung). **Vollstaendige App-Syntax und Realtest des geaenderten Notation Studio stehen noch aus.** Keine Freigabe oder Versionsanhebung, `main` unveraendert.

**Naechster einzelner Schritt:** Standalone-Quantisierungstest in REAPER auf einer Projektkopie ausfuehren. Im unmittelbar geoeffneten Dialog 1/16 und 1/64 **fuer den richtigen Track** ablesen. Bei Erfolg anschliessend die angepasste App aus dem Arbeitszweig in REAPER pruefen; erst dann Version/Freigabe entscheiden.

## Notation Studio – Aktionsdiagnose (01.11.2026, Arbeitszweig)

- Die Hauptdatei `Notation Studio.lua` auf `main` traegt v0.1.24. In `cleanup_notation()` werden nativen MIDI-Editor-Aktionen zur Darstellungsquantisierung, Mindestnotenlaenge und proportionalen Abstaenden per Namenssuche angesteuert. Der reale Effekt der Quantisierungsbefehle ist aktuell **nicht verifiziert**.
- Die offiziellen REAPER-Aktionen `Notation: Set display quantization to 1/16 (default)` und `Notation: Set minimum display quantization note length to 1/64 (default)` sind in der MIDI-Aktionsliste dokumentiert. Ob die bestehende Namenssuche sie beim Nutzer korrekt findet, bleibt zu pruefen.
- Kleine isolierte Diagnose hinzugefuegt: `tools/notation_action_diagnose.lua` liest ausschliesslich Aktionen des MIDI-Editors (Sektion 32060), zeigt Befehlsnummern und Treffer in der Konsole und zeigt keinen Projekt-/MIDI-/Track-Schreibzugriff. Es wurde **nicht in REAPER ausgefuehrt**.
- Keine Aenderungen an `Notation Studio.lua`, keine Notenschluesselmanipulation, keine neue App-Version oder Freigabe; `main` bleibt unveraendert.
- **Naechster einzelner Schritt:** Diagnoseskript mit geoeffnetem REAPER-MIDI-Editor ausfuehren; anhand der angezeigten Befehlskennungen den Aufruf der nativen Quantisierung gezielt korrigieren und in REAPER vergleichen. Erst danach am App-Code arbeiten.

Stand: 23.10.2026 · Übernahme des allgemeinen Entwicklungsstandards (Dokumentationsänderung)

## Projekt und belegter Dokumentationsstand
Kompositions-/Bearbeitungsebene in REAPER; README dokumentiert v1.1.6 vom 19.10.2026 als TEST CANDIDATE.
Diese Angaben basieren auf den verfügbaren Projektinformationen; bei dieser Umstellung wurden **keine** aktuellen End-to-End-Tests, Releases oder CI-Artefakte geprüft.

## Globale Regeln
https://github.com/wibem1/AI-Development-Standards/blob/main/DEVELOPMENT_STANDARDS.md

## Nächster Schritt
Vor erneuter Entwicklung Branch, letzten Commit, offene Aufgaben und reale Testnachweise ermitteln. Genau einen kleinen nachprüfbaren Arbeitsschritt auswählen. Bestätigte Testergebnisse mit Quelle/Version hier nachtragen. Bis dahin ist die aktuelle Gesamtfunktion **nicht neu verifiziert**.
