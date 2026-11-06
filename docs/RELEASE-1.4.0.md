# Composition Studio 1.4.0 – Testfreigabe

Auf ausdrücklichen Nutzerauftrag zur gemeinsamen Veröffentlichung von [PR #17](https://github.com/wibem1/Composition-Studio/pull/17) und [PR #18](https://github.com/wibem1/Composition-Studio/pull/18) vorbereitet. Beide freigegebenen Implementierungsstände sind als Vorfahren im gemeinsamen Release-Branch enthalten; keine Übernahme der pausierten automatischen Abschnittssteuerung. Engine und Notations-PR #12 unverändert.

## Bedienung

Nach Veröffentlichung **Studio-Menü → Update**, danach Studio neu starten. Die vorherige Skriptdatei wird vom Updater gesichert. Erste Gegenprobe an Projektkopie.

Für die kompakte Bearbeitung beide vollständigen MIDI-Items auswählen und den Auftrag **normal** eingeben, beispielsweise:

> Erstelle eine Techno-Version dieser beiden Tracks mit einer Synthie-, einer Bass- und einer Drums-Spur. Bearbeite die gesamte Länge.

Der normale Bearbeitungsweg erhält das gesamte Quellmaterial in kompakter Darstellung. Die KI darf wiederkehrende Figuren einmal beschreiben und referenzieren oder einmalige Passagen vollständig ausschreiben. Studio expandiert die Antwort lokal in die vorhandenen CS-/MIDI-Operationen. Keine festen Taktgruppen und keine zusätzliche KI-Übersetzung. Übernahme weiterhin erst mit **Änderungen anwenden** auf Basis der bestehenden Schutzregeln.

Der ausdrücklich gewählte `Ganzer Track:`-Ablauf aus 1.3.0 bleibt separat verfügbar; dieser Befehl wird für den hier beschriebenen kompakten Bearbeitungsweg nicht benötigt. Bestehende JSON-Neukompositions-/Song-/LilyPond- und gezielte Editorpfade behalten ihre Antwortformate.

Die Diagnose weist für künftige Aufrufe Eingabe, Antwort und Denken getrennt aus, soweit vom Anbieter verfügbar, und zeigt Kostenanteile, Stufe und tatsächlich angefordertes Limit. Verfügbare sichtbare Teilantworten bei Tokenabbruch/Timeout werden begrenzt gespeichert, als unvollständig gekennzeichnet und nicht importiert. Die Felder bleiben nach Neustart erhalten. Frühere verlorene Aufteilungen lassen sich nicht wiederherstellen.

## Prüfgrundlage und Grenzen

Beide Ausgangs-PRs jeweils mit fünf erfolgreichen CI-Jobs. Gemeinsamer Integrationsstand lokal mit **19 Python-Suiten und drei Lua-Dateien** bestanden. Release-Kandidat einschließlich exakter Offline-Installation aus 1.3.0 mit Backup ebenfalls lokal mit 19 Python-Suiten und drei Lua-Dateien bestanden. CI am endgültigen Kandidaten vor Merge und nach Merge die tatsächlichen Updatebytes abgleichen.

Gemessene Zeichenersparnis: etwa 59 % für den gesamten Prompt der bereitgestellten 549-Noten-Quelle; im synthetischen wiederholungsreichen 72-Takte-Dreistimmer 97,5 %, bei 500 nicht wiederholten expressiven Noten 4,8 %. Alle verglichenen Ereignisse/Planeroperationen bleiben erhalten. **Keine gemessene reale Token-/Kosteneinsparung, keine zugesicherte Reduktion der Denktokens oder garantierte erfolgreiche Modellantwort.** Kostenpflichtige KI-Aufrufe bleiben kostenpflichtig, auch bei einem Abbruch.

Tests mit Produktionsfunktionen, simulierten Anbietern/REAPER und echtem lokalem HTTP-Transport. Keine kostenpflichtigen Anbieteraufrufe, keine native Windows-/REAPER-/Hörabnahme. Daher Testfreigabe.

[Format und Verträge](COMPACT-MUSIC-TRANSPORT.md) · [Diagnosefelder und Begrenzungen](TOKEN-DIAGNOSTICS.md) · [Ursachenanalyse](TOKEN-CONSUMPTION-AUDIT-2026-11-05.md).
