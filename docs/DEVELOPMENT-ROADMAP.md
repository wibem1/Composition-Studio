# Composition Studio – Entwicklungsplan ab 1.4.2

Stand: 26.11.2026 · vom Projektinhaber bestätigte Ausrichtung · **GEPLANT**, keine Releasefreigabe.

## Ziel und Architektur

REAPER bleibt die eigentliche DAW. Composition Studio ergänzt sie um musikalische Komposition, algorithmische MIDI-Patterns und spezialisierte lokale KI-Engines. Keine eigene DAW, keine Abhängigkeit von der laufenden Anwendung oder dem Server AI Music Studio. Deren Quellcode ist eine technische Referenz; einzelne Komponenten, Modelle und vorhandene Modellgewichte sollen nach Kompatibilitäts- und Lizenzprüfung wiederverwendet werden. Keine ungeprüfte Übernahme GPL-lizenzierter Implementierungen; Herkunft und Lizenzpflichten vor Integration klären. Keine automatischen umfangreichen Downloads oder kostenpflichtigen KI-Aufrufe.

## Reihenfolge der Funktionspakete

| Zielversion | Umfang / Abnahmekriterien |
|---|---|
| 1.5.0 | Kompakter, bisheriger angedockter Chat und größerer heller, frei skalierbarer Studiomodus; Umschaltung ohne Verlust von Verlauf, Auftrag oder Einstellungen, Fensterposition/-größe merken; Andocken bzw. Maximieren soweit ReaImGui/REAPER unterstützt. Bestehende Chat- und Updatefunktionen unverändert nutzbar. Neue Arbeitsbereiche modular vorbereiten, keine funktionslosen Bedienelemente als fertige Funktionen ausgeben. |
| 1.6.0 | MIDI Pattern Studio: offline, algorithmische Erzeugung von rhythmischen, melodischen und harmonischen Patterns (Drums, Bass, Akkorde, Gitarre, Arpeggien, Ostinati, klassische Begleitmuster und perspektivisch kontrapunktische Figuren); Stil, Taktart einschließlich 5/4 und 7/8, Länge, Harmonie, Dichte, Swing, Humanisierung, reproduzierbare Varianten und Fills. Eigene Bibliothek, abgestimmte Mehrspur-Patterns, Vorhören, bewusstes Einfügen in REAPER; optional musikalische Überarbeitung mit vorhandener Kompositions-KI. Erste nutzbare Teilmenge vor weiteren Ausbaustufen. |
| 1.7.0 | Eigenständiger KI-Engine-Manager: vorhandene Modelle/Umgebungen erkennen und auf echte Einsatzbereitschaft prüfen; Katalog, Installation, Aktualisierung, Deinstallation eigener Komponenten, Versions-/Kompatibilitätsprüfung, Speicherbedarf, Fortschritt, Abbruch, Diagnose. Dynamischer, separat gepflegter Modellkatalog mit geprüften Quellen, Lizenzen und Versionspins; keine beliebige Remote-Codeausführung. Isolierte Python-Umgebungen, Wiederverwendung kompatibler Gewichte, Rückfallmöglichkeit, keine Veränderung fremder Installationen. |
| 1.8.0 | MIDI-DDSP eigenständig ansprechen: ausgewählte MIDI-Daten eines geeigneten Instruments als Audio interpretieren, unterstützte Ausdrucksparameter nach tatsächlicher Engine-Schnittstelle anbieten, Ergebnis vor Übernahme prüfen, neue Audiospur statt Originaländerung. |
| 1.9.0 | Eigenständige Gesangssynthese (SoulX-Singer, ggf. DiffSinger nach Eignung): MIDI-Melodie, Text, Stimme und Stil; kurze Render- und Hörtests, insbesondere deutsche Aussprache. |
| 1.10.0 | Audio zu MIDI (Basic Pitch) und Stem-Trennung (Demucs, ggf. MDX-Net); geeignete Audioauswahl, Ergebnisprüfung und bewusste Übernahme. |
| 1.11.0 | Weitere geeignete Musikmodelle, z. B. ACE-Step 1.5, Seed-VC, nach Hardware-, Lizenz- und Qualitätstest; keine Pflicht zur Integration aller Modelle. |

Versionen sind Zielmarken, keine vorhandenen Releases; erforderliche Teilversionen eindeutig versionieren.

## Grenzen und belegter Ausgangspunkt

- Letzte veröffentlichte Testfassung: 1.4.2; bestehender Updatepfad über Studio-Menü → Update mit Backup. Modulare Lua-Quellen unter src/; Standalone-Artefakte ausschließlich über tools/build_studio.py erzeugen.
- Auf dem Windows-PC wurde die lokale AI-Music-Studio-Schnittstelle durch den Nutzer erreicht (health: ok, Backend 0.2.0, CPU, Intel UHD 620, 15,7 GB RAM). MIDI-DDSP-Status ddsp=true, ace=false, cuda=false; Stimmenkatalog abrufbar. Dies beweist weder unabhängige Nutzbarkeit noch Renderingqualität. Installierte Modellgewichte, Python-Umgebungen und tatsächlicher Dateibestand sind noch nicht direkt geprüft.
- AI Music Studio darf für die Zielarchitektur weder gestartet noch als Server vorausgesetzt werden. Lokale Erkennung und unabhängige Funktionsprüfungen sind erforderlich; fremde Installationen nur lesend erkennen, eigene Verwaltung getrennt führen.
- Pattern-Referenz: pierrecinema/ai-music-studio (band.ts, songgen.ts; tatsächlichen Code und Lizenz vor Adaption prüfen). Algorithmische Generierung bleibt ohne API und ohne zusätzliche Modellinstallation nutzbar.
- Keine automatische Steuerung der DAW als Selbstzweck. Originale MIDI-/Audiospuren und bestehende Projekt-/Verlaufsdaten schützen. Änderungen ausdrücklich übernehmen, Undo ermöglichen. CPU-/RAM-Last begrenzen, Engines nur bei Bedarf ausführen; keine unaufgeforderten Installationen oder Updates.

## Nächster konkreter Auftrag: 1.5.0

Auf separatem Entwicklungsbranch bestehende ReaImGui-Oberfläche um gemeinsamen Sitzungszustand und umschaltbare Kompakt-/Studioansicht erweitern. Helles Studiodesign, persistente Fensterpräferenzen, Platz für künftige Module; vorhandenen Chat, Modellwahl, Anwenden, Verlauf, Einstellungen und Updater erhalten. Noch keine Engine-Anbindung und kein Pattern-Generator. Mit vorhandenen Layout-/Workflow-/Update-Regressionen prüfen, anschließend gezielte native REAPER-Abnahme. Stand 1.4.2 bis zur Freigabe schützen. Kein Release allein aufgrund dieser Planung.
