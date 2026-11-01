# Projektstand – Composition-Studio

## 02.11.2026 – Verbindliche Prioritaet: Bestehenden REAPER-Noteneditor brauchbar machen (kein neuer Renderer)

**Entscheidung des Projektinhabers:** Zuerst klären, ob der bereits in REAPER 7.83 vorhandene Notationseditor mit vertretbarem Aufwand eine **hinreichend lesbare und korrigierbare Arbeitsnotation** liefern kann. Kein Nachbau von REAPER-Notator, kein monatelanges Eigenrendering, kein Anspruch an perfekte Druckpartitur. Ein erfolgreiches Ergebnis braucht nachvollziehbare Rhythmen und Stimmen, ausreichende Abstaende und unveraendertes MIDI.

**Korrektur bisheriger Entwicklungsrichtung:** Separater ReaImGui-Score-Preview `feat/notation-score-preview-20261101`/Draft PR #4 (v0.2.0–0.2.3-test) als Entwicklungsweg **angehalten/verworfener Ansatz**. Nach Nutzer-Screenshot war v0.2.2 zwar als eigenes Fenster unter Windows real sichtbar, aber noch kein brauchbarer Notensatz. Diese experimentellen Dateien werden nicht nach `main` uebernommen. GPL-Engraver-Audit `feat/notator-gpl-rhythm-audit-20261101`/Draft PR #3 bleibt isoliert; keine Entwicklungsverpflichtung, ihn zu einem Ersatzeditor umzubauen.

**Aktuelle Codebasis auf `main` (geprüft, nicht erneut unter Windows freigegeben):** `Notation Studio.lua` v0.1.24, Git-Blob `48274e5767c8d756543bf7fa3a0b9108b639a272`. Bereits implementiert sind REAPER-Aktionsaufrufe zur `Proportional (musical) note spacing`, Displayquantisierung 1/8–1/32, Zoom, Auswahl/Inhalt einpassen und `Lesbarkeit verbessern` inkl. Aktionen fuer Anzeige- und Mindestnotenlaengen. Das sind wichtige bestehende Ausgangspunkte, keine Garantie fuer die grafische Wirkung.

**Naechster einzelner Schritt:** Ein kurzer A/B-Machbarkeitstest auf denselben 2 exemplarischen Ausschnitten (eine Solo-/Melodiepassage, eine mehrstimmige Passage) **in REAPERs eigenem MIDI-Noteneditor**, mit geprueften Einstellungen fuer Darstellung/Abstand/Stimmen. Dokumentiere nur sichtbare Vorher-/Nachher-Verbesserung und unveraendertes MIDI. Danach Go/No-Go. **Keine neue Softwareversion, kein neues Testfenster** vor dieser sachlichen Entscheidung.

**Dauerhaftes Pflichtenheft und durch fruehere Architekturabschnitte nicht mehr aufgehobene Vorgabe:** `NOTATION-MODULE.md`, Abschnitt `Verbindliche Zielkorrektur – 02.11.2026`. Code oder bestehendes Benutzerprojekt wurde nicht veraendert.

Stand: 23.10.2026 · Übernahme des allgemeinen Entwicklungsstandards (Dokumentationsänderung)

## Projekt und belegter Dokumentationsstand
Kompositions-/Bearbeitungsebene in REAPER; README dokumentiert v1.1.6 vom 19.10.2026 als TEST CANDIDATE.
Diese Angaben basieren auf den verfügbaren Projektinformationen; bei dieser Umstellung wurden **keine** aktuellen End-to-End-Tests, Releases oder CI-Artefakte geprüft.

## Globale Regeln
https://github.com/wibem1/AI-Development-Standards/blob/main/DEVELOPMENT_STANDARDS.md

## Nächster Schritt
Vor erneuter Entwicklung Branch, letzten Commit, offene Aufgaben und reale Testnachweise ermitteln. Genau einen kleinen nachprüfbaren Arbeitsschritt auswählen. Bestätigte Testergebnisse mit Quelle/Version hier nachtragen. Bis dahin ist die aktuelle Gesamtfunktion **nicht neu verifiziert**.
