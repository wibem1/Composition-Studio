# Projektstand – Composition-Studio

## 01.11.2026 – Original-MIDI der Orgelphantasie direkt ausgewertet (reale Nutzerdatei)

**Quelle:** Upload `phantasie-in-g-moll-orgel(1).mid`, lokal mit mido direkt gelesen, **Originaldatei nicht ins GitHub-Repo uebernommen**. Standard-MIDI Typ 1, 480 Ticks/Viertel, drei getrennte Spuren, Ende bei QN ~256:
- Spur 0 `Church Organ`, MIDI-Kanal 0, **759 Note-On-Ereignisse**, Register MIDI-Pitch 62–87, 649 verschiedene Einsatzzeitpunkte, darunter Akkorde bis zu vier gleichzeitig gestarteten Noten.
- Spur 1 `Church Organ`, MIDI-Kanal 1, **400 Noten**, Register 51–70, 316 Einsatzzeitpunkte, Akkorde bis drei Toene.
- Spur 2 `Pedal`, MIDI-Kanal 2, **206 Noten**, Register 31–51, monophone Starts.
- **Insgesamt 1.365 Noten**, alle Note-Offs gepaart; die 759 Noten des ersten Manuals passen **exakt** zum realen REAPER-Report (Take `Church Organ`: 759).

**Unabhaengiger Abgleich der REAPER-Projekttakte 2–5:** Projekt-Zeitfenster QN [4,7), [7,10), [10,13), [13,16). Exakte Anzahlen Note-Ons in MIDI-Spur 0: **8, 9, 9, 12 = 38**, also 100% identisch zum Nutzerbericht. Bei tatsaechlicher zeitlicher Intervall-Vereinigung dieses ersten Manuals ist in jedem dieser vier Projekt-Takte die groesste tonfreie Luecke **genau ein MIDI-Tick (1/480 Viertelnote = 0,002083 QN)**, keine Pause musikalisch relevanter Laenge. Daher sind die von der GPL-Pausen-Engine gemeldeten **0 Pausen** in diesem Abschnitt auch unabhaengig von der intern bekannten Summen-Schwachstelle **plausibel und korrekt fuer die vereinigte Klangabdeckung des ersten Manuals**. **Nicht** bewiesen ist damit die korrekte Pause jeder einzelnen polyphonen Stimme.

**Gesamtes Stueck, echte zusammenhaengende Stille je einzelner Spur (ohne die zahlreichen 1-Tick-Trennungen; Schwellwert >= 0,125 QN):** 1. Manual **8**, 2. Manual **8**, Pedal **23** Abschnitte. Die 2. Manualspur ist im Zeitfenster QN 13–16 vollstaendig stumm, waehrend das Pedal eine laengere Note haelt: Ein klarer Nachweis, warum spurspezifische Pausen nicht mit Pausen des Gesamtensembles verwechselt werden duerfen. Ueber alle drei Spuren vereinigt gibt es nur drei Abschnitte von >= 0,125 QN gemeinsamer Stille. Der erste Manualtrack hat 640 Mikroluecken <0,02 QN, groesstenteils genau 1 MIDI-Tick, die fuer das Notenbild nicht als Rest notiert werden sollten.

**Hervorstechender weiterer Befund:** Das rohe MIDI enthaelt ausschliesslich eine `time_signature`-Metaangabe **4/4 bei Tick 0** (keine weiteren Taktartwechsel). Dagegen weist REAPER `TimeMap_GetMeasureInfo` im Nutzer-Projekt fuer Takte 2–5 jeweils **3 QN/Takt** aus. Die MIDI-Datei und die REAPER-Projekttaktkarte sind damit nicht gleich. Das kann optisch unpassende Balken-, Bindungs- und Taktaufteilungen erzeugen. Vor einer Anzeige-/Notationskorrektur muss die beabsichtigte musikalische Taktart anhand der Partitur/Kompositionsanweisung geklaert werden; nicht einfach das Projekt oder MIDI automatisch umstellen. MIDI-Tonart-Tag `Bb` ist mit g-Moll (Paralleltonart) vereinbar.

**Fazit und naechster Schritt:** Der 0-Pausen-Befund in den ersten 4 untersuchten Projekttakten war **kein** Fehler des Original-Engravers. Die zuvor nachgewiesene GPL-Engine-Schwaeche bei ueberlappenden Noten bleibt technisch real, wurde hier aber **nicht** im untersuchten Bereich ausgeloest. Bei weiterer Notation-Studio-Entwicklung prioritär Taktart-Konsistenz, 3 getrennte Orgel-Systeme (Manual I/II + Pedal), innerhalb eines Systems musikalische Stimmenzuordnung und 1-Tick-Note-Offs rein fuer die **Anzeige** tolerieren. Keine MIDI-Performance-Aenderung, keine neue Version/kein Release und kein Merge. Ergebnis stammt aus direkter Dateianalyse, nicht aus einem neuen REAPER-Echtlauf der gesamten Orgelpartitur.


## 01.11.2026 – Windows: Church Organ, 38 Noten im Bereich, 0 berechnete Pausen; bekannte Engine-Grenze nachgewiesen

**Neuer REALER REAPER-Test (Nutzer-Konsolenausgabe):**
- REAPER 7.83/x64, Take und Spur **`Church Organ`**, gesamte Take-Notenzahl **759**.
- Untersuchte Projekttakte 2–5 im 3/4: T2 QN 4–7 **8** Note-Ons, T3 QN 7–10 **9**, T4 QN 10–13 **9**, T5 QN 13–16 **12**, insgesamt **38**, alle >= C4.
- Original GPL v2.55 `generate_voice_rests` liefert sowohl ohne Quantisierung als auch 1/8, 1/16 und 1/32 jeweils **0 Pausen**, auch in der ab-C4-Untergruppe 0. `MIDI-Hash unveraendert: true`; Originalnoten im Analyse-Array ebenfalls unveraendert.
- Keine Ableitung, dass jede **musikalische Stimme** lueckenlos ist: Die Originalfunktion gruppiert Stimmen vorrangig nach `n.chan`, und bei nur einem MIDI-Kanal wird `generate_track_rests` genutzt. Dort werden nominale Dauern verschiedener rhythmischer Einsaetze **summiert**, bevor tatsaechliche Zeitintervallabdeckung geprueft wird. Gerade bei ueberlappenden Chord-/Organnoten koennen Pausen dadurch unentdeckt bleiben.

**Engraver-Fehlermodus erstmals durch echten Lua-Test bewiesen:**
- `tests/test_notator_gpl_overlap_gap.lua` verwendet unveraenderten Original-Engraver und einen einzelnen 3/4-Takt mit drei Noten auf demselben MIDI-Kanal: QN 0–1,5; 0,5–2,0; 2,5–3,0.
- Die nominalen Notenlaengen addieren sich zu **3,5 Vierteln**, aber die echte Vereinigungsmenge der Tonintervalle ueberdeckt nur **2,5 Viertel**; die echte Luecke zwischen QN 2,0 und 2,5 betraegt **0,5 Viertel**.
- Unveraenderte Originalfunktion gibt **0 Pausen** zurueck. CI-Lauf https://github.com/wibem1/Composition-Studio/actions/runs/41356490167 **success**, Log: `KNOWN LIMITATION CONFIRMED: source GPL v2.55 reports 0 rests despite genuine 0.5 QN gap in overlapping same-channel notes`.
- Test ist eine **Charakterisierung eines bestehenden Algorithmusfehlers**, nicht die Bestaetigung korrekten Notensatzes. Das Original-GPL-Modul wurde NICHT veraendert.

**Konsequenz und naechster einzelner Schritt:** Vor Uebernahme der Pausenlogik in das produktive Notation Studio echte zeitliche Intervallabdeckung getrennt von der Summe nominaler Dauern analysieren und musikalische Stimmenzuordnung ermitteln. Fuer `Church Organ` kann aus dem Konsolenbericht allein nicht erkannt werden, ob der gezeigte Fehlermodus vorliegt, weil die Einzelnote-Positionen/-Dauern fehlen. Idealer Input ist die MIDI-Datei dieses Takes (oder die urspruenglich problematische `Revolt Patchable Synth`-Passage); damit lokal objektiv pruefen, ohne weitere rasterbasierte Testschleifen. Keine neue App-Version, kein Merge, `main` unveraendert.


## 01.11.2026 – Windows-Pausenvergleich: scheinbare 10-vs-12-Differenz durch Taktverschiebung aufgeklaert

**Realtest (Nutzerkonsole, REAPER 7.83/x64):**
- Take: `Valse_des_Ombres_Dorees_korrigiert.mid`, Spur `Valse_des_Ombres_Dorees_korrigiert`; im Take insgesamt **76** MIDI-Noten, alle betrachteten im Register >= C4.
- MIDI-Item in der REAPER-Projekttimeline bei **QN 4.000**, erste beruecksichtigte Violinennote bei **QN 10.000**. Zwischen Item-Start und erster Note liegen 6 Viertelnoten = zwei 3/4-Takte.
- Die Projekttakte 3–6 decken QN 7–19 ab: **T3: QN 7–10, 0 Noten; T4: QN 10–13, 4 Noten; T5: QN 13–16, 2 Noten; T6: QN 16–19, 4 Noten**. Summe 10. T3 ist tatsaechlich leer, daher exakt eine Ganztaktpause von 3.000 QN bei allen 4 Anzeigevarianten. Die naechsten zwei Violinnoten aus dem vierten musikalischen Takt nach dem ersten Einsatz liegen erwartungsgemaess in **Projekttakt 7** (nicht Teil des Tests). Somit war der Vergleich mit den urspruenglichen musikalischen Takten 3–6 falsch ausgerichtet. Kein Indiz fuer eine falsche Pausenberechnung.
- `MIDI-Hash unveraendert: true`, `Originalnoten im Analyse-Array erhalten: true`. Die GPL-v2.55-Pausenberechnung ist im realen REAPER-Windows-Lauf fuer diesen Fall funktionsfaehig; **kein** Nachweis eines fertigen verbesserten Notenbilds.
- Ungeklaert bleibt **76 REAPER-Take-Noten gegenueber 77 MIDI-Noten in der hochgeladenen Violin-Spur**. Eine einzelne Abweichung kann nur mit vollstaendigem REAPER-Take-Export bzw. Note-fuer-Note-Vergleich lokalisiert werden; nicht vorschnell einen Importverlust behaupten.
- Die urspruenglich problematische Passage (macOS-Track `Revolt Patchable Synth`, 238 MIDI-Noten, in ersten 4 Takten 24 kurze Oberregisterluecken) ist **nicht** diese Valse-Aufnahme. Fuer die Beurteilung von zu vielen angezeigten Sechzehntelpausen bleibt ein echter Vergleich mit jener Passage offen.

**Stand und naechster Schritt:** Keine neue Quantisierung und keine weiteren pauschalen Korrekturversuche bei der nahezu lueckenlosen Valse-Melodie. Der getestete GPL-Engraver bleibt auf Draft-PR #3 getrennt von der produktiven Anwendung. Fuer die eigentliche Aufgabe die frueher problematische MIDI-Passage im REAPER-Notator-Adapter pruefen oder als MIDI exportieren. `main` und `Notation Studio.lua` sind unveraendert.


## 01.11.2026 – Originaldatei Valse_des_Ombres_Dorees_korrigiert.mid gegen REAPER-Bericht verifiziert

**Datei direkt analysiert (Nutzerupload im Chat, nicht ins Repository kopiert):**
- Standard-MIDI-Datei Typ 1, 480 Ticks/Viertel, **3/4** bei konstant 108 BPM, ca. 43,335 Sekunden, 26 Takte; separate MIDI-Spuren Violine (Programm 40, 77 Noten) und Klavier (Programm 0, 208 Noten), insgesamt 285 Noten.
- Violin-Notenanfaenge bei 3/4: erste zwei Takte ohne Violine; Takt 3 **4** Noten, Takt 4 **2**, Takt 5 **4**, Takt 6 **2** = **12** Noten in Takt 3–6. Dort **kein** vollstaendig leerer Takt. In diesem Bereich liegt genau eine minimale echte Violinluecke von einem MIDI-Tick (1/480 Viertelnote ≈ 0,002083 QN), ansonsten durchgehende Notenabdeckung.
- Saemtliche 77 Violin-Notenanfaenge liegen exakt auf dem 1/16-Taktraster; keine Violin- oder Klaviernoten kuerzer als 1/16. Viele Note-off-Zeitpunkte differieren nur um einen MIDI-Tick von nominalen Notenlaengen.
- Im realen Windows-Konsolenbericht zuvor dagegen: `Bereich: Takte 3 bis 6`, `Noten: alle=10`, `Pausen=1, Summe=3.000 QN, Ganztaktpausen=1` bei allen Rastern. Dies passt **nicht** zu den 12 Violin-Notenanfaengen und vier belegten Takten der hochgeladenen Originaldatei. Moegliche Gruende: anders zugeschnittener Take, Item-/Take-Versatz oder Projektposition. Noch **nicht** identifiziert; nicht als generelle Unzulaenglichkeit der GPL-Engine oder als MIDI-Fehler bewerten.
- Der zuvor auf macOS analysierte Track `Revolt Patchable Synth` mit 238 MIDI-Noten ist **ein anderer Testgegenstand**, nicht mit diesem Valse-MIDI austauschbar.

**Gezielte Diagnostik verbessert:** `tools/notator_gpl_rest_comparison.lua` gibt nun Take-/Spurnamen, Gesamtzahl der Take-Noten, Item-Startprojekt-QN, erste beruecksichtigte Note und die Notenanfaenge pro Takt mit exakten Projekt-QN-Grenzen aus. Keine Schreibfunktionen. `tests/test_notator_gpl_rest_adapter.lua` hat eine zusaetzliche synthetische 3/4-Regression mit Taktzaehlungen 4/2/4/2. Die Original-MIDI-Datei ist **nicht** im Repository gespeichert.

**CI-Nachweis:** Nach Korrektur zweier durch die neuen Diagnosefelder entstandenen Referenzfehler laufen alle vier GPL-/Adapter-Testdateien unter Lua 5.4 erfolgreich: https://github.com/wibem1/Composition-Studio/actions/runs/41354359742 (Status `success`). Davor fehlgeschlagene Zwischenlaeufe sind nicht als erfolgreiche Nachweise zu interpretieren.

**Naechster einzelner Schritt:** Korrigiertes read-only Skript an dem aktuellen Windows-REAPER-Take erneut ausfuehren; anhand der neu ausgegebenen Projekt-QN-Grenzen und Takt-Notenanzahlen abgleichen, ob die Datei korrekt positioniert bzw. zugeschnitten ist. Keine neuen Quantisierungs-Experimente, keine musikalische Bearbeitung, kein Merge/Release.


## 01.11.2026 – Erster erfolgreicher REALER REAPER-Windows-Lauf des GPL-Pausenvergleichs

**Nutzerbeleg (REAPER 7.83/x64, Windows):**
- Read-only-Adapter `tools/notator_gpl_rest_comparison.lua` mit unveraendertem GPL-Original-Engraver v2.55 erfolgreich durchgelaufen, **keine** Taktkarten- oder Modul-Pfadfehlermeldung.
- Bericht: Bereich **Takte 3–6**; **10** nicht stummgeschaltete, in den Bereich ragende MIDI-Noten; alle liegen `pitch >= 60` (Statistik oberes Register), unter C4 0.
- Sowohl ohne Anzeigequantisierung als auch bei 1/8, 1/16 und 1/32 erzeugt der Algorithmus: **1 Pause, nicht kurz, Gesamtwert 3,000 Viertelnoten, als Ganztaktpause markiert**; `upper` und `all` sind daher identisch. Die eine Ganztaktpause entspricht im Datenmodell einem leeren 3/4-Takt. Die Zuordnung, welcher Takt leer ist, wurde **nicht** ausgegeben.
- `MIDI-Hash unveraendert: true`; `Originalnoten im Analyse-Array erhalten: true`. Dies belegt Datenstabilitaet dieses realen Laufs, NICHT eine visuelle Verbesserung der Partitur.

**Relevante Einschraenkung:** Vorherige Screenshots dieses Realtests zeigten `Valse_des_Ombres_Dorees_korrigiert.mid` im MIDI-Editor; das urspruengliche Problembeispiel enthielt dagegen **61 Noten in ersten 4 Takten**, 24 kurze Luecken im oberen Register, Track `Revolt Patchable Synth`, REAPER 7.83/OSX64. Aktueller Windows-Lauf testet daher offensichtlich **nicht dasselbe aktive Take/den gleichen Bereich**. Bei nur 10 Noten und lediglich einer Ganztaktpause ist aus dieser Ausgabe keine Aussage zur Ursache der vielen urspruenglichen kurzen Notationspausen ableitbar.

**Naechster einzelner Schritt:** Vergleich mit der konkreten problematischen Passage (frueherer Track `Revolt Patchable Synth`), falls sie in REAPER verfuegbar ist, oder alternativ ein vom Nutzer bereitgestellter Ausschnitt der urspruenglichen MIDI-Datei. Vor weiterem Parameter- oder Algorithmus-Tuning erst sicherstellen, dass dieselben Eingabedaten verglichen werden. Noch keine automatische Notationskorrektur, kein Merge/Release, `main` unveraendert.


## 01.11.2026 – Windows-Folgeversuch: Original-Engraver nicht gefunden (Installationspfad)

**Beleg:** Nutzer-Screenshot aus REAPER 7.83/Windows beim neuen Lauf des read-only-Adapters: `Original-Engraver nicht gefunden: C:\\Users\\wibem\\Downloads/../vendor/REAPER-Notator-2.55/modules/rendering/engraver.lua`.

**Eingrenzung:** Das Skript wurde direkt im `Downloads`-Stammordner gespeichert/geladen und sucht relativ zum **vermeintlichen** `tools`-Verzeichnis eine `../vendor`-Struktur. Dadurch kann der Engraver nicht geladen werden. Dies ist **kein Fehler in den MIDI-Noten, der Taktkarte oder der GPL-Engine**. Der Windows-Realtest der korrigierten Taktberechnung und Pausenfunktion steht folglich weiterhin aus.

**Korrektur ohne Codeeingriff:** Ein kompaktes lokales Test-ZIP wurde aus der vom Nutzer bereitgestellten Repository-ZIP erstellt. Es enthaelt den aktuellen `tools/notator_gpl_rest_comparison.lua`-Stand (verifiziert gegen GitHub-Blob `029784cc960b6d499d6e7420f22fb2dbb105ac31`), den unveraenderten GPL-Engraver (Blob `08e3adfd23278f0afaa44534a4bcb715a7b056a6`) und die vollstaendige GPL-3.0-Lizenz. Der relative Pfad `tools/../vendor/.../engraver.lua` existiert im ZIP; ZIP-Integritaetspruefung erfolgreich. Dieses Hilfs-ZIP ist ein Gespraechsartefakt und noch **kein** GitHub-Release. Die regulare GitHub-Quellstruktur bleibt unveraendert.

**Naechster einziger Schritt:** ZIP vollstaendig entpacken, in der REAPER-Aktionsliste eine **neue** Aktion fuer die Datei `REAPER-Pausenvergleich-Test/tools/notator_gpl_rest_comparison.lua` laden (nicht das bisherige alte Skript aus Downloads), dann den Konsolenbericht pruefen. Keine automatische Notenbild-Aenderung.


## 01.11.2026 – Windows: Taktkarte-Fehler im Pausenvergleich korrigiert

**Nutzer-Praxistest:** In REAPER 7.83/Windows zeigte `tools/notator_gpl_rest_comparison.lua` unmittelbar `Taktkarte ungueltig bei Takt 1`. Die Pausenberechnung hatte noch nicht begonnen, die MIDI-/Projekt-Daten blieben unberuehrt.

**Codeursache / Fix:** Der alte Adapter erwartete von `TimeMap_QNToMeasures` neben dem Taktindex auch die laut API **optionalen** Anfangs- und End-QN. Die genaue Rueckgabe von REAPER auf dem Nutzergeraet wurde nicht protokolliert; das ist die begruendete Fehlerhypothese, noch keine am Geraet verifizierte Ursache. Die Taktkarte wird jetzt direkt ueber `TimeMap_GetMeasureInfo(0,bar)` anhand der Taktnummer gelesen. Taktartwechsel sind dadurch explizit abgebildet. Die Original-GPL-Engine bleibt unveraendert; keine MIDI-Schreibzugriffe.

**Automatisierter Test:** `tests/test_notator_gpl_rest_adapter.lua` simuliert die ganze Adapter-Ausfuehrung mit echtem GPL-Engraver. Faelle: 4/4 mit absichtlich fehlenden optionalen `QNToMeasures`-Rueckgaben und MIDI-Item ab Takt 2 mit 3/4, 5/8, 4/4. Kein Skriptabbruch, komplette Reststatistik, MIDI-Hash unveraendert.

**Erfolgreicher CI-Nachweis:** https://github.com/wibem1/Composition-Studio/actions/runs/41352928538 – Status `success` inkl. aller vier Lua-Testskripte; Ausgabe `OK: real GPL rest adapter, measure-index API, optional outputs and meter change`.

**Offen:** Das korrigierte Skript wurde noch **nicht** in der echten REAPER-Windows-Installation getestet. Keine neue Version/kein Release/kein Merge. **Naechster Schritt:** Lokale Kopie von `tools/notator_gpl_rest_comparison.lua` aus dem Arbeitszweig aktualisieren und nur diese Aktion erneut in REAPER ausfuehren; Konsolenausgabe sichern.


## REAPER-Notator GPL 2.55 – Pausen-Engine isoliert getestet (01.11.2026)

**Neue, nachweisbare Funktionalitaet (Arbeitsbranch `feat/notator-gpl-rhythm-audit-20261101`, PR #3):**
- `tests/test_notator_gpl_rests.lua`: echte Originalfunktion `Engraver.generate_voice_rests` mit lueckenloser einstimmiger Passage, leerem Takt, echtem Taktende-Gap, zwei voneinander getrennten Stimmen, zwei ueberlappenden Stimmen sowie kuenstlich humanisierter Viertakt-Teilpassage getestet. Die Tests pruefen auch Taktgrenzen, nicht-negative Pausendauern und den Erhalt der Originalnotendaten.
- `tools/notator_gpl_rest_comparison.lua`: **rein lesender** REAPER-Adapter. Liest aktive MIDI-Noten in vier Takten, verwendet reale Taktgrenzen (inkl. Taktartwechsel) und vergleicht die Original-Pausenberechnung bei keiner Quantisierung, 1/8, 1/16 und 1/32. Analysiert Gesamtstimme und zwei nur statistisch getrennte Register ab/unter MIDI 60. Original `engraver.lua` bleibt unveraendert; MIDI-Hash wird vor/nach der Analyse verglichen; das Skript enthaelt keine Schreibfunktionen. Die reine Pausenberechnung ist **nicht** der vollstaendige visuelle Renderprozess.
- Kleiner GitHub-Workflow `.github/workflows/notator-gpl-tests.yml` prueft Lua-Syntax und fuehrt die drei echten Modul-Testskripte gegen die GPL-Originaldateien aus (nur ein Ubuntu-Runner, ohne kostenpflichtige KI-API).

**CI-Nachweis:** GitHub Actions Lauf `41340612283` (`https://github.com/wibem1/Composition-Studio/actions/runs/41340612283`), `success`. Das Log enthaelt:
- `OK: 7 GPL FilterNotesService tests (no REAPER data modified)`
- `OK: GPL v2.55 Engraver pure timing smoke tests; originals unchanged`
- `OK: Engraver rest invariants; humanized example rests: 1/16=4 (3.000 QN), 1/32=6 (3.000 QN)`.
Die Detailstatistik bezieht sich ausschliesslich auf synthetische Testnoten, NICHT auf das MIDI-Item des Nutzers.

**Weiterhin nicht verifiziert:** Realer REAPER-Lauf des neuen Pausenvergleichs, grafischer Notensatz, Verschmelzung mit `Notation Studio.lua`. Der `main`-Zweig und v0.1.24 bleiben unveraendert. Keine automatische Beseitigung oder Verlaengerung von Pausen oder MIDI-Noten.

**Naechster einzelner Schritt:** `tools/notator_gpl_rest_comparison.lua` in REAPER 7.83 mit der bekannten problematischen MIDI-Passage testen; die echten Restzahlen je Raster vergleichen. Auf Basis der Daten entscheiden, welche semantische Pausen-/Stimmeninformation in den nativen REAPER-Noteneditor uebernommen werden kann, ohne die MIDI-Performance zu veraendern.


## REAPER-Notator 2.55 – Engraver isoliert gesichert (01.11.2026)

**Neuer technischer Schritt** auf `feat/notator-gpl-rhythm-audit-20261101`, weiterhin ohne Versionsfreigabe:
- Unveraenderter GPL-3.0-Quellcode `vendor/REAPER-Notator-2.55/modules/rendering/engraver.lua` aus Commit `069821351b5d374d80788719cf951a2e01f5cf5b` hinzugefuegt. Upstream-/GitHub-Blob-SHA **08e3adfd23278f0afaa44534a4bcb715a7b056a6** nach dem Upload geprueft (identisch). Die bereits vendorten Filter- und Lizenzdateien bleiben unveraendert.
- `tools/notator_gpl_engraver_audit.lua` liest die tatsaechlichen MIDI-Notenlaengen (QN) im aktiven Take, erste vier Takte, und berechnet ausschliesslich die Notationskandidaten mit der unveraenderten Methode `Engraver.get_nominal_rhythmic_duration()`. Kein Verändern der Original-MIDI-Daten, Track-Chunks oder Partitur. Die externen Modulabhaengigkeiten `constants` und `services.octave_service` werden fuer diesen isolierten Pure-Function-Test temporaer ersetzt. Kein komplettes Rendern, keine Stimmen- oder Pausenautomatik.
- `tests/test_notator_gpl_engraver.lua` sichert erwartete Werte aus der Nutzerdiagnose: 0,240→0,250, 0,365→0,375, 0,677→0,750 und 0,135→0,125 Viertelnote, ein Taktgrenzfall und Beispiele fuer unabhaengige/gleichzeitige Tonereignisse bei der Anzeigequantisierung.

**Pruefstand:** GitHub-Originaldatei mit identischem Git-Blob-SHA bestaetigt. Skriptquellen sind auf dem Arbeitszweig gespeichert und strukturell durchgesehen. **Die neu geschriebenen Lua-Smoke-Tests sind noch nicht in einer vollstaendigen Lua-Laufzeit mit dem Engraver ausgefuehrt.** Kein REAPER-Praxistest, keine grafische Bestätigung. Keine Behauptung ueber guten Notensatz aus den Kandidatenwerten. `Notation Studio.lua` auf `main` v0.1.24 unveraendert.

**Naechster einzelner Schritt:** Zuerst den neuen lokalen Smoke-Test mit dem vendorten Gesamtmodul ausfuehren, danach den read-only Dauertest an der bekannten REAPER-Passage. Nur bei nachgewiesener Datenstabilitaet und nachvollziehbaren Ergebnissen die naechste Engraver-Funktion (Pausen-/Stimmenbehandlung) isoliert erproben. GPL-3.0-Hinweise bei jeder spaeteren uebernommenen Komponente fortfuehren.


## Notation Studio – GPL-Notator 2.55: erster Integrationsschritt (01.11.2026)

**Ausgangsstand:** `wibem1/Composition-Studio`, `Notation Studio.lua` auf `main` weiterhin v0.1.24. Der separate Arbeitsbranch `feat/notator-gpl-rhythm-audit-20261101` bleibt von PR #2 zur Quantisierungsdiagnose getrennt; keine Aenderung an der auslieferbaren App.

**Lizenzierte Quelle:** A-intheCode/ReaperNotator, v2.55, Commit `069821351b5d374d80788719cf951a2e01f5cf5b` (GPL-3.0). Die 2 uebernommenen Dateien wurden nach der Uebernahme bitgenau ueber Git-Blob-SHA verglichen:
- `vendor/REAPER-Notator-2.55/modules/services/filter_notes_service.lua` = `1407e9de593527c8dd9cfdd0980af39c1d79a9b6`
- `vendor/REAPER-Notator-2.55/LICENSE` = `f288702d2fa16d3cdf0035b15a9fcbc552cd88e7`

**Implementiert:** Unveraenderter GPL-Filter, zugehoerige vollstaendige GPL-3.0-Lizenz und Herkunftsdokumentation. `tools/notator_gpl_rhythm_audit.lua` ruft nur die Erkennung irregulaerer NotenANFAENGE in den ersten vier Takten auf, mit 1/16, 1/32 und optionalen Triolen. Nur lesend, keine MIDI-/Notations-/Track-Aenderungen. `tests/test_notator_gpl_filter.lua` enthaelt Mock-Tests ohne REAPER.

**Pruefgrundlage:** Die bitgenaue Uebernahme der beiden Originaldateien wurde im GitHub-Branch erneut bestaetigt. Die isolierte Originalroutine `is_note_regular` wurde unter Lua 5.3 (texlua) mit sieben simulierten Testfaellen erfolgreich ausgefuehrt (1/16, 1/32, Zehntick-Toleranz, Triolen, Taktgrenze). **Noch nicht** in REAPER getestet; kein vollstaendiger Lauf des vendorten Moduls und des Adapters, keine Einbindung in `Notation Studio.lua`, kein Release.

**Wichtige Lizenzgrenze:** Neue upstream-Staende sind nicht automatisch GPL; nur den exakt referenzierten alten Commit nutzen. Die GPL-3.0-Pflichten fuer uebernommene/verbreitete Kombinationen dokumentieren, Lizenzhinweise erhalten, keine Annahme einer proprietaeren Weitergabe des kombinierten GPL-Codes.

**Naechster einzelner Schritt:** Read-only-Adapter in REAPER 7.83/OSX64 an der bekannten MIDI-Passage pruefen und die Rasterstatistik mit dem bestehenden REAPER-Diagnoseergebnis abgleichen. Erst danach die Notensatz-Engine `engraver.lua` und ihre direkten Abhaengigkeiten getrennt erproben.

Stand: 23.10.2026 · Übernahme des allgemeinen Entwicklungsstandards (Dokumentationsänderung)

## Projekt und belegter Dokumentationsstand
Kompositions-/Bearbeitungsebene in REAPER; README dokumentiert v1.1.6 vom 19.10.2026 als TEST CANDIDATE.
Diese Angaben basieren auf den verfügbaren Projektinformationen; bei dieser Umstellung wurden **keine** aktuellen End-to-End-Tests, Releases oder CI-Artefakte geprüft.

## Globale Regeln
https://github.com/wibem1/AI-Development-Standards/blob/main/DEVELOPMENT_STANDARDS.md

## Nächster Schritt
Vor erneuter Entwicklung Branch, letzten Commit, offene Aufgaben und reale Testnachweise ermitteln. Genau einen kleinen nachprüfbaren Arbeitsschritt auswählen. Bestätigte Testergebnisse mit Quelle/Version hier nachtragen. Bis dahin ist die aktuelle Gesamtfunktion **nicht neu verifiziert**.
