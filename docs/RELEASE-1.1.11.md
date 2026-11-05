# Composition Studio 1.1.11 – Testfreigabe

05.11.2026. Veröffentlichung auf ausdrücklichen Nutzerauftrag über den
bestehenden `main`-Updateweg; kein neuer Installationskanal.

## Änderungen

- Bestehende Entwicklungsquellen nach Verantwortlichkeiten in 50 Quellbereiche
  unter `src/` gegliedert; 17 portable Module/Factories. Hostmodule teilen
  weiterhin den bisherigen REAPER-Sitzungszustand.
- Reine CS-Operationsplanung vom nativen MIDI-/Tempo-/CC-Commit getrennt;
  Auswahl-/Referenzschutz, Freigabe, Persistenz und Undo bleiben erhalten.
- JSON-Unicode-Escapes scheitern nicht mehr an der lokalen Namensverschattung
  der Lua-UTF-8-Bibliothek. Lokale HTTP-Testfixture mit expliziten Testschlüsseln
  und getrenntem Missing-Key-Fall korrigiert.
- Gesamtbuild, Modul-/Abhängigkeitskarte, Schnittstellen- und Auditdokumentation
  sowie vollständiger Offline-Testlauf in CI ergänzt.

Musikalische Prompts, Kompositionsalgorithmen und Defaultablauf bleiben erhalten.
Keine Engineumstellung, keine neue Song-/Memory-/Notationsfunktion und keine
Integration der getrennten Notationsarbeit aus PR #12.

## Installation und Wiederherstellung

**Studio-Menü → Update**, danach Studio neu starten. Header und Laufzeitversion
sind 1.1.11. Studio bleibt eine eigenständige Lua-Datei ohne zusätzliche
Laufzeitmodule. Rescue-Updater und Offline-Installer stammen aus demselben
Gesamtbuild. Die bestehende Backup-/Rollback-/Repairlogik bleibt unverändert.
Einstellungen, gespeicherte Ergebnisse und Projekte werden nicht migriert.

Letzter Produktionsstand: 1.1.10, Commit
`4743491d7081cf009f144a88b70c373047febeab`. Der Offline-Installertest prüft
nun zusätzlich diesen exakten Startstand und das bytegenaue Backup.

## Prüfgrundlage und Grenzen

Der Refactoringstand hat 14 Python-Suiten, drei Lua-Dateien und fünf CI-Jobs
bestanden. Darunter portable Modulgrenzen, 60 Plan-/Commit-Differentialfälle,
Versionsvergleich, Startmocks, UI/Modelle/Kosten/Reasoning, Originalschutz,
Apply/Undo/Rollback sowie Installer-/Backup-/Payloadprüfungen.
Der Release-Kandidat durchläuft vor Merge denselben vollständigen Runner und CI
mit neuer Versionskennung und synchronisierten Installern; konkrete Ergebnisse
stehen im Projektstand und in PR #13.

Der echte LilyPond-Compilerlauf wird ohne konfigurierten Compiler ausdrücklich
übersprungen. REAPER ist in dieser Cloud nicht installiert. Keine native
Windows-/macOS-/REAPER-, Hör-, Liveprovider- oder Update-/Neustartabnahme.
**Testfreigabe, keine bestätigte vollständige Produktreife.** Erste Anwendung
an einer gesicherten Projektkopie; installierte Nutzerfassungen werden durch
den GitHub-Merge nicht automatisch ersetzt.
