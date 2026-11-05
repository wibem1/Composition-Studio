# Composition Studio 1.3.0 – Testfreigabe

Auf ausdrücklichen Nutzerauftrag zur Veröffentlichung über [PR #16](https://github.com/wibem1/Composition-Studio/pull/16) vorbereitet.

## Neu: ganzer Track mit Zwischenständen

Vollständige MIDI-Items auswählen und `Ganzer Track: Erstelle eine Techno-Version mit Synthie, Bass und Drums.` eingeben. Alternativ Menü **Ganzer Track: Auftrag vorbereiten**. Die Vorbereitung erfolgt lokal ohne KI-Kosten und zeigt Umfang, mögliche Aufrufe und Tarifbeispiel. Anschließend etwa `Track-Aufbau starten: 2 USD` als zusätzliches geschätztes Ausgabenbudget freigeben.

Ein gemeinsamer Werkplan und begrenzte Arbeitsfenster erzeugen die gesamte Fassung. Gültige Abschnitte werden lokal gespeichert; bei späterem Fehler bleiben sie erhalten. `Track-Aufbau fortsetzen` zeigt den Stand, eine neue Kostenfreigabe erlaubt weitere Aufrufe. Keine automatische Wiederholung. Nur das vollständige geprüfte Ergebnis wird als Vorschlag angeboten und mit **Änderungen anwenden** auf neuen Spuren übernommen. Original und Tempo-/Taktkarte bleiben erhalten.

Neue Track-Aufrufe: 120 Sekunden HTTP-Limit, 140 Sekunden Watchdog, maximal 2048 Ausgabetokens für den Plan und 8192 pro Fenster. Budget wird vor Folgeaufrufen geprüft; unbekannter Verbrauch stoppt den Ablauf. **Keine garantierte Rechnungsobergrenze, Kosten-/Zeitersparnis oder musikalische Qualität.** Ein bereits gestarteter Anbieteraufruf kann trotz Anhalten weiter Kosten verursachen. [Bedienung, Datenverträge und technische Grenzen](WHOLE-TRACK-WORKFLOW.md).

## Prüfgrundlage und Installation

Implementierungsstand: 17 Python-Suiten und drei Lua-Dateien sowie fünf CI-Jobs bestanden. Release-Kandidat lokal ebenfalls mit allen 17 Python-Suiten und drei Lua-Dateien bestanden, einschließlich exakter Offline-Installation aus 1.2.1 mit bytegenauem Backup. Getestet mit simulierten Anbieter-/REAPER-Schnittstellen und realem lokalem HTTP-Server. Keine kostenpflichtigen Anbieteraufrufe, keine native Windows-/REAPER-/Hörabnahme. Daher Testfreigabe.

Nach Veröffentlichung **Studio-Menü → Update**, danach Studio neu starten. Erste Gegenprobe an Projektkopie. Bisherige Einzelaufträge bleiben verfügbar; der neue Ablauf wird ausdrücklich gewählt. Composition-Engine und Notations-PR #12 unverändert.
