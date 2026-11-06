# Composition Studio 1.4.1 – Ergebnisübernahme korrigiert

Auf Basis des Nutzerfehlers nach 1.4.0 als Patch-Testfreigabe über [PR #20](https://github.com/wibem1/Composition-Studio/pull/20) veröffentlicht, Merge `4ee614b5202bede74dda930a53f1221cb3c043a6`. Keine neue Kompositionsanfrage und keine Veränderung der musikalischen KI-Antwort erforderlich.

## Fehler und Korrektur

Der Screenshot zeigt die Sperre „Das Original wurde verändert“ nach einer Änderung der Medien-Item-Auswahl. Der bisherige Schutz vergleicht vollständige `GetItemStateChunk`-Texte. Diese enthalten auch das Auswahlfeld `SEL 0/1`; bereits das Abwählen eines unveränderten Items lässt den Vergleich scheitern. Die ursprüngliche Diagnose enthält keine beiden Guard-Snapshots, deshalb lässt sich die konkrete native Zustandsdifferenz rückwirkend nicht vollständig beweisen. Der reine Auswahlwechsel ist mit dem Produktionscode reproduziert.

- Nur das exakt erkannte Feld `SEL 0/1` auf oberster `<ITEM`-Ebene wird für den Vergleich ausgeblendet. Inhalt, Timing, Mute, Identität/Struktur, Spurinformationen und Tempo-/Taktkarte bleiben geschützt. Verschachtelte Felder im MIDI-/Take-Inhalt werden ausdrücklich nicht ignoriert.
- Auch bereits gespeicherte 1.4.0-Guards werden ausschließlich beim Vergleich normalisiert; gespeicherte Original-Guards behalten ihr bisheriges Rohformat. Die vorhandene Antwort bleibt nutzbar, wenn tatsächlich nur die Item-Auswahl geändert wurde; keine pauschale Aufhebung der Quellprüfung und keine automatische KI-Wiederholung.
- Der zuletzt gespeicherte Eintrag wird beim Öffnen wieder angeboten, sofern er ein noch nicht übernommener Vorschlag ist; ältere Ergebnisse bleiben über Verlauf erreichbar. „Änderungen anwenden“ liegt außerhalb des scrollbaren Chats; bereits übernommene Vorschläge zeigen diese Schaltfläche nicht. Bedienelemente passen auch bei großer Schrift in kleine Fenster.
- `apply_result` protokolliert START/SUCCESS/ERROR. `apply_guard_status` unterscheidet MATCH, SOURCE_CHANGED und MISSING_BINDING. `apply_guard_difference` benennt die erste abweichende Zeile/Feldart ohne Notenwerte oder vollständige Projektchunks zu exportieren. Bei echten Änderungen bleibt der Vorschlag gespeichert, die Übernahme gesperrt.

## Vorhandenes Ergebnis wiederverwenden

1. Das aktuell ungespeicherte REAPER-Projekt speichern, damit seine Verlaufsidentität bei späterer Wiederöffnung erhalten bleibt.
2. Studio-Menü → Update und **Studio** neu starten. Das Projekt bleibt geöffnet.
3. Der neueste fertige Vorschlag erscheint wieder. Falls nötig über **Verlauf** den vorhandenen Vorschlag auswählen.
4. **Änderungen anwenden**. Neue MIDI-Spuren werden erst bei erfolgreicher Quellprüfung erzeugt. Das Original bleibt erhalten; Rückgängig über REAPER Undo.

Den Kompositionsauftrag dafür nicht erneut an die KI senden. Wenn weiterhin eine Sperre erscheint, die Diagnose **nach dem Anwenden-Versuch** speichern; die neuen Apply-Felder zeigen den Grund. Tatsächliche Quelländerungen werden nicht blind überschrieben.

## Nachweis und Grenzen

Produktionsfunktionstest mit dem unveränderten Guard aus veröffentlichtem 1.4.0: gespeicherte kompakte Antwort, Auswahl 1→0, Save/Reload und frische Lua-Sitzung, danach einmalige Übernahme ohne Provider-/Key-Aufruf. Änderungen an Noten, Velocity, Itemposition/-länge, Mute, verschachtelten Selektionsdaten, Spuridentität, Tempo/Markern und fehlenden Items bleiben gesperrt. Tatsächliche UI-Schleife prüft die Position der Ergebnisaktion außerhalb des Chats. 64 reale Dear-ImGui-Layouts prüfen zusätzlich die sichtbare Übernahmeschaltfläche, Eingabe und Fußleiste.

Vollständiger Offline-Runner am Fix: 20 Python-Suiten und drei Lua-Dateien bestanden. Release-Kandidat einschließlich exakter Offline-Installation aus 1.4.0 mit Backup ebenfalls lokal vollständig bestanden; anschließend Ausgabe der Guard-Differenz auf feste Feldnamen beschränkt und gezielt geprüft. Alle fünf CI-Jobs am Kandidaten `c12d05d` erfolgreich, einschließlich [vollständigem Runner](https://github.com/wibem1/Composition-Studio/actions/runs/42212738082). Studio-/Installerblobs auf main entsprechen dem Kandidaten; tatsächlichen Update-Download bytegenau verglichen. Keine bezahlten Anbieteraufrufe und keine native Windows-/REAPER-Abnahme. Deshalb weiterhin Testfreigabe. Kompaktes Format und Diagnose aus 1.4.0 bleiben erhalten; Engine und Notations-PR #12 unverändert.
