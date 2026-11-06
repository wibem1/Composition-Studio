# Neue MIDI-Spuren platzieren

Status: als Testfreigabe 1.4.2 zur Veröffentlichung vorbereitet; automatisiert mit Simulation getestet. Native REAPER-Abnahme steht aus.

## Bedienung

1. Einen fertigen Vorschlag über **Änderungen anwenden** übernehmen. Die Schaltfläche steht außerhalb des scrollbaren Gesprächsverlaufs.
2. Wenn neue MIDI-Spuren mit gebundenem Quellkontext entstehen, öffnet sich ein eigener REAPER-Dialog. Seine Sichtbarkeit hängt nicht von der Scrollposition ab:
   - **Ja – einzeln:** Varianten direkt hinter ihrer jeweiligen Originalspur. Zusätzliche Stimmen ohne Originalspur werden wie bisher am Projektende eingefügt.
   - **Nein – als Block:** Alle neuen Spuren in der Reihenfolge des Vorschlags direkt hinter der letzten beteiligten Originalspur. Auch zusätzliche Stimmen ohne Originalspur gehören zu diesem Block.
   - **Abbrechen:** Keine Musik einfügen. Der gespeicherte Vorschlag bleibt verfügbar; beim nächsten Anwenden erneut auswählen. Kein neuer KI-Aufruf nötig.
3. Nach erfolgreichem Einfügen kann der gesamte Schritt über REAPER Undo rückgängig gemacht werden.

Beispiel mit zwei aufeinanderfolgenden Originalspuren und drei neuen Stimmen:

| Einzeln | Als Block |
| --- | --- |
| Piano right | Piano right |
| Techno Synth [Variante] | Piano left |
| Piano left | Techno Synth [Variante] |
| Techno Bass [Variante] | Techno Bass [Variante] |
| Techno Drums (Projektende) | Techno Drums |

Die Einstellung wird pro Übernahme gewählt. Originale werden weder dupliziert noch automatisch stummgeschaltet. Bereits eingefügte Spuren werden nicht umgeordnet.

## Technische Grenze und Nachweise

Die Auswahl liegt nach der CS-Planvalidierung und vor dem ersten nativen Schreibzugriff im gemeinsamen MIDI-Commit. Betroffen sind neu angelegte Spuren (`new`, `revised`), einschließlich lokal expandierter CS2-Antworten und in CS übersetzter JSON-Ergebnisse. Die letzte Quellspur ergibt sich aus den gespeicherten Item-/Spurbindungen des Vorschlags, nicht aus einer nachträglich veränderten Auswahl. Bei Lücken zwischen Quellen beginnt der Block hinter der letzten Quelle; bestehende Spuren außerhalb des Blocks behalten ihre relative Reihenfolge. Explizite bestehende Ziele (`target`, `track`) bleiben ihre Ziele. Ohne Quellkontext werden neue Stimmen wie bisher am Projektende erzeugt, ohne überflüssige Abfrage. Keine neuen Ordner oder Änderungen an vorhandenen Ordnerkennzeichen. Der separate LilyPond-Importweg ist nicht Teil dieser Änderung.

`tools/test_track_placement.py` prüft den Produktions-Commit mit verschiebbaren Spuridentitäten. `tools/test_proposal_guard.py` prüft den Abbruch im gespeicherten Workflow einschließlich Reload und erneutem Apply. 60 differentielle Plan/Commit-Fälle sichern die bisherige Einzelfall-Semantik; 64 reale Dear-ImGui-Layouts sichern die sichtbare Anwenden-Schaltfläche. Vollständiger Offline-Runner: 21 Python-Suiten und drei Lua-Dateien bestanden, keine bezahlten KI-Aufrufe.

Vor Veröffentlichung noch in REAPER an einer Projektkopie prüfen: beide Reihenfolgen, Quellen mit dazwischenliegenden Spuren, Abbrechen und erneutes Anwenden, Undo sowie Dialoganzeige bei nach unten gescrolltem Chat.
