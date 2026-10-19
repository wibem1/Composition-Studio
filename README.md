# Composition Studio

Composition Studio ist die KI-Kompositions- und Bearbeitungsebene direkt in REAPER.

Aktueller Stand: **v1.1.4 · 19.10.2026 · TEST CANDIDATE**.

Denkaufwand im Hauptfenster: **Kurz / Mittel / Hoch / Automatisch**, mit **Mittel** als Voreinstellung. Die Auswahl wird dauerhaft gespeichert und gilt für die KI-Aufrufe des Auftrags einschließlich Konzeption und Komposition. Während eines laufenden Auftrags ist sie gesperrt. Automatisch sendet keine Denksteuerung und verwendet die Modellvorgabe.

OpenAI erhält `reasoning.effort`, Anthropic `output_config.effort`, Gemini 3 `generationConfig.thinkingConfig.thinkingLevel` (jeweils low/medium/high). Gemini 2.5 Pro ist als Altmodell mit eingeschränktem Zugang gekennzeichnet (Google gewährt Zugang nur bisherigen Nutzern). Es verwendet stattdessen die appseitig zugeordneten Denkbudgets 2048/8192/24576 Tokens; das Hauptfenster weist darauf hin. Diagnose und Kommunikationsprotokoll enthalten die Auswahl und die tatsächlich gesendeten Parameter. Diese dokumentieren die Anforderung, nicht eine garantierte Qualität oder Tokenzahl.

Die langfristige Zielsetzung des Notationsmoduls ist in [NOTATION-MODULE.md](NOTATION-MODULE.md) dokumentiert.

Die bestehende Updatefunktion bleibt der normale Installationsweg: **Studio-Menü → Update**.

## Gemeinsamer Workflow-Kern 1.0.0

Analyse → Überarbeitung, gespeicherte Vorschläge mit Originalprüfung, Ergebnisverlauf, optionale Übergangstakte und dynamische Modellkataloge. Installation und Grenzen: [INSTALLATION-1.1.0.md](INSTALLATION-1.1.0.md). Über Studio-Menü → Update verfügbar; praktischer Test steht aus.

### Korrektur 1.1.1

Behebt einen Startabbruch nach dem Update auf 1.1.0: Der Verlauf verwendet jetzt eine dauerhaft im Projekt gespeicherte Kennung über native REAPER-Funktionen. Ein nicht lesbarer Verlauf lässt Oberfläche und Updatefunktion erreichbar. Künftige Updates stellen bei einem unmittelbaren Startfehler die vorherige Skriptdatei wieder her. Die Schutzfunktion gilt für Updates, die von 1.1.1 aus gestartet werden.

Falls 1.1.0 nicht mehr startet: [Composition Studio Repair.lua](Composition%20Studio%20Repair.lua) einmal über REAPERs Aktionsliste laden und ausführen. Es stellt die beim Update gespeicherte vorherige Fassung wieder her. Danach Studio öffnen und über das Menü auf 1.1.1 aktualisieren. Projekte und Ergebnisdateien werden dabei nicht verändert.

### Layoutkorrektur 1.1.2

Kompakter Aufbau mit Modell- und Denkauswahl über dem Chat. Eingabefeld und die vier unteren Schaltflächen behalten ihren Platz, auch bei großer Schrift. Lange Modellnamen werden passend gekürzt; Meldungen, Kosten, gespeicherte Ergebnisse und die Aktionen Anwenden/Überarbeiten liegen im scrollbaren Gesprächsbereich. Die Übergangsoption steht im Studio-Menü.

Prüfung: tools/test_layout.py führt den ausgelieferten Lua-Oberflächencode gegen Dear ImGui aus (48 Kombinationen aus Fenstergröße, Schriftgröße und Ergebniszustand). REAPER-spezifische Aufrufe werden ersetzt; dies ist kein Test in einem laufenden REAPER.

### REAPER: Textsteuerung 1.1.3

REAPER behält seine eigenständige, schmale Oberfläche. Musikalische Funktionen werden im vorhandenen Auftragsfeld formuliert. Keine zusätzlichen Funktionsseiten, kein größeres Fenster, keine Übergangs-Menüpunkte und kein gesonderter Überarbeiten-Button. Modell und Denkaufwand bleiben direkt auswählbar; Einstellungen, Export, Diagnose und Update stehen im Studio-Menü. Der gemeinsame Workflow-Kern bleibt unverändert.

Beispiele:

- „Verlängere um 16 Takte.“ Der bisherige Schluss bleibt erhalten.
- „Verlängere um 16 Takte und gestalte die letzten zwei Takte neu.“ Zwei Übergangstakte plus 16 neue Takte.
- „Ergänze eine weitere Cellostimme.“ Die ausgewählten Items oder Spuren liefern den Kontext.
- „Analysiere die Komposition.“
- „Überarbeite anhand der letzten Analyse und behalte die schlichte Begleitung.“ Verwendet die zuletzt geladene oder gespeicherte Analyse; die Originalprüfung bleibt wirksam.
- „Interpretiere die Auswahl für SWAM.“

Andere freie Formulierungen werden vom KI-Controller eingeordnet. Unklare Übergangslängen werden nachgefragt. Die technischen Grenzen für Übergänge (2/3/4 Takte und keine überspannten Noten) bleiben bestehen. Erzeugte Musik wird als Vorschlag gesichert und erst über „Änderungen anwenden“ übernommen. Die normale Updatefunktion installiert 1.1.3.

Geprüft: echte Lua-Parser und Auftrags-/Antwortpfade ohne Anbieteraufruf, Analyse nach erneutem Laden, Vorschlagsablauf, 48 Größen-/Schriftkombinationen gegen Dear ImGui. Kein praktischer Test in einem laufenden REAPER.

### Update-Rückmeldung 1.1.4

Der Updateklick wird bei einem laufenden Auftrag nicht mehr still ignoriert. Während des Downloads erscheint eine kurze Meldung außerhalb des scrollbaren Chats. Fehler und „Bereits aktuell“ werden ausdrücklich in einem Dialog gemeldet. Der Download verwendet zunächst die direkte Skriptadresse und bei Fehlern die GitHub-API; beide Wege haben begrenzte Wartezeiten.

Wenn das vorhandene Studio-Menü nicht reagiert: Studio schließen, [Composition-Studio-Update.lua](Composition-Studio-Update.lua) herunterladen, in REAPER über Aktionen → Aktionsliste anzeigen → ReaScript: Laden laden und einmal ausführen. Danach Composition Studio erneut öffnen. Der Updater benötigt kein ReaImGui, verwendet die bereits registrierte Studio-Datei, prüft Download und Lua-Syntax und sichert die vorherige Fassung als .backup. Er startet keinen KI-Aufruf und verändert keine Projektdateien.

Der eigenständige Updater wird mit tools/build_update_helper.py aus dem aktuellen Transport- und Installationscode erzeugt. Geprüft sind Installation, Ersatzadresse, Fehler, Abbruch, fehlender Zielpfad und Rückkehr bei fehlgeschlagenem Dateiaustausch, mit simulierten Windows-/Unix-Prozessen und echten temporären Dateien. Layoutprüfung: 64 Varianten einschließlich laufendem Update.
