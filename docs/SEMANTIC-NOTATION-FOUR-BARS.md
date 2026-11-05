# Musikalische MIDI-Interpretation – erster Befund (04.11.2026)

Status: **analytisch geprüft, nicht in REAPER integriert**. Vier Takte, 42 MIDI-Noten. Grundlage sind die lokalen Testartefakte `Composition_Studio_4_Takte_Interpretation.json` und `Composition_Studio_Notationstest_4_Takte.mid`. Die bisherige RH/LH-Zuordnung stammt aus einer Referenznotation und ist **keine unabhängige KI-Transkription**.

| Takt | Melodie (MIDI-Pitches als Notennamen) | Bassgrundton | Deutung |
|---|---|---|---|
| 1 | A4 C5 E5 Cis5 D5 C5 H4 | A | Dreiklangsaufstieg, fallende Linie; Cis vor D als chromatischer Vorschlag plausibel |
| 2 | C5 E5 G5 Fis5 F5 E5 D5 | F | melodischer Höhepunkt und Abstieg; Fis vor F als Vorschlag plausibel; **E5 unklar** |
| 3 | E5 D5 C5 H4 A4 | G | zusammenhängender melodischer Abstieg |
| 4 | C5 H4 B4 A4 As4 H4 A4 | A | chromatische Spannung und Rückkehr nach A; As ist regulärer melodischer Ton |

Arbeitshypothese Harmonik: A-Moll – F-Dur – G-Dur – A-Moll (i–VI–VII–i). Der Bass besteht weitgehend aus Quinten und beweist die Akkordqualitäten allein nicht.

**Konkreter Befund n15 (E5, Takt 2):** Originalbeginn 4,732292 QN, Ende 4,919792 QN, nächste G5 beginnt 5,025 QN. E5 dauert 0,1875 QN, Abstand der Anfänge 0,292708 QN. Eine pauschale Einstufung als Vorschlagsnote ist musikalisch nicht belegt. Daher **unentschieden**, keine automatische Ornament-Markierung.

Die bisher als Vorschläge bezeichneten n06, n17, n36 bleiben musikalisch plausible, aber unbestätigte Hypothesen. Keine automatischen Notationsänderungen aufgrund der MIDI-Kürze allein.

**Verbindliche Implementierungsregel:** Erst semantische Entscheidungen pro Note (Rolle, rhythmische Absicht, Sicherheit, Begründung, Alternativen), dann selektive Notationsmetadaten. Originale MIDI-Note-on/-off-, Velocity- und Controller-Daten unverändert lassen. Unklare Stellen nicht automatisch überschreiben. Als nächstes eine prüfbare semantische Datenstruktur und die Anbindung an die vorhandene Composition-Studio-KI-Pipeline entwickeln; danach **ein** gemeinsamer REAPER-A/B-Test mit vier Takten. Keine neue Version/Freigabe.
