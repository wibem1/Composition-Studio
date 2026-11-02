# Native REAPER Notation / Notation Studio v0.1.24 – vollständige statische Codeprüfung

Datum: 02.11.2026
Repository: `wibem1/Composition-Studio`, Branch `main`
Untersuchte Datei: [Notation Studio.lua](../Notation%20Studio.lua), 729 Zeilen, Blob-SHA `48274e5767c8d756543bf7fa3a0b9108b639a272`
Anlass: Nutzer hält Grundkonzept mit REAPER-nativer Notenansicht und KI-Anbindung für ausbaufähig, meldet jedoch: `Lesbarkeit verbessern` verschlechtert die Darstellung.

**Nachweisstufe:** Vollständiger Quellcode gelesen, alle 37 lokalen Funktionen und die UI-Aktionen inventorisiert, bestehende Projektberichte/Handbuch-/API-Audits abgeglichen. **Keine neue REAPER-Ausführung, kein Lua-Laufzeittest, kein API-KI-Aufruf, keine Implementierung und keine neue Version**. Anwenderbericht über die reale Verschlechterung ist ein konkreter negativer Praxishinweis, aber keine isolierte Ursachenmessung.

## Leitentscheidung

- **Bestehenden REAPER-eigenen MIDI-Notationseditor und vorhandene ReaImGui-Bedienoberfläche behalten.** Keine neue Notensatzengine und kein Neuanfang.
- v0.1.24 unverändert als Referenz erhalten. Neue Schritte klein, reversibel, einzeln testbar.
- Keine pauschale Umprogrammierung von Note-on/Note-off oder Performance-MIDI; Anzeigeeigenschaften und gezielte Notationsmetadaten bevorzugen.
- Gemäß `NOTATION-MODULE.md` gelten vier vorrangige Qualitätsziele: bessere Abstände, künstliche Minipausen erkennen statt echte Pausen löschen, reine Displayquantisierung, instrumentengerechte Notenzeilen/Schlüssel.
- Direkte, frei wählbare Taktbreiten, professionelle Kollisionsberechnung und mehrzeilige Mehrspur-Seitenlayouts sind keine nachgewiesenen Möglichkeiten der dokumentierten REAPER-API. Hier Grenzen offen benennen.

## 1. Funktionsinventar

| Bereich | Tatsächlich implementiert (Code) | Fehlend oder eingeschränkt | Beleg |
|---|---|---|---|
| Start/Fenster | Eigenes ReaImGui-Fenster, Titel, Status, Schrift, klappbare Gruppen, Update-Menü | Fehler bei nicht sichtbarem/collapsed `ImGui_Begin`; kein verlässlicher Fensterabschluss bei laufender KI | 18–36, 636–729 |
| Bindung an REAPER | Aktiver MIDI-Editor und aktive/editierbare Takes, MIDI-Note-Auswahl, Spurbezeichnungen | Alter Editor-Handle bleibt nach Schließen als Fallback erhalten, Validität nicht konsequent geprüft; mehrere editierbare Takes versus aktive Spur uneinheitlich | 205–212, 243–269, 539–576 |
| Basis-Abstände | Proportionale Abstände einschalten/ausschalten, Breiter/Schmaler, Inhalt/Auswahl einpassen, vertikaler Zoom | Keine pro-Takt-Breite, Kollisionen oder Notenkopf-Abstände; Action-Status teilweise unzuverlässig | 213–250, 326–355, 659–669 |
| Anzeigequantisierung | Schaltflächen 1/8, 1/16, 1/32 | Fehlende Statusanzeige, Auto und Reset, kein sicherer pro-Spur-Setter, keine intelligente Rasterwahl | 672–676 |
| Sammeloptimierung | `cleanup_notation`: mehrere native Befehle/Zoom/Schlüssel | Keine musikalische Prüfung, keine Vorschau, kein Gesamt-Undo, keine Erfolgskontrolle des Notenbilds | 442–534 |
| Stimme/Schlüssel | Einfache Namens- und Tonhöhenheuristik, bedingte Auto-Voicing-Umschaltung, `SCORE`-Chunk-Schreibzugriff | Keine robusten per-Track-Profile/Mehrspur-Stimmtrennung; Chunk-Verfahren undokumentiert; kein Grand-Clef-Schreiben | 357–440, 479–509 |
| Minipausen | KEIN individueller `disp_len`-Korrekturcode im aktuellen Skript | Keine Unterscheidung künstlicher Kurzlücken/echter Pausen; kein Änderungsbericht/Reset je Note | gesamt, vgl. `docs/REAPER-NATIVE-NOTATION-REUSE-AUDIT-2026-11-02.md` |
| KI-Anbindung | Drei Anbieter-Pfade (OpenAI, Anthropic, Google), Voranalyse, Artikulations-/Dynamikkommentar, freier Textauftrag, Anzeige Textantwort | Keine direkte Übernahme in REAPER, kein Dialog/Iterationsverlauf, keine sichtbaren Provider-/Modell-Auswahlelemente in diesem Fenster, keine Kostenobergrenzen | 5–18, 135–163, 555–634, 678–695 |
| Weitere UI-Gruppen | Überschriften Stimmen/Notation, Artikulation, Dynamik, Spielweise/SWAM | Nur Beschreibungstext, keine Bedienelemente/Ausführungslogik in diesen Gruppen | 698–711 |
| Update | Download von GitHub, Versionsvergleich, Syntaxprüfung, Sicherungsdatei | Kein atomarer Austausch, keine automatische Rollback-Garantie nach teilweisem Schreibfehler, Posix-`curl`-Abhängigkeit | 51–108 |

## 2. Kritische Quellcodebefunde

### P0-A – Lesbarkeit: kein Optimierer, sondern unkontrollierte Sammelaktion
`cleanup_notation()` (442–534) schaltet proportionale Abstände an, versucht Quantisierung auf 1/16 und Minimum 1/64, Triolen-Ein, wechselnde automatische Stimmenzuordnung, Schlüsselumschreiben, Continuous-View-Aus, setzt horizontalen Zoom anhand markierter Noten und führt **bei jedem Aufruf drei vertikale Zoom-in-Aktionen** aus. Keine Untersuchung, ob jeder Schritt nötig ist. Keine Vorher-/Nachher-Bewertung, kein globales Undo/Restore. Diese Logik ist mit dem negativen Nutzerbefund konsistent; der exakte einzelne Verursacher wurde noch nicht in REAPER isoliert.

### P0-B – Unscharfe Aktionssuche, fehlerhafte Toggle-Interpretation
`find_action_variants()` (193–204) sucht Teilstrings in enumerierten Action-Labels, nimmt ersten Treffer. Insbesondere der Fallback `{"notation","1/16"}` in 458–461 ist **nicht eindeutig** und kann eine andere 1/16-Notationsaktion statt der Anzeigequantisierung wählen. `execute_found` behandelt unbekannten Toggle-Status als Anlass zum Ausführen. `spacing_state()` (234–239) bildet `-1` fälschlich auf `false` ab. `set_toggle()` (225–232) wird nirgends benutzt. Aktionslabels können REAPER-Version und Lokalisierung variieren. Erfolg = 'Befehl aufgerufen' ist kein Beweis der grafischen Wirkung.

### P0-C – Undokumentiertes Track-State-Überschreiben
`set_default_clef_chunk()` (413–440) ersetzt die erste auf `SCORE ...` passende Textsequenz durch `SCORE 0 <clef> 0 0`, oder fügt sie nach der ersten `VU`-Zeile ein, und schreibt via `SetTrackStateChunk`. Kein struktureller Parser, keine Sicherung anderer SCORE-Felder, keine Prüfung auf unterschiedliche Chunks oder Sonderfälle; bei `grand` wird die Änderung übersprungen. Der Profilvorschlag aus mehreren Takes wird auf **nur den aktiven Track** angewandt. Risiko für bestehende Projekte; Funktion vorerst aus automatischem Modus herausnehmen.

### P0-D – UI: fehlerhafte Begin/End-Paarung
`draw()` (636–719): `reaper.ImGui_End(ctx)` wird ausschließlich innerhalb von `if visible then ... end` aufgerufen. Die Dear-ImGui-Vorgabe verlangt **immer** das passende `End` nach `Begin`, auch bei `visible=false` (zusammengeklappt/verdeckt). Potenzielle Assertion-/Stackfehler. Externe Quelle: https://skia.googlesource.com/external/github.com/ocornut/imgui/+/104f58fc4844ed26243b4188b78d497a7a7cd30f/imgui.h .

### P1-A – Auswahl-/Zoomheuristik berücksichtigt Musik nur oberflächlich
`selected_note_stats()` und `apply_readable_scale()` (252–269, 326–355): Zählt ausgewählte Noten und verteilte Takte, wählt 80/90/105/120 Pixel pro Viertelnote. Erfasst weder Akkord-/Vorzeichenbreiten noch Nachbarsysteme, Pausen, Fensterbreite oder tatsächliche Kollisionen. Ein Notenende exakt am Taktstrich kann den letzten Taktindex vergrößern; alle Änderungen sind globaler Zoom statt gezielter Layoutkorrektur. `Master_GetTempo()` berücksichtigt bei Umrechnung Zeit-/Beat-Skalierung keine komplexe Tempokarte. Keine Auswahl => nach vorherigen Sammelschritten nur Fehlermeldung für Zoom.

### P1-B – Offene Editor- und Mehrspur-Zustände
`active_editor()` (205–212) behält einen früheren `midi_editor`-Pointer, wenn `MIDIEditor_GetActive()` nil liefert. Dieser Pointer kann nach Editor-Schließung ungültig sein. `count_visible_tracks()` (295–313) zählt anhand enumerierter Takes Tracks, aber validiert nicht unabhängig, was im Notenlayout tatsächlich sichtbar ist. `selected_track_profile()` (357–388) kann bei Mischselektion Name/Tonhöhen verschiedener Spuren vermengen.

### P1-C – KI-Kontext nicht ausreichend für behauptete Analyse
`selection_context()` (551–576): nur Trackname, Start-/Dauer-QN, Pitch, Velocity, Channel markierter, nicht stummgeschalteter Noten. Es fehlen beispielsweise Tonart, Taktart, Tempoverlauf, notierte Stimmen, Artikulation/Dynamikmarkierungen, Pedal/Controller und musikalischer Kontext außerhalb der Auswahl. 'Artikulation / Dynamik beurteilen' kann daher allenfalls Vorschläge aus rohen Noten ableiten, keine vollständige Bewertung der tatsächlichen Partituranweisungen.

### P1-D – KI-Betrieb, Plattformen, Datenschutz und Fehler
`send_ai()`/`poll_ai_result()` (578–634): harte Modelllisten (5–11), keine Modellwahl in der vorliegenden UI (nur `model_label()`), kein Preis-/Tokenbudget, kein Abbruch, keine robuste Anbieter-JSON-Auswertung und nur einfacher HTTP-Status. OpenAI/Google haben im Skript kein explizites Antworttokenlimit; Anthropic `max_tokens=8000`. API-Schlüssel landen persistent im REAPER-ExtState und im curl-Aufruf (Header bzw. Google-URL); keine ausdrücklich geprüfte sichere Schlüsselspeicherung. `/usr/bin/curl` und Hintergrundkommando `&` sind Unix/macOS-spezifisch, daher Windows-Unterstützung nicht belegt. `read_json_string` implementiert `\\u`-Unicode-Sequenzen nicht korrekt. `os.execute`-Fehler sowie Hänger ohne Ergebnisdatei werden nicht sauber ausgewertet. Fenster schließen, während die KI läuft, kann temp. Dateien/Antworten zurücklassen.

### P1-E – Update-Sicherheit
`install_update()` (67–108): Versions-/Syntaxkontrolle und `.backup` sind positiv. Aber Zieldatei wird direkt im Schreibmodus ersetzt; bei teilweisem Schreibfehler gibt es **kein automatisches Zurückkopieren** aus dem Backup. Download und Neustart sind Unix-spezifisch; keine vollständigen REAPER-Plattformtests. Updatefreigaben deshalb gesondert absichern.

### P2 – UI-/Funktionslücken
- In den Gruppen 'Stimmen / Notation', 'Artikulation', 'Dynamik', 'Spielweise / SWAM' stehen nur Texte (698–711), obwohl sie wie Funktionsbereiche aussehen.
- Kein Diagnose-/Exportmechanismus aus diesem eigenständigen Notation-Studio-Skript, kein Protokoll konkret veränderter REAPER-Eigenschaften, keine integrierte Rücksetzschaltfläche für automatische Optimierungen.
- Kein eigenes ReaScript für `NOTE ... disp_len`/`disp_pos`, Beaming-Gruppen oder gezielte Minipausenbearbeitung, obwohl bestehende ReaTeam-Skripte technisch relevante Grundlagen demonstrieren.
- Kein dialogischer KI-Überarbeitungsprozess, keine validierte strukturierte KI-Antwort mit Vorschau, keine Übernahme von Ergebnisnoten.
- Nur 1/8–1/32 direkt verfügbar; sinnvolle Triolen-/1/64-/Auto-Konfiguration muss instrumentabhängig und auf echte REAPER-Steuermöglichkeiten begrenzt bleiben.

## 3. Belastbare Negativ- und Sicherheitsfeststellungen

- Im Skript finden sich **keine direkten** Aufrufe von `MIDI_SetNote`, `MIDI_SetAllEvts`, `MIDI_InsertTextSysexEvt`; es schreibt selbst keine Note-on/off-Ereignisse. Unbekannte/falsch ausgewählte REAPER-Aktionen dürfen dennoch nicht pauschal als garantiert nichtdestruktiv gelten.
- Die KI führt im heutigen Code **keine** REAPER-Notenbearbeitung aus. Textantwort ist Beratung.
- Die bisherige Lesbarkeitsfunktion ist **nicht idempotent** (vertikale Zoomschritte wiederholen sich) und **nicht atomar** (vorherige Änderungen bleiben bei späterem Fehlversuch bestehen).
- Durch den Anwender sind schlechte Ergebnisse dieser Funktion beobachtet; Detailursachen sind erst statisch eingegrenzt, nicht einzeln im echten Editor isoliert.
- Die vier Qualitätsziele sind noch **nicht** als gleichzeitig erreicht nachgewiesen. Die grundsätzlich gleichen Taktbreiten aus dem jüngsten Nutzervergleich sind eine REAPER-interne Grenze und werden durch einen neuen Button nicht verschwinden.

## 4. Erhaltenswerte Teile

1. Kleine, direkt mit REAPER verbundene ReaImGui-Palette statt separater App.
2. Konkrete Buttons für Abstand, Zoom und Anzeigequantisierung.
3. Zugriff auf aktuelle MIDI-Auswahl mit Spurnamen und musikalischer Zeitposition.
4. KI als optionaler Analyseassistent, ohne automatische ungeprüfte Eingriffe.
5. Bestehender Updater als Grundbaustein, nach Absicherung.
6. Instrument-/Schlüsselprofile als Idee, aber nicht das Chunk-Schreibverfahren.
7. Bestehende v0.1.24-Datei als reproduzierbare Referenz; keine Vermischung mit abgebrochenem eigenem Score-Preview-Branch.

## 5. Entwicklungsvorschlag: kleine isolierte Schritte

**Schritt 1 (als nächstes): Sicherung und Entschärfung der bestehenden Lesbarkeitsfunktion.**
- Unverändertes v0.1.24 als Referenz.
- Eindeutige Aktionsauflösung statt unscharfer Treffer, unbekannte Toggle-Zustände melden statt schalten.
- `SCORE`-Chunk-Schreiben und zwanghaften vertikalen Zoom **aus der Sammelautomatik entfernen**, separat belassen nur wenn sicher nachgewiesen.
- Anzeige eines Änderungsplans statt ungefragten Ausführens; REAPER-Optionen nur nach eindeutiger Rückmeldung setzen. Keine Note-on/off-Eingriffe.
- ImGui-Begin/End-Paarung und veraltete Editorhandles korrigieren.
- Isolierte simulierte REAPER-API-Tests (Toggle-Status -1/0/1, falsche/fehlende Aktionen, mehrere Spuren, wiederholter Klick, fehlende Selektion, Projekt unangetastet). **Kein** Schluss auf Notensatzqualität aus Mocktests.

**Schritt 2: Instrumentprofile/Displayquantisierung mit überprüfbarem Zustand und Reset.** Keine universelle 1/16/1/64-Regel. Manuelle Korrekturmöglichkeit beibehalten.

**Schritt 3: Nur nach grafischem Wirknachweis selektive Mikro-Pausenprüfung via `disp_len`, mit Kandidatenliste, echten Pausen erhalten, Rücknahme, Audit und separatem MIDI-Event-Vergleich.** Bestehende ReaTeam-Techniken als Schnittstellen-Nachweis, fremden Code nur nach Lizenzprüfung kopieren.

**Schritt 4: KI-Anbindung robuster/verständlicher machen und optionale Umsetzung strukturierter Vorschläge mit expliziter Bestätigung.** Kostenlimit, Provider-/Modellwahl, Abbruch, Fehlerprotokolle, Kontextqualität, Plattformvergleich.

**Schritt 5: Nachweislich sinnvolle Artikulations-, Dynamik-, Staff-/Voice-Funktionen hinzufügen.** Platzhalter nicht vorspiegeln; SWAM und Export erst nach eindeutiger Priorisierung.

## 6. Test- und Freigabekriterien

- `main`-Skript bleibt ohne Produktänderung; erst isolierte Änderungen auf eigenem Branch.
- Vorher/Nachher auf derselben REAPER-Test-MIDI: echte Pausen, Kurzlücken, Triolen, Mehrstimmigkeit, mehrere Tracks. Bestehende 8-Takt-Testfixture ist beschrieben in `tests/fixtures/reaper-notation/README.md`, Binärdatei nach letztem PROJECT_STATE bislang nur im Chat.
- Identische originale MIDI-Note-on/off-, Velocity-, CC-/Tempo-Events, sofern nicht ausdrücklich Bearbeitung genehmigt.
- Keine unbekannten REAPER-Aktionen, keine ungefragte Schlüssel- oder Projektdatenmutation.
- Wiederholtes Klicken darf keine zusätzlichen Veränderungen verursachen; Reset muss wirken.
- Erst isolierte automatisierte Tests, dann höchstens **ein** gebündelter REAPER-Praxistest, gegebenenfalls eine gezielte Nachprüfung.
- Keine neue Versionsnummer/Veröffentlichung ohne nachgewiesene Tests.

## Quellen

- [Notation Studio.lua v0.1.24](../Notation%20Studio.lua)
- [PROJECT_STATE.md](../PROJECT_STATE.md)
- [NOTATION-MODULE.md](../NOTATION-MODULE.md)
- [REAPER-Notationssteuerbarkeit](REAPER-NOTATION-STEUERBARKEIT-2026-11-02.md)
- [ReaTeam-Wiederverwendungsanalyse](REAPER-NATIVE-NOTATION-REUSE-AUDIT-2026-11-02.md)
- [Dear ImGui Begin/End-Vertrag](https://skia.googlesource.com/external/github.com/ocornut/imgui/+/104f58fc4844ed26243b4188b78d497a7a7cd30f/imgui.h)
