# Projektstand – Composition-Studio

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
