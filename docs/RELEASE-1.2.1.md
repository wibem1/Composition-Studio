# Composition Studio 1.2.1 – Testfreigabe

Patch zur Veröffentlichung über [PR #15](https://github.com/wibem1/Composition-Studio/pull/15) vorbereitet.

- KI-Aufrufe dürfen bis zu 600 statt 180 Sekunden laufen; der Lua-Watchdog wartet 620 Sekunden. Update und Modellkatalog behalten ihre kurzen Limits.
- Zeitüberschreitungen erhalten eine klare Meldung. Keine automatische Wiederholung oder Übernahme unvollständiger Ergebnisse.
- Fehlgeschlagene Aufrufe zeigen keine Token-/Preiswerte des vorherigen Aufrufs mehr. Tatsächlich gemeldeter Verbrauch bleibt erhalten; fehlender Verbrauch wird als unbekannt behandelt.
- Musikalische Prompts, Denkaufwand und MIDI-Verhalten unverändert. Funktionen aus 1.2.0 bleiben verfügbar.

## Prüfgrundlage

Fix mit vollständigem Offline-Runner (16 Python-Suiten, drei Lua-Dateien) und fünf CI-Jobs geprüft. Release-Kandidat lokal ebenfalls vollständig bestanden, einschließlich exakter Offline-Installation aus 1.2.0 mit Backup. Unix-curl gegen echten lokalen HTTP-Server getestet; Windows-PowerShell-Generierung statisch geprüft. Keine native Windows-/REAPER-/Liveprovider-Abnahme und keine Garantie einer Anbieterantwort innerhalb von zehn Minuten.

[Fehlernachweis und technische Grenzen](AI-TIMEOUT-DIAGNOSIS-2026-11-05.md).

Installation nach Veröffentlichung: **Studio-Menü → Update**, danach Studio neu starten. Der Updater sichert die vorherige Skriptdatei. Erste Gegenprobe an einer Projektkopie durchführen.
