# Projektstand – Composition-Studio

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
