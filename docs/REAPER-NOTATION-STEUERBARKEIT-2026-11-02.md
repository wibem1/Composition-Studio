# REAPER-Notationsengine: belegte Steuergrenzen und Schnittstellen

**Datum:** 2026-11-02  
**Ziel:** Vor einer musikalischen MIDI-Vorinterpretation die *tatsächlich ansprechbaren* Funktionen der **eingebauten REAPER-Notation** abgrenzen.  
**Status:** Dokumentations- und Projektcode-Audit, kein neu durchgeführter realer REAPER-Oberflächenversuch. REAPERs **interner Layoutalgorithmus ist nicht als offene API dokumentiert**; daher kein vollständiges internes Funktionswissen behaupten.

## Quellen und Reichweite

1. Cockos/Geoffrey Francis, **[REAPER User Guide v7.84, Kapitel 14.5–14.9](https://dlx.reaper.fm/userguide/html/)**, insbesondere Seite 283–295.
2. Cockos, **[ReaScript API Functions, erzeugt aus REAPER v7.83](https://www.reaper.fm/sdk/reascript/reascripthelp)**: `MIDIEditor_GetActive`, `MIDIEditor_OnCommand`, `MIDIEditor_EnumTakes`, `MIDIEditor_GetSetting_int`, `MIDIEditor_SetSetting_int`, `MIDI_InsertTextSysexEvt`, `MIDI_SetTextSysexEvt`, `MIDI_GetAllEvts`, `MIDI_RefreshEditors`.
3. ReaTeam / juliansader: [`js_Notation - Set displayed length of selected notes to custom value.lua`](https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Set%20displayed%20length%20of%20selected%20notes%20to%20custom%20value.lua) (v2.3); [`js_Notation - Select notes by notation keywords.lua`](https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Select%20notes%20by%20notation%20keywords.lua); [`js_Notation - Set beaming of selected notes to custom rhythm.lua`](https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Notation%20-%20Set%20beaming%20of%20selected%20notes%20to%20custom%20rhythm.lua).
4. Eigener Projektcode `Notation Studio.lua` v0.1.24, Commit/Blob `48274e5767c8d756543bf7fa3a0b9108b639a272`.

Drei **verschiedene Nachweisstufen** nicht verwechseln: (1) Benutzeroberfläche/Handbuch bietet Funktion, (2) ReaScript API/Aktionen können sie *programmatisch* ansteuern und ggf. ihren Status lesen, (3) die native Engine setzt die Kombination auf konkreter Partitur **grafisch korrekt** um. Nur #1 und Teilbereiche von #2 sind nachweisbar, #3 braucht eine echte REAPER-Ansicht.

## Steuerbarkeitsmatrix

| Eigenschaft | REAPER-Funktion / Art des Zugriffs | ReaScript tatsächlich belegt | Begrenzung / offene Frage |
| --- | --- | --- | --- |
| Anzeigequantisierung und Mindestnotenlänge | `Display quantization`, `Minimum note length` (auch **pro Track** oder Projekt); nur Anzeige, keine MIDI-Events | Steuerung über MIDI-Editor-Aktionen/Dialog grundsätzlich erreichbar mit `MIDIEditor_OnCommand`; `MIDIEditor_SetSetting_int` **unterstützt diese beiden Werte nicht als dokumentierte Settings** | Vollständige, verlässliche *programmatische* Set/Get-Prüfung pro Track nicht belegt; unser Skript ruft angeblich konkrete Aktionstitel auf, was in tatsächlicher Installation nachzuweisen ist |
| Note: angezeigte Dauer | `Display offset`, unabhängig von echter Dauer | MIDI-Notationstext **Typ 15** per `MIDI_InsertTextSysexEvt`/`MIDI_SetTextSysexEvt`; beobachtetes `NOTE channel pitch disp_len <delta>` als **Delta in Viertelnoten** (juliansader v2.3) | Text-Token-Semantik ist überwiegend durch Community-Skript, **nicht als vollständig stabilisiertes Cockos-Format** spezifiziert; verändert Notations-Events im MIDI-Take, nicht Note-on/off |
| Note: angezeigter Einsatz | `Display offset` position links/rechts | Community-Nachweis `disp_pos`, analog Notationstext; manuelle Aktionen | Exakte Semantik/erlaubte Werte und Interaktion mit Quantisierung noch nicht in REAPER 7.83 nachgewiesen; kein allgemeiner Layoutpositionswert |
| Stimme (hoch/tief) | `Voice`: Default/High/Low; `Automatically voice overlapping notes` | Community-Notationstext `voice 1` usw. plus Editor-Aktionen, Auswahl via `MIDI_EnumSelNotes`; Syntaxbeispiel `NOTE 0 64 staff 1 voice 1` | Praktisch **höchstens Standard/High/Low im dokumentierten Editor**, nicht beliebig viele unabhängige grafische Stimmen per staff. Musikalische Stimmenerkennung selbst ist **keine REAPER-Schnittstelle** |
| Balkengruppen und Bindungen | `Beam notes together`, `Do not beam notes`, `Default beaming`, `Minimize ties` | Vorhandene MIDI-Editor-Aktionen über `MIDIEditor_OnCommand`; juliansader v2.1 zeigt gruppenbezogene Selektion | Nur über Auswahl/REAPERs interne Balkenentscheidung; nicht das gesamte Beam-/Tie-Layout kontrollierbar |
| Triolen | `Automatically detect triplets` (Anzeige); manuelles `Create/Edit Tuplet` | Auto-Erkennung per MIDI-Editor-Aktion möglich; manuelle Tuplet-Aktionen über GUI/Aktionen | **WICHTIG: Handbuch 7.84 S. 290 sagt, dass manuell angelegte Tuplets Original-MIDI-Positionen und -Längen ändern können**. Nichtdestruktive Pipeline darf dies nicht still ausführen |
| Instrument, Schlüssel, Notenzeile | REAPER-MIDI-Tracks/Items, `Contents > Track list`, Default clef (Treble/Bass/Alto/Tenor etc.), clef change im Takt, `Transpose display` | REAPER Track-/Item-/Take-API, `MIDIEditor_EnumTakes`; Schlüssel im GUI direkt belegbar; `SCORE`-Track-State-Chunk im bisherigen Skript ist **undokumentierter Eingriff** | Kein nachgewiesener, sauber dokumentierter `SetDefaultClef(track,clef)`-API-Aufruf; für verlässliche Automatisierung Aktion/gezielten Track-State-Zugriff erst isoliert validieren; mehrere Tracks erzwingen kontinuierliche horizontale Ansicht |
| Horizontale Notenabstände | `Proportional (musical) note spacing`; Zoom/Scroll | Editor-Aktion; **dokumentierte** `MIDIEditor_SetSetting_int(editor,"pixels_per_timebase_unit",value)` für Skalierung (value = 1024 × pixels/timebase unit); Status via Getter / Toggle ggf. auslesbar | **Keine dokumentierte API**, um für einzelne Notenköpfe, Vorzeichen, Pausen, Takte oder Balken exakte X-Koordinaten, Kollisionsabstände oder Breiten vorzugeben. Interner Engravingalgorithmus bleibt unverändert |
| Pausen | Vom Notationsalgorithmus aus rhythmischer Belegung erzeugt, Displayquantisierung beeinflusst Ergebnis | Noten-Anzeigezeitpunkte/`disp_len` und Stimmenzuordnung beeinflussen *indirekt* die erwarteten Pausen | **Keine im Handbuch/API belegte direkte Funktion „diese grafische Pause löschen/unterdrücken“**, ohne realen Rhythmus zu ändern. Bei Polyphonie/echten Pausen besonders ungewiss |
| Grafisches Rendering / Seitenlayout | REAPER zeichnet selbst; bei mehreren Tracks nur kontinuierliche Ansicht | Keine dokumentierte Notensatz-Callback-/Render-API | Keine direkte Kontrolle der Notehead-/Accidental-Kollisionen, automatischer Systemumbrüche bei mehrspurigem Notensatz, Positionierung von Pausenzeichen oder Beam-Winkel |

## Präzise Grenzen unseres Skripts 0.1.24

- `cleanup_notation()` kombiniert proportional spacing, Quantisierung 1/16, Mindestlänge 1/64, Triolenerkennung, Stimmenautomatik, Schlüssel, Skalen-/Zoom. Das ist **keine** musikalische Analyse oder kontrollierte Pipeline.
- `find_action_variants()` scannt REAPER MIDI-Aktionen über lokalisierungs-/versionsabhängige Textfragmente; verwechselt möglicherweise ähnlich benannte Aktionen. `MIDIEditor_OnCommand` bestätigt nur, ob der Editor-Zeiger gültig ist, **nicht** dass die resultierende Notation schön/richtig ist.
- `spacing_state()` meldet auch bei unbekanntem Toggle-Zustand (`-1`) `false` statt „unbekannt“. Für Zuverlässigkeit müssen unbestimmte Zustände als **unbekannt** gelten.
- `set_default_clef_chunk()` ersetzt eine `SCORE ...`-Zeile über `GetTrackStateChunk`/`SetTrackStateChunk`, ohne öffentlich dokumentierte Schemasicherheit, und fasst nur den aktiven Track an. **Keine generelle Freigabe dieser Methode.**
- `apply_readable_scale()` setzt dokumentiertes `pixels_per_timebase_unit` aus Notendichte, kann den **internen** proportionalen Spacing-/Collision-Algorithmus aber nicht beeinflussen.
- `selected_track_profile()` wählt gelegentlich Schlüssel anhand der aktuell *selektierten* Notenhöhen; Instrumentennamen/MIDI-Spuren sind für feste Instrumentensysteme verlässlicher als eine Selection-Heuristik.
- Das Handbuch erlaubt Displayquantisierung *pro Track*, aber die `MIDIEditor_SetSetting_int`-API bietet **keinen entsprechenden dokumentierten Setter**. Per-Track-Automatik ist daher weiter ein **Implementierungsrisiko**, nicht schon „gelöst“.

## Konsequenz für die Vorinterpretation

**Eingang:** Original-MIDI (MIDI-Events unverändert) + Taktart/Instrument-Spuren.  
**Unabhängige Analyse:** rhythmische Interpretation und Zuordnung von Onsets, Notenlängen, Staffs und Stimmen, wobei echte/unechte Pausen unterschieden werden; bei Zweifeln nichts automatisch umschreiben.  
**Ausgabe:** nur solche Steuersignale, die REAPER tatsächlich annimmt: globale/pro-Track-Anzeigeoptionen; gezielte und rücksetzbare `disp_len`/`disp_pos`-Notationsmetadaten; dokumentierte Stimmen-/Balken-Aktionen; Instrumentenspur/Schlüssel.  
**Nicht möglich als direkte Ausgabe:** „Pause #12 ausblenden“, „Notenkopf 4 mm nach rechts“, „schaffe selbstständige Systemumbrüche für 3 Tracks“.

Damit ist das Konzept **ein Kandidat**, aber nicht „vorab bestätigt“. Drei harte Gates vor einem Produkt: (G1) eindeutiger, nichtdestruktiver `disp_len`-Effekt im nativen Editor auf den künstlichen Lücken (Test-MIDI Takte 3/4 vs. 1/2); (G2) echte Pausen (5/6), Triolen (7), polyphone Stimmen (8) unverändert musikalisch korrekt; (G3) Abstände/Systeme weiterhin brauchbar – falls interne Layoutqualität unzureichend, nicht durch unbegrenzten Eigenbau weiter eskalieren.

**Nächster Schritt:** Noch *keine* neue Version/Testschleife. Zuerst die prozeduralen Aktionen und die REAPER-spezifischen Notations-Token für ein einziges vorbereitendes **minimal-invasives** Skript festlegen; die GUI-Wirkung wird dann in höchstens einem gebündelten Nutzer-Praxistest (plus ggf. einer gezielten Nachprüfung) entschieden.

**Lizenz:** Hier wird **kein Code aus REAPER-Notator** übernommen; dessen aktuelle LICENSE ist proprietär. Die obige Analyse stützt sich auf Cockos-Dokumentation und independently available ReaTeam-Skripte.
