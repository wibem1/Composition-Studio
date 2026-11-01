# REAPER-Notator 2.55 – GPL-3.0-Komponente

## Herkunft und reproduzierbarer Stand

- Original: https://github.com/A-intheCode/ReaperNotator
- Exakter Commit: `069821351b5d374d80788719cf951a2e01f5cf5b` (Version 2.55, 24.10.2026)
- Nachweis der Lizenz am Quellstand: `LICENSE` (GNU GPL Version 3) und `README.md` mit ausdruecklichem GPL-3.0-Hinweis.
- Uebernommene Datei, **unveraendert**: `modules/services/filter_notes_service.lua`
- Original Git-Blob SHA dieser Datei: `1407e9de593527c8dd9cfdd0980af39c1d79a9b6`
- Original Git-Blob SHA von `LICENSE`: `f288702d2fa16d3cdf0035b15a9fcbc552cd88e7`
- Autor und Copyright: A-intheCode, (C) 2026

Die Dateien in diesem Unterverzeichnis wurden unveraendert aus dem bezeichneten GPL-Quellstand uebernommen.
Der Quellstand **nach** dem 31.10.2026 traegt eine andere Lizenz; dieser ist **nicht** die Quelle
der hier gesicherten Dateien. Auch ein spaeterer GitHub-Updatepfad darf diese Quelle nicht stillschweigend ersetzen.

## Verwendung in Composition-Studio

`tools/notator_gpl_rhythm_audit.lua` laedt ausschliesslich die vorhandene
`FilterNotesService.is_note_regular()`-Funktion, um Startpositionen von MIDI-Noten
mit 1/16-, 1/32- und optionalem Triolenraster zu vergleichen. Dieses Testskript ist
eine eigenstaendige Integration unter **GPL-3.0** und soll beim Weitergeben mit
den Lizenz- und Originalquellenhinweisen erhalten bleiben.

Der Originaldienst enthaelt weitere Funktionen, die beim Aufruf MIDI-Noten
umklassifizieren oder veraendern koennen. **Diese werden nicht verwendet.**
Der Audit-Bericht analysiert nur Notenanfangswerte, keine Endzeitpunkte,
Notenbild-Pausen, Dauer oder Stimmenzuordnung. Kein Einfluss auf Wiedergabe.

Zurzeit ist der GPL-Code **nicht** mit dem Hauptskript `Notation Studio.lua`
vermischt. Der vorhandene Hauptprogrammstand auf `main` bleibt unangetastet.

## Lizenz- und Integrationsgrenzen

Die GNU GPL-3.0 erlaubt Weitergabe und Bearbeitung unter Bedingungen. Vor einer
groesseren Verschmelzung mit dem Hauptprojekt sind Lizenzkompatibilitaet,
Quellcodebereitstellung und Hinweis-/Lizenzpflichten fuer das verbreitete
Gesamtwerk zu klaeren. Private Nutzung und unabhaengiger Test sind davon
zu unterscheiden. Keine pauschale Behauptung, die gesamte neueste REAPER-Notator-
Version sei GPL-lizenziert.

## Naechste Stufe (nicht umgesetzt)

Erst nachdem der REAPER-Praxistest des unveraenderten Erkennungsmoduls
abgeschlossen ist, die eng zusammenhaengenden Notensatzkomponenten gezielt
pruefen: `modules/rendering/engraver.lua` (hat Abhaengigkeiten zu
`constants` und `services.octave_service`) sowie getrennt
`modules/rendering/system_engraver.lua` (groesserer Abhaengigkeitsbaum).
Nicht blind die vollstaendige Engine in die laufende Anwendung kopieren.
