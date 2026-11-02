# Projektstand – Composition-Studio

## 02.11.2026 – Machbarkeitsbewertung: Vier REAPER-native Notationsziele NICHT bereits erreicht

**Nutzerfeedback:** Die fruehere Schaltflaeche `Lesbarkeit verbessern` und unsere ersten Konfigurationsversuche haben Notenabstaende, Minipausen, Darstellung und Instrumentenzeilen **nicht gemeinsam auf ein arbeitsfaehiges Niveau** gebracht. Das ist als negatives reales Ergebnis zu respektieren. Keine erneute Schleife der bekannten Sammelaktion.

**Quellen:** Aktuelles offizielles REAPER-Handbuch v7.84 (Nov. 2026) als HTML https://dlx.reaper.fm/userguide/html/, Kapitel 14.5–14.7, aktueller `Notation Studio.lua` v0.1.24 auf main sowie bestehendes ReaTeam-/juliansader-Skript `js_Notation - Set displayed length of selected notes to custom value.lua` auf https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Set%20displayed%20length%20of%20selected%20notes%20to%20custom%20value.lua.

**Einzelurteil:**
1. Notenabstaende: bedingt machbar durch REAPER `Proportional (musical) note spacing` und Zoom; keine bekannte ReaScript-Steuerung des internen Kollision-/Engravingalgorithmus, Erfolg bei dichter Mehrstimmigkeit offen.
2. Minipausen: **groesstes technisches Risiko**. Display quantization/minimum note length ist KEIN allgemeines musikalisch intelligentes Pausenkorrekturwerkzeug. Gezielte visuelle Notenlaengen-Aenderungen per `NOTE ... disp_len` sind durch existierendes ReaTeam-Skript real belegt und reversibel. Nur optische Darstellung, aber Metadaten im MIDI-Take werden geaendert; unveraenderte Note-on/-off-Ereignisse/Wiedergabe sind Bedingung. Bei mehreren Stimmen muss vorher die musikalische Zugehoerigkeit der kurzen Luecke klar sein.
3. Displayquantisierung: REAPER nativ und je Track vorhanden; MIDI-Performance bleibt bei reiner Anzeigequantisierung unveraendert. Technisch machbar, richtige Rasterwahl bei Triolen/kurzen Noten individuell.
4. Separate Notenzeilen und Schluessel: REAPER kann mehrere MIDI-Tracks mit je eigenem `Default clef` darstellen. Wichtige Grenze: Bei mehr als einem sichtbaren Track erfolgt nur horizontale kontinuierliche Ansicht, keine mehrzeilige Satzseite.

**Entscheidung:** Einfache und maessig polyphone Arbeitsnotation erscheint technisch plausibel, aber weder fuer dichte Orgelpolyphonie noch fuer alle vier Anforderungen gleichzeitig bisher nachgewiesen. Keine neue Version/keine neue App/kein weiterer Renderer. **Einzig sinnvoller naechster Test:** einmaliger enger Wirkungsnachweis der bestehenden `disp_len`-Funktion an einer problematischen Kurzpausenstelle der echten REAPER-Notation, mit Vorher/Nachher-Bild und identischen Note-on/-off-Ereignissen, reversibel und auf Kopie. Gegebenenfalls danach die dreispurige Ansicht gegenpruefen. Scheitert dies, ausdruecklich No-Go fuer weitere Eigenautomatik ohne neue REAPER-Schnittstelle und Nutzung bereits fertiger Alternativen erwägen.

**Ausfuehrlichere technische Einordnung:** `NOTATION-MODULE.md`, `Technische Machbarkeit der vier Ziele – 02.11.2026`. Stand ausschliesslich Quell-/Handbuchanalyse, KEIN neuer realer Nutzer-Praxistest.


## 02.11.2026 – Vier konkrete Qualitätskriterien vom Nutzer festgelegt

**Verbindlicher Schwerpunkt:** (1) Optimierung musikalischer Notenabstände, (2) Beseitigung **unsinniger** Minipausen bei Erhalt echter Pausen, (3) reine Displayquantisierung unabhängig von MIDI, (4) separate Notensysteme/Notenzeilen mit zum Instrument passenden Schlüsseln. Konkretisiert im dauerhaften `NOTATION-MODULE.md` unter `Vier verbindliche Qualitätsanforderungen – 02.11.2026`.

**Machbarkeitsbelege aus REAPER-Handbuch:** Proportional musical note spacing; Display quantization + Minimum note length getrennt von MIDI; mehrere sichtbare MIDI-Tracks als getrennte Notenzeilen; `Default clef` je Track/Staff. Mehrere gleichzeitig sichtbare Tracks erzwingen eine kontinuierliche links-rechts Notationsansicht; mehrzeilige Seitenansicht gilt nur beim einzelnen Track. Das ist eine reale Layoutgrenze, die wir mit dem Nutzer abgleichen muessen. Bereits vorhandenes `Notation Studio.lua` v0.1.24 bietet mehrere Aktionen, nicht jedoch einen verifizierten automatischen 4-Punkte-Modus.

**Erster Test:** Native REAPER-Notation der Orgelphantasie mit getrennten sichtbar geschalteten Spuren Manual I/II und Pedal, geeigneten Schlüsseln, proportionalem musikalischem Spacing und **nur** einer vorsichtigen Displayquantisierungs-Testeinstellung (z.B. 1/16, Mindestnotenlänge 1/32). Bildvergleich derselben Takte mit Originalansicht. Keine MIDI-Event-Bearbeitung, keine neue Version, kein eigener Renderer, kein Start von CI- oder API-Tests. Entscheidung erst nach sichtbarer REAPER-Praxis.


## 02.11.2026 – Erste Bestandsaufnahme REAPER-nativer Notationsfunktionen (ohne neuen Code)

**Nutzerziel bestaetigt:** Herausfinden, wie viel sich aus dem **vorhandenen REAPER-Noteneditor** als tatsaechlich lesbare Arbeitsnotation herausholen laesst. Vor Eigenentwicklung und weiteren Releases steht ein begrenzter A/B-Vergleich.

**Quellen:** REAPER User Guide Notation Editor Kapitel 14.5–14.8 (Cockos, https://www.reaper.fm/userguide.php; untersuchte Anleitung u.a. v7.40/v7.50), aktuelles Repository `Notation Studio.lua` v0.1.24 (main, Blob `48274e5767c8d756543bf7fa3a0b9108b639a272`).

**Native REAPER-Funktionen belegt:** proportional (musical) note spacing; Anzeigequantisierung (1/8, 1/16, 1/32, 1/64); Mindestnotenlaenge der Anzeige getrennt vom MIDI-Timing; automatische Erkennung von Triolen, automatische Stimmenzuordnung ueberlappender Noten, Optionen zur Minimierung von Bindungen und rhythmischer Balkensetzung; zoombare/mehrzeilige Darstellung und gezielte Notations-Eigenschaften. Reine Anzeigequantisierung/Mindestlaenge beeinflussen MIDI-Tonereignisse laut REAPER-Handbuch nicht.

**Kritischer Codebefund:** `Notation Studio.lua` besitzt den Button `Lesbarkeit verbessern`, dessen Funktion `cleanup_notation()` bereits ein Paket aus Anzeigeaktionen, Triolenerkennung, automatischer Voice-Umschaltung, Skalierung und Schluesselzuordnung ausfuehrt. **Nicht unkritisch einsetzen**: `set_default_clef_chunk()` ruft `GetTrackStateChunk` und `SetTrackStateChunk` auf, setzt bzw. ersetzt darin `SCORE`-Metadaten, also mehr als bloss den Zoom. Zudem aktiviert die Sammelfunktion ausnahmslos die Triolenerkennung und setzt die Mindestnotenlaenge 1/64, auch wenn das im konkreten Beispiel ggf. unerwuenschte winzige Notenreste sichtbar laesst. Der Button ist **nicht als harmloser A/B-Anzeigeschalter freigegeben**. Vermeide auch `Quantize MIDI notes`, `Correct overlapping notes` als Bearbeitung der eigentlichen Events.

**Empfohlene Testreihenfolge, klein und nachvollziehbar:** Die vorhandene REAPER-Orgelpartitur ist bereits als problematischer Lesbarkeitsfall im Nutzer-Screenshot dokumentiert. In Kopie des Projekts, **im nativen Noteneditor**, zuerst identischen 4-Takt-Ausschnitt anzeigen; dann `Proportional (musical) note spacing` EIN und Displayquantisierung 1/16, Mindestnotenlaenge probeweise 1/32 statt 1/64 vergleichen (nur wenn keine musikalischen 1/64-Noten vorliegen). Weitere aendernde Optionen wie automatische Stimme, Schluessel, Noten-Offsets erst nach diesem reinen Anzeigetest isoliert pruefen. Mit A/B-Bild und ggf. MIDI-Hash/Notenvergleich beurteilen. Nicht mit unserem experimentellen ReaImGui-Fenster verwechseln.

**Stand:** Dokumentations-/Code-Audit, KEIN Realtest dieser Einstellungskombination, keine neue Version, kein produktiver Code geaendert. Nächster Schritt ist genau **ein** A/B-Vergleich am echten REAPER-Notenbild; danach die konkrete darstellungsbedingte Engstelle priorisieren.


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
