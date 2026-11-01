# Projektstand – Composition-Studio

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
