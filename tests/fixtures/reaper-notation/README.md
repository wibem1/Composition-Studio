# Kontrollierte Test-MIDI: REAPERs eigener Noteneditor

**Stand:** 02.11.2026. Dies ist ein synthetisches, **nicht** urheberrechtlich von REAPER-Notator abgeleitetes Prüfmittel; kein neues Produktrelease. Die Datei wurde im Chat als `REAPER_Notation_Gezielter_Machbarkeitstest_8_Takte.mid` (1.451 Byte) zusammen mit einer `Testanleitung.txt` und einer maschinenlesbaren `Testreferenz.json` erzeugt. Nutzer soll **nicht** Dutzende Testläufe durchführen.

**MIDI-SHA-256:** `f55ec9c9f2d8a18174959ef7acdfcb4e703a9fe69c657d5d0bf2d49de638fbbf`.

## Format

- Standard MIDI File Type 1, 960 Ticks/Viertel, 96 BPM, g-Moll, durchgehend 4/4, **8 Takte**.
- Eine reine Meta-/Tempospur mit Abschnittsmarkierungen, dazu **3 MIDI-Instrumentalspuren und insgesamt 117 Noten**:
  - Violine (GM-Program 41, 62 Noten) → **G-Schlüssel**.
  - Bratsche (GM-Program 42, 36 Noten) → **Alt-C-Schlüssel**.
  - Violoncello (GM-Program 43, 19 Noten) → **Bassschlüssel**.
- Die Schlüsselzuordnung ist **Erwartung**, keine durch das Standard-MIDI-Format erzwungene REAPER-Anweisung. Die Instrumente müssen ggf. nach dem Import explizit ihren Notensystemen/Schlüsseln zugewiesen werden.

## Eingebaute Goldstandard-Fälle

| Takte | Kontrollierte MIDI-Bedingung | Soll-Ergebnis der **nativen** REAPER-Notationsansicht |
| --- | --- | --- |
| 1–2 | 28 Noten; metrisch exakte Onsets/Offsets, ohne Lücken | Saubere Referenznotation, keine Minipausen |
| 3–4 | Genau dieselben Tonhöhen und Einsatzzeiten wie 1–2; **nur** Note-offs um 1, 2, 4, 8, 10, 12, 28, 36, 40 oder 55 Ticks vorgezogen | Keine zusätzlich dominierenden Kleinstpausen; Note-on/-off im Original-MIDI erhalten |
| 5–6 | 19 Noten mit **absichtlichen** Lücken, darunter 1/16, 1/8 und 1/4 | Musikalisch echte Pausen **müssen erhalten bleiben** |
| 7 | Exakte Achteltriolen in der Violinstimme (12 Noten × 320 Ticks) und bis ±14 Ticks geänderte Viola-Onsets | Triolen verständlich; Vortrags-Timing nicht verschoben |
| 8 | Mehrere zeitlich überlappende eigenständige Stimmen innerhalb Violine/Bratsche, separate Cellostimme | Stimmen unterscheidbar, genug Platz und 3 getrennte Instrumentenzeilen |

## Qualitätsanforderungen

1. Horizontale Notenabstände auch in Takt 7/8 lesbar (ohne extreme Zoomtricks).
2. Keine *künstlichen* Minipausen in Takt 3/4, aber echte Pausen in Takt 5/6 sichtbar.
3. Reine **Displayquantisierung**, keine Note-on/-off-, Velocity-, CC- oder Tempoänderungen.
4. Drei Instrumentalzeilen mit G-/Alt-C-/F-Schlüssel in der REAPER-eigenen Notationsansicht.

## Prüfstand und Stop-Regel

- Erzeugt lokal und danach mit **mido** erneut eingelesen; alle 117 Noten und die speziellen Mikro-Lücken/Triolen/Polyphonie-Fälle wurden gegen die vollständige maschinenlesbare Referenz geprüft. Die erzeugte MIDI-Datei besitzt 4 MIDI-Tracks (einschließlich Metaspur).
- Ein gelungener Offline-Roundtrip beweist **nicht**, dass REAPER sie optisch korrekt darstellt.
- Benutzer wird nur zu **einem gebündelten Praxistest** in einem neuen leeren REAPER-Projekt aufgefordert, wenn die musikalische/technische Vorprüfung abgeschlossen ist. Bei einem einzelnen konkret identifizierten Fehler maximal eine gezielte Nachprüfung, anschließend Go/No-Go.
- Das bisherige `Notation Studio.lua` auf `main` bleibt unverändert; keine Programmversion ausgeliefert. Keine Eigen-Renderer-Entwicklung.
- Die Binär-MIDI-Datei und JSON-Vollreferenz sind aktuell **Konversationsartefakte**; sie wurden **nicht** in dieses GitHub-Repository hochgeladen. Der SHA-256 ermöglicht eine sichere Identifizierung, sobald die Dateien erneut bereitgestellt werden.
