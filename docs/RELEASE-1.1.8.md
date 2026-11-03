# Composition Studio 1.1.8 – Testfreigabe vom 03.11.2026

## Veröffentlichung

Auf ausdrücklichen Nutzerauftrag wird die vorhandene Integration aus PR #9 abgeschlossen und über die bestehende `main`-Update-Linie freigegeben. Installation: **Studio-Menü → Update**. Header `-- @version` und `local VERSION` sind einheitlich **1.1.8**; die bestehende Versionsprüfung akzeptiert das Update von 1.1.7. Keine neue Anwendung, keine Datenmigration oder neue Installationsmethode. Der vorhandene Offline-Wiederherstellungsinstaller wurde aus den identischen aktuellen Skriptbytes neu erzeugt; der vorhandene separate Updater bleibt unverändert.

## Funktionsumfang und gezielte Korrekturen

- Arrangement, native Notenansicht und Piano-Roll liefern Material für den vorhandenen Analyse-/Kompositionsworkflow. Die Ansichten des MIDI-Editors teilen dieselbe Auswahllogik.
- Markierte editierbare Noten sind das exakte Ziel. Andere sichtbare Stimmen werden getrennt als read-only Referenz übergeben (±2 QN, maximal 160 Referenznoten; Kürzung sichtbar). Über 2500 Noten im Gesamteditor-Kontext: klare Ablehnung.
- Direkte Einzelnotenbearbeitung: nur Pitch/Velocity, gespeicherter Vorschlag, ausdrückliches Anwenden, Quellprüfung und Undo. Keine neuen Rhythmus-/Einfüge-/Löschfunktionen.
- Abschlusskorrektur: gespeicherte Analyse → Revision erweitert den Bereich nicht auf weitere Items der gebundenen Spuren; Einzelnotenidentität, Partiturschutz und harmonischer Kontext bleiben erhalten. Varianten entstehen separat; Originalspuren sind gegen CS|target und CS|track geschützt.
- Fortsetzung markierter Einzelnoten wird sicher abgewiesen; ganze Arrangement-Items bzw. ausdrücklich der Editor dienen als Fortsetzungsquelle. Editorbezogene Komposition überspringt nicht versehentlich ihren Kontext.
- Veraltete Testfixtures wurden angepasst: JSON-Ideenprotokollierung liegt im vorhandenen Workflow-Adapter, fehlender MIDI-Editor wird im Starttest korrekt als nil simuliert; Layout-/Texttests erhalten die benötigten Editor-Stubs.

## Tatsächlich ausgeführte Prüfung

Lokale Ausführung mit Python/lupa **Lua 5.4**, ohne bezahlte Anbieteraufrufe:

| Prüfung | Ergebnis |
|---|---|
| Vollständiger Produktionscode: Lua-5.4-Syntax | bestanden |
| tests/json-bridge-test.lua | bestanden; JSON, Aufrufpfade, Protokollierung |
| tests/test_notation_selection_integration.lua | bestanden; Auswahl, direkte KI-Patches, veraltete Quelle, Kollisionen, Undo, unberührte Noten/CC |
| tests/test_score_workspace_bridge.lua | bestanden; sichtbare Takes, beide Ansichten, native Aktionen, Limits, fehlender Editor/Shortcut, gespeicherte Analysebereiche, Referenzschutz, verbotene Übernahmen, Einzelnoten-Fortsetzung |
| tools/test_lilypond_import.py | 33 Prüfungen bestanden; Start, Import, Übergänge, Updatevalidierung, Backup, Rename-Rollback, Startfehler-Rollback; echter LilyPond-Compiler ausgelassen |
| tools/test_layout.py | 64 echte Dear-ImGui-Layouts bestanden; REAPER-Aufrufe simuliert |
| tools/test_cost_accounting.py | 32 Prüfungen bestanden |
| tools/test_reasoning.py | 28 Anbieter-/Denkmodusfixtures plus Kostenregression bestanden |
| tools/test_text_workflow.py | Text-/Controllerpfade und Arrangement-Fortsetzungen bestanden |
| tools/test_workflow_core.py | gespeicherte Vorschläge, Quellschutz, Analyse → Revision, Kataloge und JSON bestanden |
| tools/test_model_transport.py | echter curl gegen lokalen HTTP-Server; Unix-Startpfad, Kataloge und Fehlerbehandlung bestanden |
| tools/test_update_helper.py | Installation, Fallback, Abbruch, Fehler und Backup bestanden; zusätzlich echte 1.1.7-Quellbytes → 1.1.8 unter Unix-/Windows-Transportmocks |
| tools/test_offline_installer.py | Installation mit bytegenauer Sicherung aus 1.1.7 und vier älteren Ständen sowie sieben Fehler-/Nichtupdatefällen bestanden |
| git diff --check | bestanden |

Die GitHub-CI-Resultate und der abschließende Merge-/Update-Abgleich werden in `PROJECT_STATE.md` ergänzt. Diese Tabelle behauptet keinen nativen Windows-/macOS-REAPER-Test.

## Ausstehende Praxisprüfung

Kein laufendes REAPER, keine reale REAPER-7.83-GUI, keine echte KI-Analyse/-Komposition und kein realer Menü-/Netzwerk-/Neustarttest. Native Aktionsnamen können von REAPER-Version/Sprache abhängen; bei fehlender bekannter Aktion gibt es eine Rückmeldung und manuellen Ansichtswechsel. Für `Zeige Partitur` muss das vorhandene Vier-Takte-Notationsskript separat als MIDI-ReaScript registriert sein; dieses Update installiert es nicht neu.

Ein gebündelter Test in einer gesicherten Projektkopie: zwei bis drei Instrumentalstimmen öffnen, Piano-Roll/Notenansicht wechseln, denselben markierten Ausschnitt analysieren und per bestätigter Pitch-/Velocity-Änderung bearbeiten. Referenzstimmen, unmarkierte Noten, CC und Timing vergleichen; Undo prüfen. Anschließend Analyse → Variante und neue Instrumentalstimme testen. Nach zwei gezielten Fehlversuchen Diagnose statt weiterer Paketserie.

## Wiederherstellung von 1.1.7

Unveränderter vorheriger `main`-Commit: `9dfebaeb2b2cda7fc562aee693162b9aada7801b`, zusätzlich als Branch `recovery/v1.1.7` gesichert. [Originalskript 1.1.7](https://github.com/wibem1/Composition-Studio/blob/9dfebaeb2b2cda7fc562aee693162b9aada7801b/Composition%20Studio.lua).

Der reguläre Updater schreibt vor dem Austausch die bisherige Datei als `Composition Studio.lua.backup`. Bei unmittelbarem Startfehler stellt er sie automatisch wieder her. Für manuelle Rückkehr Studio schließen und das bestehende `Composition Studio Repair.lua` ausführen, solange diese Sicherung noch 1.1.7 enthält. Alternativ die registrierte Studio-Datei durch die oben verlinkten unveränderten 1.1.7-Quellbytes ersetzen. Kein Löschen von Einstellungen, Ergebnissen oder Projektdaten. Der normale Updater führt absichtlich kein Downgrade durch.
