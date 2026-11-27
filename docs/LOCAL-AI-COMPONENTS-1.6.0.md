# Lokale KI-Komponenten und MIDI-DDSP – 1.6-Teststand · 1.6-test3

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

- GitHub-Quellcodeprüfung: Worker-CLI, Check-Ausgabe, JSON-Notenformat, unterstützte Instrument-IDs und WAV-Ausgabe.
- Am Code-Commit `640f6102646f3da4a9f5609e59405ca18e5e9e1b` bestanden: [Local AI component regression #23](https://github.com/wibem1/Composition-Studio/actions/runs/45982948803), [Modular Studio regression #48](https://github.com/wibem1/Composition-Studio/actions/runs/45982948881), [Notation selection #114](https://github.com/wibem1/Composition-Studio/actions/runs/45982948950), [Score workspace bridge #84](https://github.com/wibem1/Composition-Studio/actions/runs/45982948943). Der lokale KI-Lauf beinhaltet einen Lua-Mocktest für den Dateidialog und ein gültiges JSON-Diagnoseergebnis.
- OFFEN: Windows-/REAPER-Praxistest mit den vorhandenen Pfaden, realer DDSP-Render, Audio-/Timingkontrolle, Abbruch und WAV-Import. Keine erfolgreiche reale Audiogenerierung behauptet.
- OFFEN: eigene isolierte Komponenteninstallationen samt geprüftem Katalog, Lizenz-/Versionspins, Speicherbedarf, Updates, Entfernung und Rückfall. Der aktuelle Kandidat wählt vorhandene Python-/Worker-Dateien aus und nutzt sie; er installiert oder verändert keine fremde Umgebung.
- Diese Testfassung ist keine 1.6.0-Freigabe. Die Diagnose enthält Pfade und wird nur auf ausdrücklichen Nutzerklick gespeichert.
