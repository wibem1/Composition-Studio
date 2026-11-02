# Recherche & Wiederverwendung: REAPER-native Notenlesbarkeit

**Datum:** 02.11.2026  
**Projekt:** Composition-Studio / Notation Studio 0.1.24 (\`main\`)  
**Status:** Quellcode- und Dokumentationsprüfung. **Keine Implementierung, kein aktueller REAPER-Echttest und keine Freigabe.**

## Entscheidungsrahmen

Es bleibt bei der **eingebauten REAPER-Notationsansicht**. Keine Eigenentwicklung einer Notensatzengine und kein Nachbau von REAPER-Notator. Die schon erfolglose Sammelfunktion \`Lesbarkeit verbessern\` wird nicht erneut unverändert probiert.

**Vier verbindliche Ziele:** (1) musikalisch sinnvollere horizontale Abstände, (2) keine *künstlichen* Minipausen, echte Pausen bleiben, (3) Displayquantisierung ohne Änderung der Note-on/-off-Events, (4) getrennte Instrumentalzeilen mit geeigneten Schlüsseln.

Quellen:
- Offizielles [REAPER-Handbuch 7.84](https://dlx.reaper.fm/userguide/html/), Kapitel 14.5–14.7 (Abstände, Displayquantisierung, Minimum note length, Stimmen, Schlüssel, Multi-Track-Ansicht).
- [ReaTeam/ReaScripts / MIDI Editor](https://github.com/ReaTeam/ReaScripts/tree/master/MIDI%20Editor), sieben gezielt geprüfte \`js_Notation\`-Dateien (Autor juliansader). Die Dateinamen, Skriptversionen und Blob-SHAs folgen unten. Diese Blob-SHAs sind Quellreferenzen, keine Git-Commits der eigenen Anwendung.
- Eigene Datei [Notation Studio.lua](../Notation%20Studio.lua) v0.1.24 (\`main\`): \`cleanup_notation()\`, \`set_default_clef_chunk()\`, \`set_musical_spacing()\`, \`apply_readable_scale()\`.

## 1. Vergleich sämtlicher sieben ReaTeam-Skripte

| Nr. | Skript (jeweils unter \`MIDI Editor/\`) | Fundstelle / SHA | Technische Wirkung | Übernahme / nötige Änderung | Gewichtung |
| --- | --- | --- | --- | --- | --- |
| 1 | \`js_Notation - Set displayed length of selected notes to custom value.lua\` v2.3 | [Quelle](https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Set%20displayed%20length%20of%20selected%20notes%20to%20custom%20value.lua), \`c6e9bf8c9748886af6d545aefcc2609bcbf5296f\` | Für ausgewählte Noten wird in REAPERs Text-/Notationsevent Typ 15 \`disp_len\` gesetzt. **Wert ist ein Offset gegenüber der MIDI-Notenlänge**, normiert auf Viertelnoten; leere Eingabe entfernt den Wert wieder. Note-on/-off-Zeitpunkte werden nicht geschrieben. | **Zentraler Kandidat.** Keine pauschale benutzerdefinierte Länge für alle Noten; künftig nur nach Prüfung je Stimme/Situation einen *Ziel-Anzeigewert* bestimmen, Offset korrekt aus Originaldauer ableiten; alte andere Metadaten erhalten; Änderung dokumentieren und einzeln/rücksetzbar machen. Skript arbeitet mit Popup und allen editierbaren Takes – für unseren Editor braucht es sichere Zielauswahl und nichtinteraktiven Aufruf. | **A** |
| 2 | \`js_Notation - Select all notes that have customized display lengths or positions.lua\` v3.10 | [Quelle](https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Select%20all%20notes%20that%20have%20customized%20display%20lengths%20or%20positions.lua), \`57f9efdb744a8a79570315f3b6feb295cbacd4b5\` | Liest rohe MIDI-/Notationsevents, findet \`disp_len\` und \`disp_pos\`, **selektiert** passende Noten über veränderte Selection-Flags mit \`MIDI_SetAllEvts\`. | **Übernehmen als Audit-Prinzip**, vorzugsweise lesender Bericht mit Marker/Takt/Spur, Vorher-/Nachherwert und Reset. Originalskript kann direkt als manueller Kontrollschritt genutzt werden; für automatische Berichte nicht ungefragt Note-Selections ändern. | **A** |
| 3 | \`js_Notation - Set beaming of selected notes to custom rhythm.lua\` v2.1 | [Quelle](https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Set%20beaming%20of%20selected%20notes%20to%20custom%20rhythm.lua), \`8407214913c5be89729400b7f6865b8ea752015a\` | Erzeugt eigene rhythmische Balkengruppen, z. B. **3+3+2**, toleriert leicht zu frühe Einsätze mit gridabhängigem Spielraum. Verwendet \`MIDI_SelectAll\`/\`MIDI_SetNote\` auf Selection-Flags sowie REAPER-Aktionen 41045 (Beam notes together), 41749 (Minimize ties). | **Als separate optionale Satzkorrektur nutzen**. Für unsere Zwecke: musikalisches Takt-/Gruppenschema statt starrem 3+3+2, Auswahl auf einen klaren Track/Abschnitt und ggf. Stimme begrenzen, Auswahl vorher sichern und nachher vollständig wiederherstellen; Aktionen dynamisch nach Namen/Version prüfen, nicht blind harte IDs übernehmen. Keine Auswirkung auf globalen Spacingalgorithmus. | **A/B** |
| 4 | \`js_Notation - Select notes by notation keywords.lua\` v1.03 | [Quelle](https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Select%20notes%20by%20notation%20keywords.lua), \`7025418610f3da4dc49c42570e0d08bd65602582\` | Durchsucht Notationstext nach \`staff\`, \`voice\`, \`beam\` etc., selektiert zugehörige Noten; wirkt **nur auf den aktiven Take**. Ruft \`JS_Window_SetFocus\` auf (zusätzliche js_ReaScriptAPI-Abhängigkeit). | Nicht als Automatik zur Stimmerkennung missverstehen: Erfasst **bereits gespeicherte** Zuordnungen. Nützlich als **Diagnose**, um vorhandene Voice-/Staff-Metadaten sichtbar zu machen; Auswahl optional. Eigenständige Datenabfrage ohne Popup/JS-Fokusabhängigkeit wäre sicherer. | **B** |
| 5 | \`js_Notation - Select notes by user-supplied notation text.lua\` v2.0 | [Quelle](https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Select%20notes%20by%20user-supplied%20notation%20text.lua), \`9cc7ef96fd8d81672d96623548353ecb70908887\` | Funktional weitgehend wie Nr. 4, aber Auswertung **aller editierbaren Takes**. Ermittelt Takes noch über einen Eingriff in globale Zeit-/Notenauswahl (\`GetSet_LoopTimeRange2\`, \`MIDIEditor_LastFocused_OnCommand\`), setzt Selection-Flags mit \`MIDI_SetAllEvts\`, benötigt \`JS_Window_SetFocus\`. | **Nicht parallel übernehmen**. Allenfalls die Mehrspur-Idee übernehmen: zielgerichtete Auflistung über neuere \`MIDIEditor_EnumTakes\` und read-only Metadatenabfrage, ohne Zeitselektionstrick, Fokus-Zwang und ungefragte Selection-Modifikation. | **C** |
| 6 | \`js_Notation - Set display length of selected notes to double and add staccato articulation.lua\` v2.1 | [Quelle](https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Set%20display%20length%20of%20selected%20notes%20to%20double%20and%20add%20staccato%20articulation.lua), \`82bdc32cb0c06f817ce9ebeb0b6c76c66ceb5cb5\` | Notierte Länge 2× MIDI-Länge und **Staccatozeichen** zur Erklärung der kürzeren realen Dauer. Hilfreich bei absichtlich kurz klingenden Noten. Entfernt/ersetzt vorhandene \`articulation\`-/\`disp_len\`-Felder. | **Nicht als globale Minipausenautomatik einsetzen** (für legato Orgel/Violine musikalisch falsch); nur ausdrücklich gewünschter Staccato-Notationsmodus. Würde bei einer Integration Bestandsartikulationen bewahren oder Änderung sichtbar bestätigen müssen. | **C** |
| 7 | \`js_Notation - Set display length of selected notes to quadruple and add staccatissimo articulation.lua\` v2.1 | [Quelle](https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Set%20display%20length%20of%20selected%20notes%20to%20quadruple%20and%20add%20staccatissimo%20articulation.lua), \`09e938c7fce545979336a1f0790373a535e20897\` | Entsprechend 4× MIDI-Länge und Staccatissimo; überschreibt vorhandene Artikulationsangaben. | **Vorläufig nicht integrieren**; kein Beitrag zum allgemeinen Problem minimaler MIDI-Notenlücken. Allenfalls später manuelle Spezialnotation. | **C** |

**Ergebnis:** Drei direkt verwertbare Ansätze (#1, #2, #3), ein ergänzender Diagnoseansatz (#4), ein nahezu redundantes Verfahren (#5), zwei **musikalisch eng begrenzte** Spezialfunktionen (#6, #7). **Keines** implementiert automatische Stimmtrennung, intelligente Entscheidung über echte vs. künstliche Pausen oder einen neuen horizontalen Notensatzalgorithmus.

## 2. Zuordnung zu unseren vier Zielen

### Ziel 1 – Musikalisch sinnvolle Notenabstände

**Vorhanden:** REAPERs eigene Option \`Proportional (musical) note spacing\`, horizontale/vertikale Skalierung; bereits von \`Notation Studio.lua\` v0.1.24 ansteuerbar. REAPERs proportionaler Modus verteilt kurze und lange Noten bewusst anders als eine gleichmäßig zeitproportionale Pianorolle (offizielles Handbuch 14.5).

**Von den sieben übernehmen:** Kein Skript steuert den internen optischen Algorithmus. Das Beaming-Skript #3 verbessert rhythmische *Gliederung*, aber nicht die wirklichen Kollisionsabstände.

**Modifikation:** Bestehende Skalierung und Zoomsteuerung nach messbarer Notendichte / verfügbarem Fensterplatz anbieten, nicht ungezielt mehrere Zoomaktionen kombinieren. Manuelle Option für dichte Passagen. *Grenze:* Verschachtelte Akkorde/Vorzeichen/Engraving-Kollisionen bleiben REAPER-intern; derzeit **kein belegter REAPER-API-Hook**, um diese Verteilung beliebig zu berechnen.

**Einschätzung:** *Begrenzt machbar*, nicht durch ReaTeam alleine lösbar.

### Ziel 2 – Keine unsinnigen Minipausen (kritische Anforderung)

**Vorhanden:** REAPER \`Display quantization\` und \`Minimum note length\`; das **Custom-display-length-Verfahren #1** erlaubt einzelne Abweichungen vom tatsächlichen MIDI, ohne Note-on/-off zu verschieben. #2 erkennt die eingetragenen Korrekturen. **Staccato #6/#7 ausdrücklich nicht als Standardersatz**: Es sind interpretatorische Anweisungen, die bei einem Legato-Manual falsch wären.

**Fehlender Teil = musikalische Entscheidung:**
- Kandidat ist eine kurze *rechnerische* Lücke zwischen Ende einer Note und nächstem musikalischem Anschluss **derselben Stimme**.
- Vergleich nicht nur nach nächstem beliebigen MIDI-Onset: Chord, legato overlap, Stimmwechsel, echte Achtel-/Viertelpause, Beginn/Ende einer Phrase, Pause zwischen Takten, Repetitionen und Triolen unterscheiden.
- Kleinste absolute Note-Off-Mikrolücken (z. B. ein Tick) sind starke Kandidaten, aber **kein automatischer Löschbeweis**.
- Bisherige Analysen zeigen an der Orgelphantasie zahlreiche 1-Tick-Mikrolücken und mehrere echte spurspezifische Stille-Abschnitte. **Musikalische Stimme ist nicht MIDI-Kanal und auch nicht automatisch Track**.
- Nach Prüfung angezeigte Endzeit maximal bis zum sachlich gerechtfertigten Raster-/Folgeonset verlängern, wobei **bestehende Notationsmetadaten unverändert bleiben**, sofern nicht explizit mit der betreffenden Eigenschaft geändert wird.
- Jede Korrektur mit Originalwert und Zielwert protokollieren; pro Note rücksetzbar, vollständige Undo/Redo-Kette. Eine nachvollziehbare Änderung am MIDI-Notationstext ist **nicht** eine Änderung der MIDI-Wiedergabe.
- Technische Übernahme: \`disp_len\` als **Offset zur echten Notenlänge in Viertelnoten** setzen; im alten Skript werden nur drei Dezimalstellen geschrieben. Für hohe PPQ-/Triolenpräzision neu prüfen, ob mehr Genauigkeit sicher verarbeitet wird. Ambivalente Fälle in der Vorschau/Diagnose stehen lassen, **nicht automatisch glätten**.

**Einschätzung:** *Plausibel für eindeutig unnötige Mikro-Pausen; ungeklärt bei polyphonen, überlappenden Stimmen.* Dieser Punkt bestimmt die Machbarkeit des Projekts.

### Ziel 3 – Displayquantisierung ohne Änderung der Wiedergabe

**Vorhanden:** Vollständige REAPER-Bordfunktion \`Display quantization\` und \`Minimum note length\` pro Track; offizielle Dokumentation stellt ausdrücklich klar, dass sie **keine MIDI-Noten verschiebt**. REAPER unterstützt auch automatische Triolenerkennung.

**Von den sieben übernehmen:** **Keines** quantisiert die Darstellung global besser als REAPER. #1 ist eine **gezielte Ausnahme** für einzelne Noten, nicht ein Ersatz für die native Quantisierung.

**Modifikation:** \`Notation Studio\` stellt überprüfbare instrument-/spurbezogene Anzeigepresets und Status/Reset bereit, nicht pauschal 1/16+1/64 für alles. Default-Beispiele erst nach musikalischem Profil und korrekter Taktart wählen, Triolen niemals durch ungeeignetes Raster zerstören. REAPER eigene Optionen zentral ansteuern, nicht MIDI-Events quantisieren.

**Einschätzung:** *API-/Funktionsseitig gut machbar, musikalische Wahl individuell; schon teilweise umgesetzt.*

### Ziel 4 – Jedes Instrument in eigener Notenzeile, geeigneter Schlüssel

**Vorhanden:** Mehrere MIDI-Tracks in einem REAPER MIDI-Editor, eigene \`Default clef\`-Optionen (Treble, Bass, Alto, Tenor, Treble + Bass usw.), transponierte **Anzeige** ohne MIDI-Änderung. Das Handbuch legt eine wesentliche Grenze fest: Bei mehreren gleichzeitig angezeigten Tracks gibt es nur die **durchlaufende horizontale Notationsansicht**, nicht den mehrzeilig umgebrochenen Partiturseitenmodus.

**Von den sieben übernehmen:** #4/#5 dienen nur der Prüfung bereits bestehender \`staff\`-/\`voice\`-Informationen, nicht dem Anlegen eigener Instrumentalzeilen.

**Modifikation:** Instrumentenzuordnung aus **REAPER-Tracks** und expliziten Nutzerangaben, nicht aus bloßer Höhe einer Note (die beiden Orgelmanuale heißen beide „Church Organ“). Für Beispiel Orgel: getrennte Items/Tracks Manual I, Manual II, Pedal; passende Standardschlüssel je Track durch reguläre REAPER-Aktionen/Kontextmenü. Kein ungeprüftes \`SCORE\`-Chunk-Replacement aus bisherigem \`cleanup_notation()\`, keine unerbetene Vereinigung aller MIDI-Spuren.

**Einschätzung:** *Funktional möglich, Layoutgrenze bei Mehrspurpartituren bleibt.* Nutzerwunsch „Arbeitsnotation“ könnte Continuous View akzeptieren, nicht aber automatisch A4-Druckpartitur.

## 3. Was würden wir konkret entwickeln – nur wenn die Machbarkeit nachgewiesen ist?

Keine zweite Anwendung. Maximal vier logisch getrennte, kleine Bausteine in der **bestehenden** Notation-Studio-REAPER-Steuerung:

| Baustein | Basis | Aufgabe | Unbedingt vermeiden |
| --- | --- | --- | --- |
| **A. Darstellungsprofile** | REAPER native Aktionen / eigenes 0.1.24 | Status-/Presetsteuerung für musikalische Abstände, 1/8–1/64, Mindestlänge, Triole, Zoom; je Instrument/Track | Globale pauschale Umschaltung aller Optionen |
| **B. Pausenprüfung & optionale Korrektur** | ReaTeam #1 + #2 als **technisches Vorbild** | Tiny-gap-Kandidaten/Notationsmetadaten lesen, in Stimmen-Kontext bewerten, einzelne \`disp_len\`-Änderung vorschlagen und rücksetzbar ausführen | Blindes Dehnen aller Noten, Staccato-Vortäuschung, Änderungen an Note-off |
| **C. Rhythmen/Balken** | ReaTeam #3 / native REAPER-Aktion | Auf bestätigten Gruppen gewünschtes Balkenschema setzen, ggf. Ties minimieren | Hardcoded 3+3+2 für ganze Partitur oder Verändern der ursprünglichen Auswahl |
| **D. Instrumente und Zeilen** | REAPER Track-Liste/Default clef, #4 als Diagnoseidee | Sichtbarkeit der Instrumentenspuren und passende Schlüssel steuern, Stimmenzuordnung anzeigen | Automatische willkürliche Notenschlüssel, \`SCORE\`-Chunk-Hack |

**Architektur:** Die vier Module steuern ausschließlich die **native REAPER-Notation** und deren Metadaten. Keine ReaImGui-Neurender-Engine. B und C sind **optionale Notationskorrekturen**, keine verpflichtende globale Ausführung. Bei unbekanntem Stimmenkontext: **Vorschlag statt automatische Änderung**.

## 4. Sicherheits- und Integrationsbedingungen

1. **Keine unerwarteten MIDI-Ereignisänderungen:** Erlaubt sind REAPER-Anzeigeoptionen und nach Bestätigung einzelne Text-Events zur Notation (\`NOTE ... disp_len\`, \`staff\`, \`voice\`, Beaming). **Nicht** erlaubt ohne gesonderten Auftrag: Note-on, Note-off, Pitch, Velocity, ursprüngliche CC-/Pedal-Events, Tempo-/Taktart-Events umschreiben. Bei Vergleich Note-on/-off und CCs byte-/semantikgleich halten; Selection-Flags sind nicht semantische Notenänderungen, sollten dennoch erhalten bleiben.
2. **Transaktion, Anzeige, Reset:** Vorherigen Notationszustand sichern; Änderung markieren; per REAPER-Undo, pro Note und gesamter Auswahl umkehrbar. Bestehende Artikulationen, \`staff\`, \`voice\`, \`disp_pos\`, andere NOTATION-Tokens nicht löschen. Die vorliegenden #6/#7 tun das hinsichtlich Artikulationen teilweise explizit und sind daher als globale Skripte **ungeeignet**.
3. **Keine falschen Abkürzungen beim Lesen:** #2 und #4/#5 ändern Selection-Flags via \`MIDI_SetAllEvts\`; #3 setzt Selektion via \`MIDI_SetNote\`; #5 verändert zusätzlich vorübergehend die Time Selection. Diese Vorbilder nicht für eine **read-only-Diagnose** einfach unverändert ausführen.
4. **Lizenz-/Übernahmeprüfung:** Das öffentliche \`ReaTeam/ReaScripts\`-Root enthält **keine allgemeine LICENSE-Datei**; die sieben untersuchten Skript-Header enthalten keine ausdrückliche Lizenzangabe. Öffentliche Einsehbarkeit allein gestattet **nicht automatisch** das Kopieren oder Weiterveröffentlichen von Drittquellcode. Vor Vendor-/Codeübernahme Nutzungsrechte/Erlaubnis für die konkreten Skripte klären. Bis dahin: unveränderte Originalskripte unabhängig per **ReaPack** beim Nutzer installieren oder die durch REAPER dokumentierten APIs und allgemein beschriebenen Verfahren **eigenständig implementieren**, ohne fremde Codeabschnitte zu kopieren. ReaPack-Quelle: \`https://github.com/ReaTeam/ReaScripts/raw/master/index.xml\`; nicht mit GPL-ReaperNotator-Code vermischen.
5. **Reale Engine zuerst:** GitHub-Lua-Mocktests beweisen keine grafische Wirkung in REAPER. Vor Implementation auf höchstens **einem** problematischen 4-Takt-Ausschnitt nachvollziehen, ob ein *einzelner* gezielter \`disp_len\`-Eingriff die fragliche Pause in der nativen REAPER-Partitur wirklich beseitigt. **Danach Go/No-Go** zur Pausenautomatik. Ein zweiter Auszug prüft die Mehrspur-/Schlüsselsituation. Kein monatelanger Variantenbau.
6. **Trennung: REAPER-Notator:** Separate bestehende Notensatzengine als **Alternative/Referenz**, nicht als Pflichtquelle für Nachbau. Nicht mit den sieben ReaTeam-\`js_Notation\`-Skripten verwechseln.

## 5. Bewertung für die Entscheidung

**Sofort nutzbar ohne neue Engine:** REAPERs eigene Darstellungsprofile und getrennte Instrumentalzeilen; ReaTeam #1 manuell für gezielte \`disp_len\`-Korrektur, #2 als Kontrolle, #3 für ausgewählte rhythmische Balkengruppen. Die meisten anderen Skripte sind nur Diagnose/Einzelfall.

**Technisch fehlend:** belastbare *musikalische* Unterscheidung echter Pausen von Mikro-Lücken innerhalb einer polyphonen Stimme; ein frei steuerbarer Notensatzabstandsalgorithmus; mehrzeilige Seitenpartitur gleichzeitig für mehrere Tracks innerhalb REAPERs nativer Ansicht. Einsetzbare, bereits fertige REAPER-Erweiterung, die genau diese drei Lücken in **dieser nativen** Ansicht vollständig schließt, ist aus der sieben-Skript-Auditierung **nicht nachgewiesen**.

**Empfehlung:** Nur den minimalen, reversiblen \`disp_len\`-Machbarkeitsnachweis und die vorhandenen Staff-Funktionen als Gate betrachten. Wenn der **konkrete** Problemfall trotz Anzeige-Offset nicht besser wird oder REAPER trotz kleiner, klarer Änderungen weiterhin falsche Pausen/Stimmen zeichnet, kein komplexes Automatikmodul entwickeln. Dann ggf. REAPER-Notator als bereits bestehende Alternative verwenden. Nicht vorher erneut ein eigenes ReaImGui-Notenfenster entwickeln.

## Quellenstand / Nachweise

GitHub-Quellen selbst eingesehen am 02.11.2026 (jeweils die sieben unveränderten Upstream-Skripte mit den obigen SHA-Prüfwerten). REAPER-Handbuch 7.84 geöffnet. Eigener bestehender \`Notation Studio.lua\` v0.1.24 auf \`main\` quellengeprüft. **Kein neues REAPER-Instrumententestprotokoll; keine Aussage, dass ein bestimmtes Script einen realen Orgel-Notationsfehler bereits behoben hätte.**
