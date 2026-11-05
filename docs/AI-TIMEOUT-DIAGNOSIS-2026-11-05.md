# Diagnose und Korrektur: KI-Aufruf nach drei Minuten abgebrochen

## Gesicherter Ablauf

Die bereitgestellte Diagnose der veröffentlichten 1.2.0 enthält einen freien
Auftrag zur Techno-Überarbeitung von zwei vorhandenen Spuren. Der Controller
antwortet nach neun Sekunden korrekt mit `NEED_MUSIC`. Der anschließende
Kompositionsaufruf läuft mit Gemini 3.8 Flash und Denkaufwand high und endet
nach rund 182 Sekunden in einer Windows-`TaskCanceledException` bei
`HttpClient.SendAsync(...).GetAwaiter().GetResult()`.

Der Code setzt dafür 180 Sekunden HTTP-Timeout und 200 Sekunden Lua-Watchdog.
Zeitverlauf und Ausnahmetyp passen zum lokalen Timeout. Es ist keine erfolgreiche
HTTP-Kompositionsantwort dokumentiert; der MIDI-Importer wird nicht erreicht.
Eine fehlende Anbieterberechtigung ist damit nicht belegt: Der unmittelbar
vorherige Controlleraufruf war erfolgreich. Die Ursache der langsamen bzw.
ausbleibenden Kompositionsantwort bei Anbieter/Netz ist nicht weiter bewiesen.
Die Originaldatei mit Quellnoten und lokalen Pfaden wird nicht ins Repo kopiert.

## Korrektur

- KI-Anfragen haben 600 Sekunden HTTP-Timeout und einen passenden 620-Sekunden-
  Watchdog; keine endlose Wartezeit. Update-/Modellkatalog-Abfragen behalten
  ihre eigenen kurzen Limits.
- Windows prüft die Exception-/InnerException-Kette auf Cancellation/Timeout und
  liefert einen eindeutigen TIMEOUT-Status. Unix erkennt curl-Exit 28; die
  Statusdatei wird nach Abschluss atomar veröffentlicht.
- Keine automatische Wiederholung, kein stilles Herabsetzen des Denkaufwands,
  kein Abschneiden der Musik und keine Übernahme einer unvollständigen Antwort.
- Vorherige Token-/Preisdiagnosen werden pro Aufruf entfernt. Die bekannten
  Controllerkosten verbleiben in den Gesamt-/Auftragssummen; der Verbrauch der
  abgebrochenen Komposition bleibt ohne echte Usage-Daten ausdrücklich unbekannt.
  Falls echte Verbrauchsdaten vorliegen, werden sie trotz Transportfehler erfasst.

Die Korrektur entfernt ein nachweislich zu frühes lokales Limit. Sie behauptet
nicht, dass eine Gegenstelle innerhalb von zehn Minuten antworten muss.

## Nachweise und Grenzen

`tools/test_ai_timeouts.py` testet die Produktionsfunktionen: Windows-Skript-
Generierung mit 600 Sekunden und verschachtelter Exceptionprüfung, Watchdog,
Status-/Dateibereinigung, keine Wiederholung sowie Controller-Erfolg gefolgt
von Timeout ohne veraltete Verbrauchswerte. Ein tatsächlicher lokaler HTTP-Server
prüft Erfolg und Timeout über den generierten Unix-curl-Pfad; dafür wird nur das
Testzeitlimit auf eine Sekunde verkürzt und das Ziel auf Loopback umgeleitet.
TLS-Prüfung für echte Ziele bleibt unverändert. Der alte Legacy-Rückvergleich
isoliert diese drei bewusst geänderten Einheiten; ihre neuen Verhaltensfälle
haben einen eigenen Regressionstest.

Vollständiger Runner: 16 Python-Suiten und drei Lua-Dateien bestanden.
Kein nativer Windows-/PowerShell-/REAPER- und kein Liveprovider-Test. Die
hochgeladene Diagnose ist ein realer Fehlernachweis, keine Praxisabnahme des Fixes.

Status: Patchfreigabe 1.2.1 vorbereitet in PR #15. Nach Veröffentlichung
gezielte native Windows-/REAPER-Gegenprobe mit repräsentativer Antwort;
keine Serie kostenpflichtiger Wiederholungen.
