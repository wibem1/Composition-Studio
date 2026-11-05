# Composition Studio 1.2.1 – Testfreigabe

Veröffentlicht über [PR #15](https://github.com/wibem1/Composition-Studio/pull/15), Merge `2754871b5e32909cdc0baf263103ece9faf75b0c`. Tatsächlicher Update-Download bytegenau mit dem geprüften Kandidaten abgeglichen.

- KI-Aufrufe dürfen bis zu 600 statt 180 Sekunden laufen; der Lua-Watchdog wartet 620 Sekunden. Update und Modellkatalog behalten ihre kurzen Limits.
- Zeitüberschreitungen erhalten eine klare Meldung. Keine automatische Wiederholung oder Übernahme unvollständiger Ergebnisse.
- Fehlgeschlagene Aufrufe zeigen keine Token-/Preiswerte des vorherigen Aufrufs mehr. Tatsächlich gemeldeter Verbrauch bleibt erhalten; fehlender Verbrauch wird als unbekannt behandelt.
- Musikalische Prompts, Denkaufwand und MIDI-Verhalten unverändert. Funktionen aus 1.2.0 bleiben verfügbar.

## Prüfgrundlage

Alle fünf CI-Jobs am Release-Kandidaten `97bc5e8` erfolgreich, einschließlich [Gesamtbuild und vollständigem Runner](https://github.com/wibem1/Composition-Studio/actions/runs/42057974341).

Fix mit vollständigem Offline-Runner (16 Python-Suiten, drei Lua-Dateien) und fünf CI-Jobs geprüft. Release-Kandidat lokal ebenfalls vollständig bestanden, einschließlich exakter Offline-Installation aus 1.2.0 mit Backup. Unix-curl gegen echten lokalen HTTP-Server getestet; Windows-PowerShell-Generierung statisch geprüft. Keine native Windows-/REAPER-/Liveprovider-Abnahme und keine Garantie einer Anbieterantwort innerhalb von zehn Minuten.

[Fehlernachweis und technische Grenzen](AI-TIMEOUT-DIAGNOSIS-2026-11-05.md).

Installation: **Studio-Menü → Update**, danach Studio neu starten. Der Updater sichert die vorherige Skriptdatei. Erste Gegenprobe an einer Projektkopie durchführen.
