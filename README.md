# Composition Studio

Composition Studio ist die KI-Kompositions- und Bearbeitungsebene direkt in REAPER.

Aktueller Stand: **v1.1.1 · 19.10.2026 · TEST CANDIDATE**.

Denkaufwand im Hauptfenster: **Kurz / Mittel / Hoch / Automatisch**, mit **Mittel** als Voreinstellung. Die Auswahl wird dauerhaft gespeichert und gilt für die KI-Aufrufe des Auftrags einschließlich Konzeption und Komposition. Während eines laufenden Auftrags ist sie gesperrt. Automatisch sendet keine Denksteuerung und verwendet die Modellvorgabe.

OpenAI erhält `reasoning.effort`, Anthropic `output_config.effort`, Gemini 3 `generationConfig.thinkingConfig.thinkingLevel` (jeweils low/medium/high). Gemini 2.5 Pro ist als Altmodell mit eingeschränktem Zugang gekennzeichnet (Google gewährt Zugang nur bisherigen Nutzern). Es verwendet stattdessen die appseitig zugeordneten Denkbudgets 2048/8192/24576 Tokens; das Hauptfenster weist darauf hin. Diagnose und Kommunikationsprotokoll enthalten die Auswahl und die tatsächlich gesendeten Parameter. Diese dokumentieren die Anforderung, nicht eine garantierte Qualität oder Tokenzahl.

Die langfristige Zielsetzung des Notationsmoduls ist in [NOTATION-MODULE.md](NOTATION-MODULE.md) dokumentiert.

Die bestehende Updatefunktion bleibt der normale Installationsweg: **Studio-Menü → Update**.

## Gemeinsamer Workflow-Kern 1.0.0

Analyse → Überarbeitung, gespeicherte Vorschläge mit Originalprüfung, Ergebnisverlauf, optionale Übergangstakte und dynamische Modellkataloge. Installation und Grenzen: [INSTALLATION-1.1.0.md](INSTALLATION-1.1.0.md). Über Studio-Menü → Update verfügbar; praktischer Test steht aus.

### Korrektur 1.1.1

Behebt einen Startabbruch nach dem Update auf 1.1.0: Der Verlauf verwendet jetzt eine dauerhaft im Projekt gespeicherte Kennung über native REAPER-Funktionen. Ein nicht lesbarer Verlauf lässt Oberfläche und Updatefunktion erreichbar. Künftige Updates stellen bei einem unmittelbaren Startfehler die vorherige Skriptdatei wieder her. Die Schutzfunktion gilt für Updates, die von 1.1.1 aus gestartet werden.

Falls 1.1.0 nicht mehr startet: [Composition Studio Repair.lua](Composition%20Studio%20Repair.lua) einmal über REAPERs Aktionsliste laden und ausführen. Es stellt die beim Update gespeicherte vorherige Fassung wieder her. Danach Studio öffnen und über das Menü auf 1.1.1 aktualisieren. Projekte und Ergebnisdateien werden dabei nicht verändert.
