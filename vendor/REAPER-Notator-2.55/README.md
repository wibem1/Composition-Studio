# REAPER-Notator 2.55 – GPL-3.0-Komponente

## Herkunft und reproduzierbarer Stand

- Original: https://github.com/A-intheCode/ReaperNotator
- Exakter Commit: `069821351b5d374d80788719cf951a2e01f5cf5b` (Version 2.55, 24.10.2026)
- Nachweis der Lizenz am Quellstand: `LICENSE` (GNU GPL Version 3) und `README.md` mit ausdruecklichem GPL-3.0-Hinweis.
- Uebernommene Dateien, **unveraendert**: `modules/services/filter_notes_service.lua`, `modules/rendering/engraver.lua`
- Original Git-Blob SHA des Filters: `1407e9de593527c8dd9cfdd0980af39c1d79a9b6`
- Original Git-Blob SHA des Engravers: `08e3adfd23278f0afaa44534a4bcb715a7b056a6`
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

`tools/notator_gpl_engraver_audit.lua` ist eine zweite, **nur lesende**
REAPER-Diagnose. Sie laedt den unveraenderten GPL-Engraver getrennt und
wendet ausschliesslich `get_nominal_rhythmic_duration()` auf die ersten
vier MIDI-Takte an. Sie zeigt die notierten **Kandidaten** getrennt vom
urspruenglichen MIDI-Timing; sie veraendert keine MIDI-Noten, Notenbilder
oder Projekteinstellungen. Dafuer werden fehlende `constants`- und
`services.octave_service`-Abhaengigkeiten ausschliesslich fuer den
isolierten Test durch temporaere Modul-Platzhalter ersetzt. Die
eigentliche grafische Engine wird damit **nicht** ausgefuehrt.

`tests/test_notator_gpl_engraver.lua` prueft die festen Dauerkandidaten
und einige einfache Quantisierungsszenarien als rein lokale
Smoke-Tests. Diese Tests muessen vor einer Freigabe ausgefuehrt
werden; weder deren Erfolg noch ein Realtest in REAPER ist schon
bestaetigt.

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

Nach erfolgreichem REAPER-Praxistest und den lokalen Engraver-Smoke-Tests
als naechstes die weiteren semantischen Notensatzfunktionen isoliert
untersuchen. Die vollstaendige Render-/Layout-Engine ist weiterhin **nicht**
integriert. `system_engraver.lua` hat einen grossen Abhaengigkeitsbaum und
wird nicht blind in die laufende Anwendung kopiert.
