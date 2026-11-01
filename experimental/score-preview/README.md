# Notation Studio – Notenbild-Test 0.2 (experimentell)

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
