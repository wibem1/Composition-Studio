# Lesbare Notation erstellen

1. Den [isolierten Installer](../Composition-Studio-Semantic-Test-Install.lua) herunterladen und in REAPER über **Aktionen → Aktionsliste → ReaScript laden** einmal ausführen. Er öffnet die separate Testfassung und verwendet die vorhandene KI-Konfiguration als Vorgabe.
2. MIDI-Items im Arrangement oder einzelne Noten im MIDI-Editor auswählen und in Composition Studio **Lesbare Notation erstellen** drücken. Bei offenen Editoren haben markierte Einzelnoten Vorrang. Ohne Markierung oder Itemauswahl wird das aktive MIDI-Item im Editor verwendet.
3. Das Ergebnis erscheint in REAPERs Notenansicht. Die Statuszeile zeigt, wie viele Noten der Plan eindeutig abdeckt und wie viele Anzeigen geändert wurden. Die Notenänderungen lassen sich als ein Schritt über REAPER rückgängig machen.

Der Button stellt einen einzelnen KI-Auftrag. Aus MIDI und Taktgrenzen rekonstruiert das Modell Stimmen und rhythmische Absichten und liefert notierte Einsätze und Dauern. Das Skript prüft sie gegen die Quellnoten, die Taktmetrik und konservative Grenzen für expressive Abweichungen. Es setzt nur Anzeige-Offsets in REAPER-Notationsevents. Noten, Velocity, Controller, Pedal und Tempo bleiben erhalten. Der Editor verwendet proportionale Notenabstände und die native Triolenerkennung. Schlüssel und Notensysteme folgen der bestehenden REAPER-Konfiguration.

Der Abschnitt ist auf 500 Zielnoten begrenzt. Unsichere Deutungen, mehrdeutige Notenidentitäten, Vorschlagsnoten und bereits manuell eingestellte Anzeige-Offsets werden ausgelassen. Gepoolte, dateibasierte oder tatsächlich wiederholte MIDI-Quellen werden vor einem Schreibvorgang abgewiesen. Nach Änderungen am Quellprojekt muss der Auftrag neu gestartet werden.

## Prüfnachweis

- **Native REAPER 7.84 unter Linux:** Ein Takt mit acht leicht verspäteten und verkürzten Noten wurde aus einem vorbereiteten Modellresultat verarbeitet. Das echte Notenbild wechselte von acht einzeln geflaggten Noten mit sichtbaren Pausen zu zwei gebalkten Achtelgruppen. Die Produktionsfunktionen schrieben acht Anzeigeereignisse. Ein Vergleich der absoluten Positionen, Flags und Bytes aller übrigen MIDI-Ereignisse ergab Gleichheit. REAPER meldete Notationsmodus und proportionale Abstände aktiv.
- **Lokale Regression:** Vollständige Lua-Syntax und alle 18 Testsuiten erfolgreich, einschließlich Antwortvalidierung, Schutz bestehender Anzeigeinformationen, Abbruch bei veraltetem Projekt, Rücknahme bei Mehrspur-Schreibfehler und 64 Fensterlayouts mit sichtbarem Button.
- **Prüfgrenze:** Der native Versuch verwendete eine vorbereitete KI-Antwort und einen kontrollierten Takt. Die automatische Interpretation freier Einspielungen durch ein echtes Modell sowie die Installation unter macOS und Windows sind noch nicht praktisch abgenommen. Der Kandidat liegt im Entwicklungsbranch von PR #12.

Referenz für den MIDI-Ereignispuffer und REAPER-Notationsevents: [Cockos ReaScript API](https://www.reaper.fm/sdk/reascript/reascripthelp.html).
