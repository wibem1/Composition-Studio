# Composition Studio – Notationsmodul

## Zielsetzung

Der REAPER-Notationseditor soll zu einem echten Kompositionsarbeitsplatz erweitert werden. Die vorhandene REAPER-Notation wird nicht ersetzt, sondern durch Composition Studio komfortabler, musikalisch intelligenter und mit der KI-, Playback- und Exportebene verbunden.

Das Modul soll zwei gleichberechtigte Arbeitsweisen unterstützen:

1. **Manuelles Komponieren und Notieren** direkt im REAPER-Notationseditor.
2. **KI-unterstütztes Arbeiten** auf der aktuellen musikalischen Auswahl, z. B. „transponiere nach G-Dur“, „erfinde eine Improvisation hierzu“, „führe das Motiv weiter“, „schreibe eine Gegenstimme“ oder „optimiere den Notensatz“.

## Grundprinzip

Notation ist nicht nur Grafik. Zwischen Partitur und Wiedergabe wird eine semantische musikalische Ebene aufgebaut:

**Notation ↔ musikalische Bedeutung ↔ MIDI/Controller ↔ Instrument/Playback**

Damit sollen Spielanweisungen in beide Richtungen funktionieren. Von Composition Studio oder der KI erzeugte musikalische Absichten erscheinen im Notenbild; manuell eingetragene Angaben werden erkannt und bei der Wiedergabe berücksichtigt.

Beispiele: Triller werden hörbar ausgeführt, ritardando verändert das Tempo, crescendo steuert Dynamik/Expression, pizzicato/arco schaltet die Spielweise, Legato/Staccato beeinflusst Artikulation und Phrasierung.

## SWAM

Die vorhandene SWAM-Integration wird nicht auf eine einzelne Violine beschränkt. Ziel ist eine **mehrspurige Ensemble-Architektur** mit instrumentenspezifischen Profilen, z. B. Violine I/II, Viola, Cello, Flöte, Klarinette und weitere SWAM-Instrumente.

Eine musikalische Anweisung wird instrumentenspezifisch übersetzt. Dieselbe Angabe wie crescendo, vibrato oder legato darf bei Streicher und Holzbläser unterschiedliche Controller- und Artikulationsdaten erzeugen.

## Notensatz und Layout

Geplante Funktionen:

- Darstellungsquantisierung ohne Änderung der MIDI-Performance
- Stimmen- und Systemzuordnung
- Schlüssel, 8va/8vb, Beaming, Bindungen und enharmonische Schreibweise
- Dynamik, Artikulationen, Ornamente und Spielanweisungen
- KI-gestützte Notationsinterpretation eingespielter MIDI-Daten
- Arbeitszoom und Druckansicht
- Takte pro System, System- und Seitenumbrüche
- für A4-Ausdruck optimiertes Notenbild

## Export

Priorität hat **MusicXML** als Austauschformat für Dorico, MuseScore und andere Notensatzprogramme. Zusätzlich vorgesehen: MIDI und PDF; LilyPond kann später ergänzt werden.

## Entwicklungsprinzip

Keine neue DAW und keine parallele Spezial-App. REAPER bleibt DAW, Audio-/MIDI-Engine, Plugin-Host und Undo-System. Composition Studio ergänzt nur die Funktionen, die REAPER im Notations- und KI-Bereich fehlen.

Die Entwicklung erfolgt modular und in kleinen, testbaren Stufen. Jede Stufe muss über die bestehende eingebaute Updatefunktion ausgeliefert werden und im Infofenster klar angeben, was neu ist und was getestet werden soll.

## Phase 1 – v1.0.5 / Notation-Prototyp 0.1

Implementiert:

- neues Menü **Notation** im vorhandenen Composition-Studio-Fenster
- Anzeige der Zahl aktuell ausgewählter Noten im aktiven MIDI-/Notationseditor
- Darstellungsraster **Auto**, **1/8**, **1/16**, **1/32**
- **Originale Darstellung** zum Entfernen eigener Display-Längen
- Änderung ausschließlich der REAPER-Notationseigenschaft `disp_len`; MIDI-Noten, Anschläge und echtes Timing bleiben unangetastet
- REAPER Undo/Redo bleibt erhalten

### Zu testen

1. Notationseditor öffnen und mehrere Noten auswählen.
2. Composition Studio → **… → Notation**.
3. Auto, 1/8, 1/16 und 1/32 vergleichen.
4. Kontrollieren, dass die Wiedergabe zeitlich identisch bleibt.
5. **Originale Darstellung** testen.
6. REAPER Undo/Redo testen.

Erst nach erfolgreichem Test wird Phase 2 begonnen.


## Phase 1b – v1.0.7 / Notenbild

Der erste reale Test zeigte, dass korrekte Darstellungsquantisierung bei zu geringer horizontaler Notendichte nicht genügt. Die Lesbarkeit des Notenbilds hat daher Vorrang.

Implementiert: Lesbar machen, Breiter, Schmaler, Auswahl einpassen, Inhalt einpassen. Diese Funktionen steuern REAPERs vorhandene MIDI-Editor-Zoom-Aktionen; sie verändern keine Musikdaten.
