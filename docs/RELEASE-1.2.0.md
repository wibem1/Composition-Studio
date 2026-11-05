# Composition Studio 1.2.0 – Testfreigabe

05.11.2026. Neue musikalische Funktionen aus PR #14, Veröffentlichung auf
expliziten Nutzerauftrag über den bestehenden Studio-main-Updater.

## Neue Funktionen

- Musikalische Nutzerentscheidungen pro Projekt mit `Merke musikalisch: …`
  speichern, mit `Zeige Musikgedächtnis` anzeigen und mit
  `Lösche Musikgedächtnis` bewusst zurücksetzen. Diese Befehle sind lokal.
- `Analysiere den Werkzusammenhang` und `Prüfe den musikalischen Gesamtzusammenhang`
  ergänzen die bestehende Analyse um strukturiertes mehrstimmiges Material
  und gespeicherte musikalische Präferenzen.
- `Entwickle die Auswahl zu einem vollständigen Song` erzeugt einen ganzen
  Vorschlag samt Abschnitten, Stimmenrollen und Formbeziehungen in einem
  Anbieteraufruf. Erst **Änderungen anwenden** schreibt zusätzliche Spuren.
  Quellspuren und vorhandene Tempo-/Taktkarte bleiben erhalten.

Für den Hörvergleich die neuen Songspuren solo schalten; Quellspuren werden
nicht automatisch stummgeschaltet. Projekt speichern, um das Gedächtnis zu
bewahren. [Befehle, Formate und technische Grenzen](MUSIC-WORKSPACE.md).

## Grenzen

Erster begrenzter Songpfad, kein mehrstufiger Song-Agent. Das Gedächtnis speichert
zunächst explizite Nutzerentscheidungen, keine automatisch erkannten Motivgraphen.
Form-/Rollenbezüge sind KI-Interpretationen, keine nachgewiesene musikalische
Qualität. Kein neues Tempo/Taktmaß oder Pitch Bend im Songpfad. Keine automatische
Verbesserungsschleife. Ein Aufruf pro neuer Analyse/Song begrenzt die Aufrufzahl,
garantiert aber keinen Geldbetrag; die vorhandene Kostenanzeige bleibt aktiv.

Keine Übernahme von Notations-PR #12 und keine Änderung der Composition Engine.

## Prüfungen und Installation

15 Python-Suiten und drei Lua-Dateien sowie die fünf CI-Jobs haben den
Featurestand bestanden. Der Release-Kandidat wird zusätzlich mit 1.2.0-Kennung
und synchronisierten Artefakten vollständig geprüft, einschließlich exakter
Offline-Installation aus 1.1.11 mit Backup. Konkrete Commit-/Prüfnachweise stehen
in PROJECT_STATE.md und PR #14.

Kein Liveprovider-/Hör-/nativer REAPER-/Windows-/macOS-Test. Echter
LilyPond-Compiler ohne Konfiguration ausdrücklich ausgelassen.
**Testfreigabe, keine bestätigte vollständige Produktreife.**

Installation: **Studio-Menü → Update**, danach Studio neu starten. Die App bleibt
eine eigenständige Lua-Datei; Installer-/Backup-/Rollbackpfad bleiben erhalten.
Keine Migration oder Zurücksetzung vorhandener Projekte, Einstellungen, Schlüssel
oder Ergebnisverläufe. Neues Gedächtnis verwendet den separaten Projektschlüssel
`MusicMemoryV1`. Alte 1.1.11 ignoriert diesen Schlüssel, kann neue Songvorschläge
aber nicht anwenden. Letzter Stand: `2742b497de4e2e15c95d86972bb8c6617fd4a3fd`.
