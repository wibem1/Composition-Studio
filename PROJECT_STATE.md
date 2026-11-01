# Projektstand – Composition-Studio

## 01.11.2026 – Sichtbarer Notenbild-Testkandidat 0.2 fuer REAPER, separates Feature-Branch

**Auftrag:** Nach den bisherigen GPL-Pausendiagnosen moechte der Nutzer endlich einen sichtbar bedienbaren Notenbild-Prototyp. Dieser Schritt implementiert erstmals eine native (ReaImGui) Score-Vorschau, ohne das bestehende Notation Studio zu ersetzen.

**Feature-Branch:** `feat/notation-score-preview-20261101` direkt von `main` erstellt, **separat** vom GPL-Notator-Branch `feat/notator-gpl-rhythm-audit-20261101`. `Notation Studio.lua` v0.1.24 auf main bleibt unveraendert. Neue Dateien unter `experimental/score-preview/`: `Notation Studio - Notenbild Test.lua`, `score_preview_core.lua`, `README.md`, `tests/test_core.lua`, `tests/test_gui_mock.lua`. Der Kern verwendet **keine** kopierten GPL-Notator-Module.

**Funktionsumfang – implementiert:** Oeffnet ein eigenstaendiges natives ReaImGui-Fenster IN REAPER. Liest MIDI-Noten aus den selektierten MIDI-Items (fallback aktiver MIDI-Editor), zeigt getrennte Systeme, Tonhoehen/vereinfachte Notenkoepfe und Notenwerte, Taktstriche und Hilfslinien, zoomt und blaettert taktweise; Buttons fuer **manuelles** 4/4 oder 3/4 als Display-Testgitter und Anzeige 1/16 oder 1/32. Original-MIDI bleibt unangetastet. Keine KI-/Netzwerkaufrufe, keine Aenderung der Nutzer-Einstellungen.

**Grenzen:** Noch KEIN klassischer vollstaendiger Notensatz: fehlende echte Stimmenzuordnung innerhalb einer Orgelmanual-Spur, Balkengruppen, Bindeboegen, korrektes Vorzeichen-Gedaechtnis, korrekte polyphone Pausen, Triole, Noten-/Taktartwechsel-Automatik und MusicXML/PDF. Die farbig helle Darstellungs-Dauerlinie ist keine Bindung. Die Testversion darf nicht als auffuehrungsfertige Partitur gelten.

**Nachweise:**
- Die beiden Lua-Dateien im vom Nutzer herunterladbaren ZIP (Gesprächsartefakt `Notation_Studio_Notenbild_Test_0.2.zip`) sind *bytegleich* mit den GitHub-Versionen (Git-Blob-SHAs beider Seiten abgeglichen).
- Lua 5.3 lokal: `test_core.lua` bestanden, `test_gui_mock.lua` (echtes GUI-Skript, 22 Zeichenvorgaenge, 0 MIDI-Schreib-APIs) bestanden. Tatsaechliche hochgeladene Orgel-MIDI-Datei lokal geparst und als Lua-Modell mit **1.365 Noten, 3 Systemen und 64 4/4-Takten** erfolgreich aufgebaut. Nutzerdaten nicht in GitHub uebernommen.
- GitHub CI `https://github.com/wibem1/Composition-Studio/actions/runs/41358898500` auf Ubuntu Lua 5.4 `success`: beide Core- und GUI-Mocktests.
- **Echter REAPER-ReaImGui-Grafiklauf Windows/Mac noch NICHT getestet**; kein Hauptprogramm-Release, Draft-PR, kein Merge.

**Naechster einzelner Schritt:** Testpaket in echtem REAPER verwenden, drei passende MIDI-Items markieren, Fenster oeffnen und die lesbare Darstellung beurteilen; dann auf Basis des visuellen Befunds gezielt verbessern. Keine weitere Diagnose-Schleife ohne konkreten Fehler.

Stand: 23.10.2026 · Übernahme des allgemeinen Entwicklungsstandards (Dokumentationsänderung)

## Projekt und belegter Dokumentationsstand
Kompositions-/Bearbeitungsebene in REAPER; README dokumentiert v1.1.6 vom 19.10.2026 als TEST CANDIDATE.
Diese Angaben basieren auf den verfügbaren Projektinformationen; bei dieser Umstellung wurden **keine** aktuellen End-to-End-Tests, Releases oder CI-Artefakte geprüft.

## Globale Regeln
https://github.com/wibem1/AI-Development-Standards/blob/main/DEVELOPMENT_STANDARDS.md

## Nächster Schritt
Vor erneuter Entwicklung Branch, letzten Commit, offene Aufgaben und reale Testnachweise ermitteln. Genau einen kleinen nachprüfbaren Arbeitsschritt auswählen. Bestätigte Testergebnisse mit Quelle/Version hier nachtragen. Bis dahin ist die aktuelle Gesamtfunktion **nicht neu verifiziert**.
