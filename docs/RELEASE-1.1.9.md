# Composition Studio 1.1.9 – Testfreigabe

Stand: 04.11.2026. Nutzerfreigabe zur Veröffentlichung über den bestehenden Updater; Merge und abschließender Byteabgleich werden in `PROJECT_STATE.md` dokumentiert.

## Fehler und Korrektur

In REAPER 7.83 wurde der Fehler mit der installierten Version 1.1.8 direkt
beobachtet: 86 OpenAI-Modelle füllten das Popup über die Bildschirmhöhe hinaus.
Anthropic und Google folgten erst am Ende dieser Liste. Das Öffnen startete
zusätzlich jedes Mal eine Katalogabfrage.

Die drei Anbieter stehen jetzt fest oberhalb der separat scrollbaren Modellliste.
Standard ist die kurze, bereits im Projekt definierte Hauptmodellauswahl. Ein
abweichendes gespeichertes Modell wird zusätzlich erhalten. Die Anzahl ist kein
technisches Dreierlimit. Weitere Katalogmodelle sind ausschließlich über
„Alle verfügbaren Modelle“ mit Suche erreichbar. Öffnen und Anbieter ansehen
lösen weder Netzwerk noch Änderung der gespeicherten Auswahl aus. Aktualisierung
fragt ausdrücklich den gerade angesehenen Anbieter mit dessen vorhandenem
Schlüssel ab; ein Modellwechsel während eines Auftrags ist gesperrt.

Keine Änderungen an Modellkennungen, Preisen, MIDI, Projektdateien, API-Schlüsseln,
Verlauf oder gespeicherten Modellkatalogen. Die Vorauswahl stammt aus dem
bestehenden Projekt; ihre aktuelle Freischaltung bei Anbietern wurde nicht mit
Live-API-Aufrufen bestätigt.

## Nachweise

- Lua 5.4: gesamtes Skript syntaktisch gültig.
- `tools/test_model_picker.py`: sechs echte Dear-ImGui-Interaktionsfälle mit
  86 Modellen, 280/360/480 Pixeln Breite und Schrift 14/26. Anbieter sichtbar,
  kurze Vorauswahl, Suchauswahl, identische Modellnamen, gespeicherte Sonderauswahl,
  gezielte Persistenz, Auftragssperre und kein automatisches Netzwerk. Zusätzliche
  Produktionsfunktionsprüfung für Katalogabfrage des angesehenen Anbieters und
  fehlenden Schlüssel bestanden.
- `tools/test_layout.py`: 64 Layoutfälle bestanden.
- Beide Lua-Produktionsfunktionstests für Notenauswahl und Editor-Brücke bestanden.
- `tools/test_lilypond_import.py`: 34 Prüfungen bestanden, einschließlich
  Start/erstem UI-Frame mit simulierten REAPER-APIs, Updatevalidierung,
  Sicherung/Rollback und echtem lokalem LilyPond-Compiler.
- `tools/test_update_helper.py`: Installation, Ersatzadresse, Abbruch,
  Fehler, Rollback und Sicherung unter Windows-/Unix-Transportmocks bestanden.
- `tools/test_offline_installer.py`: Installation von 1.1.8 sowie fünf älteren
  Quellständen mit bytegenauer Sicherung und sieben Fehler-/Nichtupdatefällen
  bestanden. Der Generator schreibt UTF-8/LF unabhängig von Windows-Defaults.
  Windows-lupa verwendet für Dateipfade die schmale CRT; deshalb dort ASCII mit
  Leerzeichen/Apostroph statt Unicode-Dateiname. Native REAPER-Unicodeinstallation
  ist damit nicht nachgewiesen.
- Echter REAPER-7.83-Oberflächentest: unveränderte Produktionsfunktion
  `draw_model_picker` in einem isolierten Testfenster, 86 OpenAI-Fixtures.
  Anthropic und Google sofort sichtbar; Auswahl von Claude Sonnet 5 und Gemini
  3.8 Flash zeigte jeweils korrekten Anbieter und Modellkennung. Auswahl war nur
  im Testspeicher; kein Schlüssel, keine Benutzereinstellung und kein MIDI wurde
  geschrieben. Testfenster anschließend geschlossen. Dies ist kein vollständiger
  App-/Neustart-/Live-KI-Test.

## Grenzen und Bereitstellung

Keine vollständige erneute Gesamtabnahme. Die vorhandenen JSON-/Workflow-/Kosten-
Tests ließen sich unverändert unter Windows-lupa teilweise nicht ausführen
(CRLF-Quelltextassertion, Unix-`mkdir`-Mock bzw. plattformabhängiger Prozessstart).
Diese Resultate werden nicht als bestanden gewertet; die betroffenen
Produktionspfade wurden durch diese Korrektur nicht verändert. Kein Live-KI-Test.

Header und Laufzeitversion sind 1.1.9; der bestehende Offline-Installer enthält
dieselben Quellbytes. Der reguläre Updater bleibt unverändert und lädt weiterhin
aus `main`. Solange der vorbereitete PR nicht gemergt ist, liefert er 1.1.8.
Keine Änderung der installierten Benutzerfassung durch diese Vorbereitung.

Ausgangsstand: `e9d857267be47dfab9bb3bb78aa154e1614508ca` (Version 1.1.8). Der Updater sichert die vorherige
Datei als `.backup`; vorhandene Repair-Funktion und Wiederherstellung bleiben
erhalten. Alle drei PR-Prüfungen sind erfolgreich; die Veröffentlichung über den bestehenden
Updateweg wurde vom Nutzer beauftragt. Nach Merge `main`-Quellbytes abgleichen.
