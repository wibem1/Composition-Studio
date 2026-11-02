# Projektstand – Composition-Studio

## 02.11.2026 – Schnittstellenprüfung: Welche Notationsanweisungen kann REAPER wirklich umsetzen?

**Anlass:** Der Nutzer weist zutreffend darauf hin, dass vor einer musikalischen Vorinterpretation zunächst genau geklärt sein muss, welche **Steuerungsmöglichkeiten und -grenzen** REAPERs interne Notationsengine hat.

**Neu erstellt:** [docs/REAPER-NOTATION-STEUERBARKEIT-2026-11-02.md](docs/REAPER-NOTATION-STEUERBARKEIT-2026-11-02.md). Quellgrundlage: REAPER User Guide v7.84 Kap. 14.5–14.9, offizielle ReaScript-API aus REAPER v7.83, ReaTeam/juliansader-Skripte, eigener `Notation Studio.lua` v0.1.24.

**Technisch abgesicherte Erkenntnisse:**
- **GUI-seitig belegbar:** Displayquantisierung und Mindestnotenlänge pro Track / Projekt, Default- und Wechsel-Schlüssel, High-/Low-Stimmen, Beaming / Tie-Minimierung, auto triplet, proportional spacing, MIDI-Trackliste und mehrspurig continuous layout.
- **ReaScript-seitig belegt:** Aufruf von MIDI-Editor-Aktionen, Steuerung der Editor-Horizontal-Skalierung (`pixels_per_timebase_unit`), Zugriff auf Takes/Tracks/MIDI-Events und Notationsmetadaten Typ 15, z. B. individuelles `disp_len` (als Offset zur MIDI-Länge), gespeicherte `staff`-/`voice`-Metadaten. **Keine** in `MIDIEditor_SetSetting_int` dokumentierte direkte pro-Track-Quantisierung/Schlüssel-Setter; native Aktionen/Chunk-Hacks sind nicht gleich verifizierte dauerhafte Steuerbarkeit.
- **Nicht direkt steuerbar:** Erzeugte grafische Pausen einzeln entfernen, horizontalen Engraving-/Kollisionsalgorithmus mit beliebigen X-Werten ersetzen, beliebige Mehrspur-Systemumbrüche durchsetzen; daher kein blindes Versprechen für Ziele 1/2.
- **Neue wichtige Sicherheitseinschränkung:** Manuell angelegte/edierte Tuplets können laut Handbuch echte MIDI-Note-On-/Note-Off-Positionen verändern! Nur automatische Anzeigeerkennung für unverändertes MIDI zulassen, ohne ausdrückliche Zustimmung zum echten Edit.
- **Eigene bekannte Problemstellen:** `cleanup_notation()` benutzt unscharfe Action-Textsuche, unterscheidet unbekannte Toggle-Zustände teilweise nicht, schreibt `SCORE` über undokumentierten Track-Chunk und beeinflusst keine internen Glyph-/Abstandsberechnungen.

**Entscheidung:** Die Notations-Vorinterpretation ist **bedingt technisch plausibel**, nicht bewiesen. Vorerst Dokumentation statt neuer Code; bei Umsetzung höchstens ein gebündelter kontrollierter REAPER-Praxistest der acht Takte (plus höchstens eine Nachprüfung); keine Serie manueller Experimente.


## 02.11.2026 – Kontrollierte 8-Takt-Referenz-MIDI erzeugt und offline geprueft

**Ausloeser:** Nutzer schlaegt statt zufaellig gewaehlter Musik eine gezielt aufgebaute Test-MIDI-Datei vor, um die vier Kriterien ohne lange Testserie objektiv zu pruefen.

**Konkretes Artefakt (Chat):** `REAPER_Notation_Gezielter_Machbarkeitstest_8_Takte.mid`, MIDI SMF Type 1, PPQ 960, g-Moll, 4/4, 96 BPM, 8 Takte, 1451 Byte, SHA-256 `f55ec9c9f2d8a18174959ef7acdfcb4e703a9fe69c657d5d0bf2d49de638fbbf`, 3 Instrumentalspuren mit 117 Noten: Violine (62, G-Schluessel), Bratsche (36, Alt-C-Schluessel), Violoncello (19, F-Schluessel), plus eine Metaspur. Dazu wurden `REAPER_Notation_Testanleitung.txt` und `REAPER_Notation_Testreferenz.json` erstellt; ein ZIP-Gesamtpaket `REAPER_Notation_Machbarkeitstest_Komplettpaket.zip` liegt ebenfalls im Chat.

**Testfaelle:** Takte 1–2 exakt gerasterte Kontrolle; 3–4 **exakt dieselben Onsets/Tonhoehen**, aber MIDI-Note-offs um 1–55 Ticks frueher (bewusst kunstliche Minipausen); 5–6 echte Achtel-/Sechzehntel-/Viertelpausen, die **nicht** entfernt werden duerfen; 7 exakt 320-Tick-Achteltriolen und leicht humanisierte Viola-Onsets; 8 echte Polyphonie in Violine/Bratsche. Bewusst ein *einziger* 8-Takt-Datensatz fuer alle vier Ziele.

**Nachweise:** Die erzeugte MIDI-Datei wurde unmittelbar mit einem getrennten mido-Datei-Parser wieder eingelesen; alle 117 Noten, ihre Start-/Endzeiten, Tonhoehen, Anschlagsstaerken und die spezifischen 1–55-Tick-Luecken, 320-Tick-Triolen und ueberlappenden Stimmen wurden gegen die vorgabeseitig gebildete Goldstandard-Referenz geprueft. Ebenso wurde ZIP-Integritaet/Dateigleichheit geprueft. **Dies belegt nur MIDI-Dateistruktur und Testfaelle, keinen REAPER-Grafiktest und noch keine Verbesserung.** Standard-MIDI speichert Schluessel nicht verbindlich; Zuordnung muss im nativen REAPER-Editor erfolgen.

**GitHub-Dokumentation:** [tests/fixtures/reaper-notation/README.md](tests/fixtures/reaper-notation/README.md) enthaelt Kurzspezifikation, Sollbedingungen, Pruefstatus und SHA. Die MIDI-Binaerdatei/JSON sind weiterhin **nur Chat-Artefakte**, nicht ins Repo hochgeladen. **Keine Veraenderung an Notation Studio 0.1.24, keine neue App-Version, kein Nutzer-Praxistest.**

**Naechster Schritt:** Die vier eigentlichen Darstellungsalgorithmen/Notationsmetadaten gegen diese kontrollierten Faelle offline absichern und erst danach **einen** gebuendelten REAPER-7.83-Praxistest fuer die native Notation organisieren. Keine neue Testserie.


## 02.11.2026 – Verbindliche Testdisziplin: Keine Testserien beim Nutzer

**Nutzerentscheidung:** Zur Ermittlung der REAPER-Notationsmachbarkeit und zu einer eventuellen kleinen Implementierung darf kein Prozess mit Dutzenden manuellen Versuchen und immer neuen Testpaketen entstehen. Der Assistent organisiert Quellenanalyse, präzise Hypothesen und sichere automatisierte Offline-Pruefungen; der Nutzer soll nur fuer die wenigen unvermeidbaren Beobachtungen der **echten REAPER-Notationsoberflaeche** einbezogen werden.

**Vorgehensweise ohne neue Entwicklungsfreigabe:**
1. **Vollstaendige Vorarbeit vor einem Praxistest:** Dokumentierte ReaScript-Metadaten (`disp_len`, `voice`, `staff`), gebundene Anzeigeaktionen und konkrete Auswirkung auf einen klein gewaehlten Problemfall abgleichen. Proprietäre Implementierungsdetails von REAPER-Notator nicht kopieren; sein öffentlich beschriebenes Funktionsprinzip darf nur als Ausgangspunkt fuer eine unabhängige Architektur dienen.
2. **Offline-Checks selbst:** An vorhandener Test-MIDI mit Fallbeispielen für Tiny-Gaps, echte Pausen, Polyphonie, Triolen und Instrumentenzuordnung Verhaltensmodell/Regeln pruefen. Statische Lua-Prüfung, deterministische Unit-/Mocktests, Beweis dass Note-on/-off, Velocity, CC und Tempo unberührt bleiben. Diese Tests beweisen **nicht** die reale grafische Wirkung des eingebauten REAPER-Editors.
3. **Höchstens ein gebündelter erster Nutzer-Praxistest:** Ein vorbereitetes, unverändertes/gesichertes REAPER-Projekt und ein kurzer konkreter Vorher-/Nachhervergleich im nativen Notationseditor mit den vier Qualitaetsmerkmalen. Bei Bedarf nur **eine weitere gezielte Nachprüfung** fuer eine klar benannte Ungewissheit; keine offene Folge neuer Testversionen. Laufzeit-/Plattformtests können nicht allein aus Lua-Mocks als nachgewiesen bezeichnet werden.
4. **Stopregel:** Nach spätestens zwei gezielten fehlgeschlagenen realen Versuchen keine neue Paketserie; technische Grenzen anerkennen und vorhandene Alternativen empfehlen bzw. REAPER-API-Grenze dokumentieren. `main` und der letzte bestaetigte Stand bleiben unangetastet, bis Tests gelingen.

**Status:** Nur Prozess-/Qualitaetsentscheidung dokumentiert, keine Softwareaenderung, keine neue Version, kein REAPER-Echttest. Entwicklungsrichtung weiterhin: musikalische Analyse -> native REAPER-Notationseigenschaften, nie eigenes Notenfenster.


## 02.11.2026 – Sieben ReaTeam-Notationsskripte vollständig quellengeprueft, Wiederverwendungskonzept

**Benutzerauftrag:** Zunaechst recherchieren und eine belastbare Uebersicht erstellen, **welche Teile welcher bereits existierenden Entwicklungen** unsere vier Ziele im nativen REAPER-Noteneditor unterstuetzen und wo konkrete Modifikationen erforderlich waeren. **Keine neue Testversion und keine Softwareprogrammierung.**

**Neuer Recherchebericht:** [docs/REAPER-NATIVE-NOTATION-REUSE-AUDIT-2026-11-02.md](docs/REAPER-NATIVE-NOTATION-REUSE-AUDIT-2026-11-02.md), anhand der **Quelltexte aller sieben** `js_Notation`-Skripte unter `ReaTeam/ReaScripts/MIDI Editor/` inkl. Git-Blob-SHAs, REAPER-Handbuch 7.84 und `Notation Studio.lua` 0.1.24. Einzelne Skripte gelten nicht als nachweislich an der Nutzer-Orgel getestet.

**Prioritaeten:**
- **A / zentral:** `Set displayed length ... custom value` (Notationsmetadata `disp_len` als Delta gegen originale MIDI-Laenge, Reset vorhanden); `Select all notes that have customized display lengths or positions` (Audit von `disp_len`, `disp_pos`).
- **A/B / relevant:** `Set beaming ... custom rhythm` (manuelle rhythmische Balkengruppen, aktuelle Selection zurueckstellen und Takt-/Stimmenkontext beachten).
- **B / Diagnose:** `Select notes by notation keywords` (vorhandene Staff-/Voice-Metadaten, keine eigene Stimmtrennung).
- **C / redundant bzw. eingeschraenkt:** `Select notes by user-supplied notation text` (weitgehend alternative Variante, nutzt aeltere Take-Ermittlung); `Set display length ... double + staccato` und `... quadruple + staccatissimo` (fuer musikalisch echte kurze Artikulation, nicht fuer pauschale Orgel-Legato-Mikroluecken; ueberschreiben vorhandene Artikulation).
- **Keines der sieben** ersetzt REAPERs horizontalen Engravingalgorithmus oder erzeugt automatisch Instrumentenzeilen; hier sind nur native REAPER-Funktionen/Track-Profile relevant.
- Drei getrennte nutzbare Ansatzgebiete: native Darstellungsprofile, punktuelle `disp_len`-Korrektur mit Audit, optionale Beaming-Gliederung; dazu native Track-/Clef-Zuordnung. Der **fehlende, riskante Baustein** waere musikalische Erkennung unnoetiger Kurzpausen je Stimme.
- **Lizenzvorsicht:** Der gepruefte Upstream `ReaTeam/ReaScripts`-Root enthaelt keine globale LICENSE-Datei, in den sieben Script-Headern keine explizite Lizenz. Vor Quellcode-Copying/Weiterverteilung Rechte klaeren; unabhängige ReaPack-Installation oder eigene Implementierung nur anhand dokumentierter ReaScript-APIs als Zwischenweg.

**Urteil:** Begrenzte Verbesserung des eingebauten Editors ist plausibel, **nicht bewiesen fuer alle vier Ziele zusammen**. Der bestehende Problemfall muss mit einem einzigen reversiblen `disp_len`-Eingriff die Wirkung im **echten** REAPER nachweisen, bevor automatisierte Pausenbearbeitung sinnvoll ist. Kein neues Fenster, kein Notator-Nachbau. Projektcode, Nutzer-MIDI und aktive App unveraendert; nur Dokumentation geaendert.


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
