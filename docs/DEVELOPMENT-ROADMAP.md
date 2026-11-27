# Composition Studio – Entwicklungsplan ab 1.4.2

Stand: 27.11.2026 · vom Projektinhaber bestätigte Ausrichtung · **GEPLANT**, keine Releasefreigabe.

## Ziel und Architektur

REAPER bleibt die eigentliche DAW. Vorrang: eigenständige Nutzung und Verwaltung bereits installierter lokaler KI-Komponenten abschließen. Danach universelle Plugin-Parameter-Datenbank und kontrollierte KI-Pluginsteuerung. Composition Studio ergänzt sie um musikalische Komposition, algorithmische MIDI-Patterns und spezialisierte lokale KI-Engines. Keine eigene DAW, keine Abhängigkeit von der laufenden Anwendung oder dem Server AI Music Studio. Deren Quellcode ist eine technische Referenz; einzelne Komponenten, Modelle und vorhandene Modellgewichte sollen nach Kompatibilitäts- und Lizenzprüfung wiederverwendet werden. Keine ungeprüfte Übernahme GPL-lizenzierter Implementierungen; Herkunft und Lizenzpflichten vor Integration klären. Keine automatischen umfangreichen Downloads oder kostenpflichtigen KI-Aufrufe.

## Reihenfolge der Funktionspakete

| Zielversion | Umfang / Abnahmekriterien |
|---|---|
| 1.5.0 | Kompakter, bisheriger angedockter Chat und größerer heller, frei skalierbarer Studiomodus; Umschaltung ohne Verlust von Verlauf, Auftrag oder Einstellungen, Fensterposition/-größe merken; Andocken bzw. Maximieren soweit ReaImGui/REAPER unterstützt. Bestehende Chat- und Updatefunktionen unverändert nutzbar. Neue Arbeitsbereiche modular vorbereiten, keine funktionslosen Bedienelemente als fertige Funktionen ausgeben. |
| 1.6.0 | Eigenständiger KI-Engine-Manager: vorhandene Modelle/Umgebungen erkennen und auf echte Einsatzbereitschaft prüfen; Katalog, Installation, Aktualisierung, Deinstallation eigener Komponenten, Versions-/Kompatibilitätsprüfung, Speicherbedarf, Fortschritt, Abbruch, Diagnose. Dynamischer, separat gepflegter Modellkatalog mit geprüften Quellen, Lizenzen und Versionspins; keine beliebige Remote-Codeausführung. Isolierte Python-Umgebungen, Wiederverwendung kompatibler Gewichte, Rückfallmöglichkeit, keine Veränderung fremder Installationen. |
| 1.7.0 | Universeller Plugin-Scanner und persistente, durchsuchbare Parameter-Datenbank (siehe Implementierungsauftrag unten). |
| 1.8.0 | Kontrollierte KI-Pluginsteuerung, gezielte Handbuchabfrage und Presetwissen; Vorschau, Bestätigung, Rücklesen und Undo. Keine Annahme eines Zugriffs auf interne Editoren. |
| 1.9.0 | MIDI Pattern Studio: offline, algorithmische Erzeugung von rhythmischen, melodischen und harmonischen Patterns (Drums, Bass, Akkorde, Gitarre, Arpeggien, Ostinati, klassische Begleitmuster und perspektivisch kontrapunktische Figuren); Stil, Taktart einschließlich 5/4 und 7/8, Länge, Harmonie, Dichte, Swing, Humanisierung, reproduzierbare Varianten und Fills. Eigene Bibliothek, abgestimmte Mehrspur-Patterns, Vorhören, bewusstes Einfügen in REAPER; optional musikalische Überarbeitung mit vorhandener Kompositions-KI. Erste nutzbare Teilmenge vor weiteren Ausbaustufen. |
| 1.10.0 | Audioanalyse und iterative Klangoptimierung: kurze MIDI-Testsequenzen, kontrolliertes Rendering, messbare Klangmerkmale, Nutzer-Hörabnahme; CPU- und API-Budget begrenzen. |
| 1.11.0 | MIDI-DDSP eigenständig ansprechen: ausgewählte MIDI-Daten eines geeigneten Instruments als Audio interpretieren, unterstützte Ausdrucksparameter nach tatsächlicher Engine-Schnittstelle anbieten, Ergebnis vor Übernahme prüfen, neue Audiospur statt Originaländerung. |
| 1.12.0 | Eigenständige Gesangssynthese (SoulX-Singer, ggf. DiffSinger nach Eignung): MIDI-Melodie, Text, Stimme und Stil; kurze Render- und Hörtests, insbesondere deutsche Aussprache. |
| 1.13.0 | Audio zu MIDI (Basic Pitch) und Stem-Trennung (Demucs, ggf. MDX-Net); geeignete Audioauswahl, Ergebnisprüfung und bewusste Übernahme. |
| 1.14.0 | Weitere geeignete Musikmodelle, z. B. ACE-Step 1.5, Seed-VC, nach Hardware-, Lizenz- und Qualitätstest; keine Pflicht zur Integration aller Modelle. |

Versionen sind Zielmarken, keine vorhandenen Releases; erforderliche Teilversionen eindeutig versionieren.

## Grenzen und belegter Ausgangspunkt

- Letzte veröffentlichte Testfassung: 1.5-test1 (26.11.2026); vorheriger Stand 1.4.2; bestehender Updatepfad über Studio-Menü → Update mit Backup. Modulare Lua-Quellen unter src/; Standalone-Artefakte ausschließlich über tools/build_studio.py erzeugen.
- Auf dem Windows-PC wurde die lokale AI-Music-Studio-Schnittstelle durch den Nutzer erreicht (health: ok, Backend 0.2.0, CPU, Intel UHD 620, 15,7 GB RAM). MIDI-DDSP-Status ddsp=true, ace=false, cuda=false; Stimmenkatalog abrufbar. Dies beweist weder unabhängige Nutzbarkeit noch Renderingqualität. Installierte Modellgewichte, Python-Umgebungen und tatsächlicher Dateibestand sind noch nicht direkt geprüft.
- AI Music Studio darf für die Zielarchitektur weder gestartet noch als Server vorausgesetzt werden. Lokale Erkennung und unabhängige Funktionsprüfungen sind erforderlich; fremde Installationen nur lesend erkennen, eigene Verwaltung getrennt führen.
- Pattern-Referenz: pierrecinema/ai-music-studio (band.ts, songgen.ts; tatsächlichen Code und Lizenz vor Adaption prüfen). Algorithmische Generierung bleibt ohne API und ohne zusätzliche Modellinstallation nutzbar.
- Keine automatische Steuerung der DAW als Selbstzweck. Originale MIDI-/Audiospuren und bestehende Projekt-/Verlaufsdaten schützen. Änderungen ausdrücklich übernehmen, Undo ermöglichen. CPU-/RAM-Last begrenzen, Engines nur bei Bedarf ausführen; keine unaufgeforderten Installationen oder Updates.

## Nächster konkreter Auftrag: lokale KI-Komponenten (Ziel 1.6.0)

Prioritätskorrektur durch Projektinhaber am 27.11.2026: bisherigen Integrationsauftrag zuerst abschließen, Plugin-Datenbank zurückstellen. 1.5-test1 bleibt geschützter Ausgangspunkt; native UI-Abnahme offen.

- Zunächst tatsächliche lokale Installationen, Python-Interpreter, Modellgewichte und unterstützte Schnittstellen ermitteln. Aus GitHub-Quellcode allein nicht auf den PC-Bestand schließen. In Composition Studio eine lesende, vom Nutzer auslösbare Diagnose mit Pfadangaben, Versions-/Importprüfung und Export implementieren; keine vollständige Festplattensuche.
- AI Music Studio nur als Quellcode-/Installationsreferenz nutzen. Kein Zwang, dessen Anwendung oder Server zu starten. Kompatible vorhandene Modelle und Umgebungen nach Lizenzprüfung nutzen, eigene Komponenten getrennt verwalten.
- Erste vertikale Integration: MIDI-DDSP priorisieren, da dessen Verfügbarkeit zuvor gemeldet wurde; reale unabhängige Inferenz mit kurzer MIDI-Testsequenz und validiertem Audioergebnis nachweisen. Nur tatsächlich unterstützte Stimmen und Parameter anzeigen. Audio nach Vorschau und Bestätigung auf neuer Spur importieren, Original unverändert lassen. CPU-Betrieb, Abbruch, Timeout, Fortschritt und Fehlerdiagnose berücksichtigen.
- Engine-Manager: Status je Komponente (gefunden, importierbar, lauffähig geprüft, inkompatibel, fehlt), manuelle Pfadwahl, geprüfter Katalog, explizite Installation/Updates eigener Komponenten mit Versionspins, Speicherbedarf und Rückfall. Keine Veränderung fremder Installationen und keine ungefragten Downloads. Weitere vorhandene Engines nach tatsächlicher Eignung anbinden; fehlende Modelle nicht als integriert melden.
- Automatisierte Offline-/Mocktests und bestehende Update-/Layoutregressionen, anschließend echte Windows-/REAPER-Gegenprobe mit vorhandenen Modellen. Ohne lokalen Zugriff Diagnose-/Testpaket bereitstellen und dessen reale Ergebnisse einholen, keine erfolgreiche Integration behaupten. Nachweis der unabhängigen Audioerzeugung ist Abnahmekriterium, bloßer Health-Status genügt nicht.
- MIDI-DDSP-Ausbau in 1.11.0 bleibt für vertiefte Ausdruckssteuerung und weitere Instrumente vorgesehen; erste nutzbare Anbindung gehört bereits zu 1.6.0. Plugin-Datenbank erst danach.

## Folgeauftrag: Plugin-Datenbank (Ziel 1.7.0)

Beschlossen am 27.11.2026. Die native Abnahme von 1.5-test1 bei 150 % Windows-Skalierung bleibt offen; den bestehenden Stand schützen. Die Entwicklung des Scanners kann isoliert auf einem neuen Branch auf Basis des aktuellen main erfolgen. Keine endgültige Freigabe von 1.5.0 behaupten.

### Umfang des ersten Funktionspakets

- Eigenen Arbeitsbereich „Plugin-Datenbank“ in der Studioansicht einrichten, Kompaktansicht und Chat unverändert erhalten. Keine externe App oder obligatorische Python-Laufzeit.
- Installierte FX über REAPER EnumInstalledFX inventarisieren; Instrumente, Effekte und Sampler verschiedener unterstützter Formate erfassen. Installationsliste und tatsächlich analysierte Plugininstanzen getrennt behandeln.
- Bereits geladene ausgewählte FX zunächst ausschließlich lesend analysieren. TrackFX_GetNumParams, GetParamName, GetParamIdent, GetParam/GetParamNormalized, GetParameterStepSizes, GetFormattedParamValue und Presetabfrage nach tatsächlicher API-Verfügbarkeit prüfen. IDs, Indizes, Namen, rohe und normalisierte Werte, Bereiche, Schrittweiten, formatierte Werte, Pluginidentität, Format, Version soweit nachweisbar und Scanzeit speichern. Instanz-/Presetzustand von dauerhaftem Parameterschema trennen. Fehlende Angaben explizit unbekannt, keine geratenen Einheiten oder IDs.
- Selektiven Scan nicht geladener Plugins erst nach sicherer Machbarkeitsprüfung in separater Testprojektumgebung, niemals automatisch im Benutzerprojekt. Seriell, abbrechbar, Fortschritt und Fehler je Plugin, wiederaufnehmbar; problematische Plugins überspringen, keine unkontrollierten Retry-Schleifen. Kein Anspruch auf Schutz vor sämtlichen nativen Pluginabstürzen.
- Persistenter lokaler Katalog, SQLite bevorzugt sofern ohne problematische native Abhängigkeiten zuverlässig verfügbar; andernfalls versioniertes JSON mit atomarem Schreiben, Backup und Migrationspfad. Speicherort unter REAPER-Ressourcenpfad, nicht projektspezifisch. Suche, Filter, Detailansicht, Aktualisierung und JSON-Export für Diagnose. Keine API-Schlüssel, keine unnötigen Plugin-State-Blobs.
- Parameterzugriff dokumentieren: lesbar, potenziell steuerbar, praktisch verifiziert steuerbar, unbekannt/nicht exponiert unterscheiden. Keine Schreibtests im ersten Paket. Dynamische Parameterlisten nach Preset-/Enginewechsel berücksichtigen. Keine Plugins anhand bloßer Namen zusammenführen, soweit eindeutige Identitäten verfügbar sind.
- Schnittstelle für späteren KI-Kontext: nur relevante Plugin-/Parametergruppen und aktuellen Instanzzustand abrufen; keine vollständige Datenbank in jeden Prompt. Handbuchzuordnung und Erfahrungswissen als erweiterbare Metadaten vorsehen. Keine kostenpflichtigen KI-Aufrufe im Scanner.

### Abnahme

Automatisierte Tests mit REAPER-Mocks für Inventar, Nullparameter, fehlende IDs, dynamische Parameter, doppelte Namen, Scanfehler, Persistenz/Reload, Abbruch, Export und UI; bestehende Layout-/Workflow-/Update-Regressionen. Native REAPER-Gegenprobe auf Windows mit Ultra, Pigments, HALion und einem einfachen Effekt: angezeigte Parameter mit REAPER vergleichen, gespeicherten Katalog nach Neustart wiederfinden, vorhandenes Projekt unverändert lassen. Ergebnisse und offene Grenzen in PROJECT_STATE.md dokumentieren. Neue Testversion eindeutig kennzeichnen; Veröffentlichung erst nach den erforderlichen Prüfungen und Freigabe. Quellmodule unter src/, Artefakte über vorhandenen Generator erstellen.

### Folgepaket 1.8.0

KI-Pluginsteuerung mit explizitem Ziel (Track/FX-Identität), begrenzten normalisierten Werten, Vorschau, Bestätigung, Schutz vor veraltetem Instanzzustand, Rücklesen, Undo und gegebenenfalls Zustandssicherung. Handbücher lokal zuordnen und relevante Abschnitte abrufen; Presetwissen und erfolgreiche Klangrezepte speichern. UltraWave Blend, Sample-Import, Modulationsmatrix, interne Enginewechsel und vergleichbare proprietäre Funktionen sind nicht automatisch über VST-Parameter zugänglich; gezielt prüfen und Grenzen anzeigen. Keine UI-Automatisierung als Voraussetzung. Musikalische Qualität durch Nutzer-Hörtest, nicht bloß Parameteränderung belegen.

