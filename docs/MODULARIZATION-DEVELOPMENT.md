# Modularer Entwicklungsstand und Ein-Datei-Auslieferung

Die bearbeitbare Quelle des gesamten bestehenden Studios liegt jetzt unter
`src/`. `src/manifest.json` registriert jede Lua-Datei genau einmal und legt
Reihenfolge, Schnittstellen und Abhängigkeiten fest. Die [Modulkarte](MODULARIZATION-SOURCE-MAP.md)
zeigt die tatsächlichen Grenzen; der [Audit](MODULARIZATION-AUDIT-2026-11-05.md)
bleibt die historische Bestandsaufnahme vor dem Refactoring.

## Build

Aus dem Repository-Root:

```sh
python tools/build_studio.py
python tools/build_studio.py --check
python tools/test_all.py
```

`build_studio.py` benötigt ausschließlich Python-Standardbibliotheken. Es baut
`Composition Studio.lua`, `Composition-Studio-Update.lua` und
`Composition-Studio-Offline-Install.lua` gemeinsam im Speicher. `--check` prüft
alle Bytes ohne Dateien zu verändern. Nicht registrierte Quellen, doppelte IDs,
ungültige Pfade, nicht deklarierte Importbindungen und abweichende Export-/
Factoryverträge werden zurückgewiesen. Die älteren Einzelgenerator-Kommandos
bleiben kompatibel; für Änderungen an `src/` stets den Gesamtbuild verwenden.
Die ausgelieferten Lua-Dateien werden nicht von Hand bearbeitet.

Benötigte Testabhängigkeiten: Python 3.12, `lupa==2.8` und
`imgui-bundle==1.93.0` entsprechend CI. Tests laufen gegen den gebauten
Produktionscode und die eigenständig geladenen portablen Quellen. Die lokalen
HTTP-Fixtures brauchen Loopback-Sockets; nur deren Loopback-Ziele werden vom
externen Proxy ausgenommen. Es werden keine echten API-Schlüssel oder bezahlten
Provideraufrufe benötigt. Historische Git-Objekte bleiben für Differential- und
Installerprüfungen erforderlich; ein flacher Clone reicht nicht für alle Tests.

## Schnittstellen und Zustandsgrenzen

- `core/version`: `parts(v)`, `is_newer(remote,localv)`; unveränderte Updateordnung.
- `core/text`: Trim/Titel-Helfer; `ai/response`: bestehende Antwortstring-Decoder.
- `music/cs_notes`, `music/programs`: vorhandene Notendaten und Programmauswahl.
- `music/continuation_request`: vorhandene Text-/Takt-/Übergangserkennung;
  `music/continuation_prompt(compact_music_excerpt)`: Prompt mit explizitem Kontextport.
- `music/json_direct_prompt` und `music/json_framework_prompts`: unveränderte
  direkte bzw. zweistufige Kompositionsprompts; der persistente Modus und der
  Jobstart liegen getrennt unter `workflow/`.
- `ai/reasoning(REASONING_LABELS)`: native Providerparameter ohne Hostpersistenz.
- `music/cs_plan(trim,parse_notes,program_for_name)`: reine Operationsplanung.
  `plan_composition(text,items,tracks,force_single_piano)` liefert
  `jobs,musical_map,controls,src,targets` oder `nil,error`. Die Jobs sind die
  bisherigen `new/revised/target/track`-Operationen, keine neue Musikrepräsentation.
  Der REAPER-Commit erhält nur validierte Pläne; er behält native Erzeugung,
  Tempo-/Taktkartenoperationen, CC und Undo/Rollback. Die übergeordneten
  Freigabe-/Sourceguard-/Scopeprüfungen bleiben vorgeschaltet.
- `music/json_codec`: `decode_engine_json(text)`; native UTF-8-Bibliothek ausdrücklich
  gegen lokale Namensverschattung abgesichert, keine musikalischen Korrekturen.
- `music/json_score(decode_engine_json)`: Lua-Adapter des bestehenden JSON-Schemas
  nach CS/CSMETA/CSCTRL, einschließlich Tempo, Sustain und Einzelspur-CC.
- `music/prompts(music_context,parse_notes,trim)`: vorhandene Prompts und technische
  Chunkprüfung; Kontext ist ein injizierter Port, kein direkter REAPER-Zugriff.
- `editing/selected_notes_prompt(editor_reference_excerpt)`: festes CSNOTE-Protokoll
  mit getrenntem read-only Referenzkontext. `music/lilypond_prompt`: bisheriger
  LilyPond-Auftrag.
- `shared/workflow`: eingebetteter zentraler Kern `Composition-Workflow-1` v1.0.0.
  Herkunft: Composition-Engine `8b062ea6deea9e7421c62b0dd415cf652b47828a`,
  `workflow-core/runtime.lua` und `spec.json`; der vorhandene Interpreter und die
  Spezifikation werden nicht unabhängig weiterentwickelt. Keine neue Engine.

Diese Module sind separat ladbare Lua-Dateien mit Rückgabetabellen bzw. expliziten
Factoryparametern. Im REAPER-Build entfernt der Compiler ausschließlich die
Export-/Factoryhülle und bettet den Funktionskörper unverändert an seiner
bisherigen Position ein. Das ist eine bewusste Buildzeit-Verknüpfung, kein neuer
Laufzeitloader. Originalschutz, Freigabe, native Bindings und Undo bleiben im
Host-/Workflowadapter. Dessen veränderlicher Sitzungszustand ist noch gemeinsam:
Die Quellenaufteilung allein macht ihn nicht zu einem universellen Host-Framework.

## Kompatibilität und Abgrenzung

Studio bleibt genau eine installierbare Lua-Datei. Keine zusätzliche
Laufzeitinstallation, kein `require`, keine Suchpfadänderung und kein neuer
Netzwerkdienst. Update-/Repair-/Backup-/Offlinepfade und persistente Schlüssel
bleiben erhalten. Produktversion bleibt 1.1.10, `main` und Notations-PR #12 werden
nicht verändert. Der Default-Kompositionsablauf, Prompts und musikalische
Algorithmen werden beim Refactoring nicht an einen anderen Enginevertrag
angepasst.

Die erste vollständige Quellaufteilung erzeugte exakt die Bytes des separat
geprüften M2-Stands `b35301c`. Danach wurde ausschließlich die bestehende
CS-Vorprüfung mechanisch in `plan_composition` verschoben. Ein Test setzt diese
Extraktion strukturell zurück und verlangt wieder vollständige Gleichheit mit
M2: keine anderen Runtimeänderungen sind erlaubt. Zusätzlich vergleichen 60
Fälle die alte und neue Planung samt Host-Aufrufreihenfolge und Rollback.
Die originalen Vergleichs-/Auswahl-/Quellschutz-/Rollback-/Installationsfälle
und die portablen Schnittstellen werden weiterhin ausgeführt.
Der bekannte Transport-Fixturefehler wurde mit expliziten Testschlüsseln und
eigenem Missing-Key-Fall korrigiert. Der Unicodefehler wurde separat behoben.

Neue Funktionen wie Motivgedächtnis, vollwertiges Werkmodell, Song Construction,
neue Engineabläufe oder Notationsintegration gehören nicht zu dieser
verhaltenserhaltenden Umstrukturierung. Native Windows-/macOS-/REAPER-Abnahme,
Hörtests und die Windows-LilyPond-Integration sind in der Linux-Cloud nicht belegt.
Ein bestandener Offlinebuild ist keine Veröffentlichung oder vollständige
Produktfreigabe.

## Abschluss dieses Refactorings

50 registrierte Quellbereiche, davon 17 als eigenständig ladbare portable Module
bzw. Factories. Vollständige Offline-Regression: 14 Python-Suiten und drei
Lua-Dateien, einschließlich 60 Plan-/Commit-Differentialfällen. Die bekannte
Compilerprüfung bleibt ohne `LILYPOND_EXE` ausdrücklich ausgelassen; REAPER ist
in dieser Cloud nicht installiert. Die CI führt den gesamten Runner aus, statt
nur einige UI-/Installersuiten. Source-/Artefaktgleichheit und Abnahmegrenzen
stehen auch im aktuellen `PROJECT_STATE.md`.

Die Quellmodularisierung und die isolierte Plan-/Commit-Grenze des Bestands sind
implementiert. Eine vollständige Auflösung jedes gemeinsam veränderlichen
Hostzustands ist damit nicht behauptet: `workflow_adapter`, `job`, `busy`,
Provider-/Modellwahl und UI-Sitzung bleiben über die im Manifest deklarierten
Bindungen verbunden. Eine weitere Laufzeitentkopplung oder eine Engineumstellung
braucht eigene Verhaltensverträge und native Prüfung. Die langfristige Vision
mit neuen musikalischen Fähigkeiten bleibt davon getrennt.
