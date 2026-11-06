# Kompaktes Musikformat – Prototyp

Für die ausdrücklich beauftragte Testfreigabe 1.4.0 gemeinsam mit der Diagnosekorrektur vorbereitet. Keine Integration der pausierten automatischen Abschnittssteuerung. Composition-Engine und Notations-PR #12 bleiben unverändert.

## Ziel und tatsächlich angeschlossener Ablauf

Ein normal formulierter Bearbeitungsauftrag für vorhandene vollständige MIDI-Items erhält weiterhin den gesamten Quellkontext. Für diesen bisherigen `NEED_MUSIC` → `composition`-Pfad nutzt Studio jetzt eine kompakte Eingabe und fordert eine kompakte Gesamtantwort an. Kein besonderer Ganztrack-Befehl, keine Zerlegung in Taktgruppen und kein neuer kostenpflichtiger Übersetzungsaufruf. Der vorhandene Controller bleibt erhalten.

Editor-/Einzelnotenauswahl und Partiturkontext behalten ihren bisherigen Vorschlagsweg und ihre Schutzregeln. Die getrennten JSON-Neukompositions-/Song-/Ganztrack- und LilyPond-Pfade werden in diesem Prototyp nicht auf ein neues Antwortformat umgestellt. Alte CS-Antworten bleiben lesbar.

## Eingabe MIDI1

Die vorhandenen Itemköpfe enthalten Quellkennung, Spur, Name und Bereich. Anschließend:

```text
MIDI1: absolute QN; columns=start,duration,pitch,velocity,channel. ITEM refers to the matching ITEM number above.
NOTES ITEM 1
1.50208,0.25,67,56,0;2,0.93751,69,78,0
NOTES ITEM 2
1.50208,1,48,80,1
```

Keine Itemkennung pro Note, keine wiederholten `N`-Präfixe und keine überflüssigen Dezimalnullen. Alle Quellnoten, ihre Reihenfolge, Quellenzuordnung, Start/Dauer, Pitch, Velocity und Kanal bleiben erhalten. Die bisherige Genauigkeit des Promptformats von fünf Nachkommastellen wird beibehalten; keine zusätzliche Rundung oder Quantisierung. Das ist Verlustfreiheit gegenüber der bisherigen übergebenen Darstellung, nicht die Behauptung, dass diese schon jeden nativen MIDI-Zeitwert vollständig abbildete.

## Ausgabe CS2-1

Eine vollständige Antwort beginnt mit `CS2|1` und endet mit `END`. Das Beispiel beschreibt 288 Viertel-Bassdrums, also 72 Takte bei 4/4:

```text
CS2|1
T|d|new|-|Drums|0|9
P|kick|1|0,0.125,36,100
R|d|kick|0|288
END
```

| Zeile | Bedeutung |
| --- | --- |
| `T\|id\|ART\|QUELLE\|NAME\|PROGRAM\|KANAL` | Stimme deklarieren; ART `new`, `revised`, `target` oder `track`; vollständige bekannte Quell-/Spurkennung, bei `new` ein `-` |
| `N\|id\|start,dauer,pitch,velocity;…` | Ausgeschriebene Noten mit absolutem Start; optional fünfter Wert als Kanalüberschreibung |
| `P\|figur\|SPANNE\|start,dauer,pitch,velocity;…` | Exakt wiederverwendbare Figur mit relativen Starts, nicht verschachtelt |
| `R\|id\|figur\|START\|ANZAHL` | Figur bei `START + j × SPANNE`, `j=0…ANZAHL−1`, einsetzen |
| `U\|SOURCE_GUID` | Quell-Item unverändert belassen |
| `C\|id\|start\|KANAL\|cc\|CONTROLLER\|WERT` | Controllerereignis |
| `C\|id\|start\|KANAL\|program\|PROGRAM` | Program Change |

Alle Zeiten in Viertelnoten-Einheiten (QN). Kanal aus `T`, sofern keine fünfte Notenzahl angegeben ist. Noten dürfen über die Figurenspanne hinaus klingen. Andere oder einmalige Passagen werden vollständig mit `N` oder eigenen Figuren beschrieben. Für ersetzende Varianten werden die entsprechenden Basiseinsätze weggelassen. Wiederholungen, Phrasenlänge und Songform werden nicht vorgegeben; Figuren sind lediglich eine technische Referenzmöglichkeit.

Der Decoder versteht auch bestehende CSMETA-Zeilen als Transportoperation. Der hier angeschlossene Bearbeitungsprompt verlangt jedoch ausdrücklich, die vorhandene Tempo-/Taktkarte zu erhalten und keine CSMETA auszugeben; bestehende Apply-Schutzregeln bleiben verbindlich.

## Lokale Expansion und Schutz

`music_model.compact` kapselt Formatierung, Spezifikation und Decoder als portable Funktionen. `music_context` verknüpft die kurze Notendarstellung mit den vorhandenen Quellköpfen. `composition_prompt` fordert CS2 nur im oben beschriebenen Bearbeitungsweg an.

`workflow_adapter.offer` dekodiert eine CS2-Kompositionsantwort lokal, bevor ein Vorschlag gespeichert wird. `raw_response` bewahrt die kompakte Originalantwort, `payload` enthält die expandierten alten CS-Operationen; `transport=CS2-1` kennzeichnet die Herkunft. Dadurch verwendet Apply unverändert den bestehenden CS-Planer, Bindings, Quell-/Originalschutz, Commit und Undo. Gespeicherte Payloads sind auch für den bisherigen CS-Verarbeiter lesbar. Keine neue Engine, kein Code aus Antworten ausgeführt und keine KI zur Expansion benötigt.

Fehlende `END`-Markierung, unbekannte Referenzen, doppelte IDs, ungültige Zahlen/MIDI-Werte, leere deklarierte Stimmen und übergroße Expansion werden vor einem gültigen kompakten Vorschlag zurückgewiesen. Vollständige Übertragung ist damit prüfbar; `END` allein beweist keine musikalische Qualität oder korrekte Umsetzung jedes Auftragsdetails. Unbekannte native Quellen/Ziele und unzulässige Tempoänderungen blockiert weiterhin der vorhandene Apply-Planer.

Grenzen: 64 Ergebnisstimmen, 128 Figuren, je 20000 expandierte Noten/Controller und 2 MB kompakte/expandierte Antwort; Zeiten von 0 bis 1000000 QN. Kein rekursives Expandieren. Die Ausgabe numerischer Werte wird ohne weiteren Präzisionsverlust aus den geparsten Zahlen in ein vom alten CS-Parser lesbares Dezimalformat überführt.

## Gemessene Größen und Nachweisgrenzen

**Keine Anbieter-Tokenmessung und keine bezahlten Aufrufe.** Prozentwerte beziehen sich ausschließlich auf Zeichen; die tatsächliche Token-/Kostenersparnis sowie die Antworttreue eines realen Modells bleiben offen.

- Letzte bereitgestellte Diagnose mit 549 Quellnoten: gesamter Prompt bisher 39144 Zeichen einschließlich gemeinsamen Regeln. Der angeschlossene kompakte Prompt mit allen Quellnoten und neuer Spezifikation liegt bei rund 16000 Zeichen, etwa **59 % weniger**. Es wurden nur Größen gemessen; keine Originalnoten oder Kennungen eingecheckt.
- Synthetischer Eingangstest mit 549 Noten: Notendarstellung 36217 → 13026 Zeichen. Sämtliche Herkunfts-/Zeit-/Pitch-/Velocity-/Kanal-Tupel inklusive Reihenfolge identisch.
- Synthetisches vollständiges 72-Takte-Beispiel mit drei Stimmen und wiederkehrenden Figuren: 10719 → 268 Zeichen (**97,5 % weniger**); expandierte Noten und bestehende Planeroperationen identisch. Das ist ein gezielt wiederholungsreiches Formatbeispiel, keine Messung einer echten KI-Komposition oder allgemeine Sparquote.
- 500 nicht wiederholte expressive Noten mit wechselnden Kanälen, ohne Figuren: 16473 → 15690 Zeichen (**4,8 % weniger**); Planeroperationen identisch. Einmalige Musik bleibt frei ausschreibbar; die Ersparnis hängt stark vom Material ab.

`tools/test_compact_music.py` prüft diese Fälle, alle Operationstypen, Ausdrucks-/Tempoereignisse, Kanalüberschreibungen, ausklingende Figurennoten, 306 numerische Rückvergleiche sowie ungültige/abgeschnittene/überlaufende Antworten. `tools/test_whole_track.py` prüft zusätzlich die tatsächliche normale Freitextroute mit Produktionsprompt, simuliertem Controller/Anbieter, Speicherung von Rohantwort/expandiertem Payload, Neuladen, einmaligem Apply und Ablehnung einer abgeschnittenen Antwort ohne Teilübernahme oder Übersetzungsaufruf.

Vollständiger Offline-Runner: 18 Python-Suiten und drei Lua-Dateien bestanden. Native REAPER-/Windows-/Hörabnahme und reale Modellantworten sind nicht geprüft. Nächster Schritt: Prototyp anhand dieser Verträge prüfen und die noch fehlende Trennung von Antwort-/Denktokens für eine belastbare spätere Anbieterbewertung berücksichtigen.
