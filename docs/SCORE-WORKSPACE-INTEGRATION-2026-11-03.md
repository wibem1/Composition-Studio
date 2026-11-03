# Composition Studio – Notationseditor als zweiter Kompositionsarbeitsbereich

**03.11.2026 · Entwicklungszweig `feat/score-workspace-bridge-20261103` · Draft-PR #9 · kein Release**

## Konzept
REAPERs Arrangement und seine native Notenansicht sind **gleichwertige Arbeitsorte** auf demselben MIDI-Projekt. Composition Studio bleibt die einzige KI-/Auftragsebene. MIDI-Items, Instrumentalspuren und ausgesuchte Noten sind keine getrennten Kopien, sondern verschiedene Ansichten derselben REAPER-Daten. Es wird kein eigener Notensatzeditor programmiert und es gibt keine zweite Composition-Studio-Palette.

### Drei klar getrennte Scopes
1. **Arrangement-Auswahl:** Markierte MIDI-Items/Tracks mit schon vorhandenem Composition-Studio-Workflow. Keine Verhaltensänderung für gewöhnliche Aufträge ohne Partiturbezug.
2. **Einzelnoten-Auswahl:** Die in einem editierbaren MIDI-Take explizit markierten Noten, unabhängig von Arrangement-Item-Auswahl. Das ist der Scope aus Version 1.1.7 für gezielte Analyse, transponieren und begrenzte KI-Tonhöhen-/Velocityänderungen. Die tatsächliche Live-Funktion in REAPER ist noch nicht bestätigt.
3. **Sichtbare Partitur:** Alle im zuletzt fokussierten, weiterhin geöffneten MIDI-Editor **sichtbaren** MIDI-Takes, inklusive nicht editierbarer Referenzspuren, als **ausschließlich musikalischer Kontext**. Die Auswahl einzelner Noten wird durch diesen Scope nicht verändert, und Sichtbarkeit ist **keine Schreibfreigabe**. Bei `>2500` MIDI-Noten wird der Auftrag zurückgewiesen statt verschwiegen gekürzt.

Der Scope für einen Auftrag wird bei dessen Start bestimmt. Die ausdrückliche Anweisung „markierte/ausgewählte Noten“ hat Vorrang vor „Partitur“, damit eine einzelne markierte Melodie nicht versehentlich durch die ganze Partitur ersetzt wird.

## Implementierte Bedienung im Entwicklungskandidaten
**Vorhandenes Composition-Studio-Auftragsfeld:**
- `Zeige die Partitur` bzw. `Notenansicht vorbereiten`: vorhandenen Noteneditor nutzen oder die ausgewählten MIDI-Items per nativer REAPER-Aktion `40153` öffnen; einen MIDI-Aktionsbefehl für den Notationsmodus nutzen, **falls vorhanden und identifizierbar**, danach das bisherige separat registrierte Skript `REAPER Notation - 4 Takte und Instrumentenschluessel.lua` über REAPERs MIDI-Aktionsliste ausführen.
- `Analysiere die sichtbare Partitur`: alle angezeigten MIDI-Takes/Instrumentalstimmen auslesen und direkt dem vorhandenen KI-Analyse-Workflow geben, auch wenn keine Noten markiert sind. Es wird **kein zusätzlicher KI-Controller-Aufruf** erforderlich.
- `Ergänze eine eigenständige Cellostimme zur angezeigten Partitur`: die sichtbaren Stimmen werden als Kontext und Quell-GUIDs an den vorhandenen KI-Kompositions-Workflow übergeben. Die KI kann eine zusätzliche Stimme bzw. eine separate Variante vorschlagen; Vorschlag/Speicherung/Benutzerfreigabe/Undo bleiben erhalten.
- `Analysiere die markierten Noten in der Partitur`: **nur die ausdrücklich markierten Noten**, nicht die Gesamtheit sichtbarer Items.

**Vorhandenes Studio-Menü:** zusätzlicher Eintrag `Notenansicht vorbereiten`. Keine neue Oberfläche und kein eigener Notensatz.

### Wichtige Architekturentscheidung
Das unabhängige, kompakte Shortcut-Skript wird **nicht dupliziert**. Composition Studio sucht seine vom Benutzer bereits registrierte REAPER-MIDI-Aktion dynamisch anhand des Dateinamens und ruft sie über `MIDIEditor_OnCommand` auf. Das eigenständige Skript bleibt weiter separat ausführbar.

**Voraussetzung:** Es muss als MIDI-Editor-ReaScript bereits in REAPER registriert sein; der Quellcode liegt auf dem Entwicklungszweig `feat/reaper-notation-one-shot-20261102` im selben Repository. Falls die Registrierung fehlt, erscheint im bestehenden Studio-Gespräch eine konkrete Fehlermeldung. Falls REAPERs native MIDI-Aktionsliste den Modus-Befehl nicht unter einem bekannten Namen bereitstellt, erfolgt der Wechsel zur Notation einmalig manuell über die View-/Ansicht-Funktion (häufig Alt+4). **Die Ausgabe eines Erfolgstexts ersetzt keine GUI-Wirkungsprüfung.**

### Sicherheit
- Anzeigen und Analysieren verändern **keine** MIDI-Noten, Notenauswahl, CC oder Arrangement-Media-Item-Auswahl.
- Für aus dem vollen Partiturscope erzeugte KI-Vorschläge sind `CS|target` und `CS|track` im Übernahmepfad gesperrt, sodass nicht unkontrolliert neue MIDI-Items auf den Originalspuren überlagert werden. Separate Varianten oder neue Stimmen verwenden den bestehenden kontrollierten Übernahmepfad.
- Kein automatischer Zoom nach jeder KI-Übernahme – der Bearbeitungsausschnitt soll bestehen bleiben.
- Die Dokumentation der Ausgabe von mehreren Tracks als kontinuierliche Notationsansicht bleibt an REAPERs grafische Engine gebunden. Keine Behauptung, dass professionelle Seitenumbrüche oder Notenabstände frei steuerbar seien.

## Test und nächste Schritte
Neue isolierte Offline-Regression führt tatsächlichen Sourcecode aus: Lesen sichtbarer Takes in zwei Instrumentalspuren, Vollkontext statt Notenauswahl, gemutete Noten, harter 2500-Noten-Schutz, kein MIDI/Item-Write, vorhandenen/fehlenden Editor, native Anzeigeaktion und Nutzung/Fehlen des eigenständigen Shortcuts. Zusätzlich laufen die vorhandenen Tests zur Einzelnotenauswahl und KI-Teilübernahme weiter. Siehe [Pull Request #9](https://github.com/wibem1/Composition-Studio/pull/9).

**Nicht verifiziert:** REAPER-7.83-Bedienung, die konkrete Sprache/ID der Notationsmodus-Aktion, Sichtbarkeit nach dem Aufruf des eigenständigen Shortcuts, gleichzeitige Instrumentalspuren in der Notenansicht, reale KI-Analyse im gemischten Partitur-Scope, Wiedererkennung der nach KI-Komposition neu erzeugten Items.

**Nächster einzelner Akzeptanztest:** In einer REAPER-Projektkopie zwei MIDI-Items verschiedener Instrumente auswählen, Composition Studio im bestehenden Fenster starten, `Zeige die Partitur` und `Analysiere die sichtbare Partitur` verwenden. Danach eine neue Stimme im Partiturkontext beauftragen, Vorschlag prüfen und auf einer neuen Spur anwenden. Fällt eine der beiden Startaktionen zweimal aus, zuerst REAPER-Aktions-IDs, Editor-Fokus und Item-Sichtbarkeit diagnostizieren; keine ungeprüfte Aktion hinzufügen.

**Freigabe:** `main` und der bestehende Updater bleiben bei **v1.1.7**. Keine neue Versionsnummer oder Veröffentlichung vor gezielter REAPER-Praxiserprobung.
