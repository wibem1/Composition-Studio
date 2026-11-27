# Lokale KI-Komponenten und MIDI-DDSP – 1.6-Teststand 1.6-test2

Stand: 27.11.2026 · Entwicklungsfassung, keine Freigabe.

## Umsetzung in diesem Testkandidaten

- Composition Studio bietet ein separates Fenster „KI-Komponenten“.
- Python-Interpreter und `midi_ddsp_worker.py` werden lokal ausgewählt und in REAPER-ExtState gespeichert.
- „Umgebung prüfen“ ruft den Worker mit `--check` direkt auf. Der Workerstatus und das Vorhandensein der MIDI-DDSP-Gewichte werden getrennt ausgewertet.
- MIDI-DDSP rendert die Noten eines ausgewählten MIDI-Items/aktiven MIDI-Editors ohne AI-Music-Studio-Server. Instrumente werden aus der vom Worker unterstützten Liste gewählt.
- WAV wird erst nach ausdrücklicher Bestätigung auf einer neuen REAPER-Spur übernommen. Die MIDI-Originalspur bleibt unangetastet.
- Rendern ist gesperrt, wenn der Vorabtest keine Modellgewichte meldet. Es gibt keine automatischen Downloads und keine Änderung an AI Music Studio.

## Einrichtung

1. In Composition Studio **… → KI-Komponenten…** öffnen.
2. Die passende `python.exe` der bestehenden MIDI-DDSP-Umgebung und die Datei `midi_ddsp_worker.py` auswählen.
3. **Umgebung prüfen** ausführen. Ein erfolgreicher Status zeigt Paketimport und separat die installierten Modellgewichte.
4. MIDI-Item auswählen oder im REAPER-MIDI-Editor öffnen; Instrument auswählen und **Ausgewähltes MIDI rendern** starten.
5. Die erzeugte WAV-Datei prüfen und erst dann **WAV auf neuer REAPER-Spur übernehmen** verwenden.

Der Worker-Aufruf folgt der bestehenden CLI von AI Music Studio (`midi_ddsp_worker.py --check` bzw. mit JSON-Anfrage). Composition Studio übernimmt keinen Worker-Code und startet weder dessen Anwendung noch Backend. Die Referenzimplementierung steht unter [pierrecinema/ai-music-studio](https://github.com/pierrecinema/ai-music-studio); dessen Repository-Lizenz und die einzelnen Modell-/Gewichtslizenzen sind getrennt zu beachten. Dieses Paket verteilt keine fremden Dateien.

## Prüfstatus und Grenzen

- GitHub-Quellcodeprüfung: Worker-CLI, Check-Ausgabe (`ok`, `weights`), JSON-Notenformat, unterstützte Instrument-IDs und WAV-Ausgabe geprüft.
- Automatisierte Modul-/Artefakt-, Versions-, vollständige Offline-Regression und Lua-Prüfungen: bestanden am Code-Commit `170c87ce8563373e51b1d2e8121a58cb04d29c32`; siehe [Local AI component regression](https://github.com/wibem1/Composition-Studio/actions/runs/45979473272) und [vollständiger Regressionstest](https://github.com/wibem1/Composition-Studio/actions/runs/45979473275).
- Noch offen: vollständige isolierte Installations-/Update-/Entfernungsverwaltung eigener Komponenten, geprüfter Katalog, Speicherbedarf und Lizenzpins. Echter Windows-REAPER-Importtest mit der installierten Umgebung, Audio-/Timing-Gegenprobe und Nutzerabnahme. Diese Entwicklungsversion ist deshalb keine funktionsbestätigte 1.6.0-Freigabe.
- Die vollständige Verwaltung (Installation, Aktualisierung und Entfernung eigener isolierter Komponenten, Speicherbedarf und Katalog-/Lizenzpins) bleibt offen. Diese erste vertikale Integration erkennt und nutzt MIDI-DDSP, installiert oder verändert aber keine fremde Umgebung.
