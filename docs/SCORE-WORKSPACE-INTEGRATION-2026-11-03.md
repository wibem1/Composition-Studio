# Composition Studio – Notationseditor als zweiter Kompositionsarbeitsbereich

**03.11.2026 · Version 1.1.8 · PR #9 · vom Nutzer beauftragte Testfreigabe**

Der aktuelle Auftrag erlaubt ausdrücklich die Veröffentlichung mit dokumentiert fehlenden REAPER-Praxistests. Er ersetzt die nachstehenden historischen Freigabesperren; ältere Implementierungs- und Testabschnitte bleiben als Verlauf erhalten. Die Version ist kein praktisch bestätigter SAFE-Stand. Abschlussprüfung und Rückweg: [RELEASE-1.1.8.md](RELEASE-1.1.8.md).

**Gezielte Abschlusskorrekturen:** Analyse → Überarbeitung bewahrt gespeicherte Item-/Einzelnotenbindung, read-only Partiturscope und harmonischen Referenztext. Ein Fortsetzungsauftrag für einzelne markierte Noten wird abgewiesen statt auf ganze Items erweitert. Eine ausdrücklich editorbezogene Komposition wird nicht versehentlich als kontextfreie Neuanlage behandelt. Bestehende UI, Updater und Übernahmemechanik bleiben bestehen.

## Erweiterung am 03.11.2026 – Piano-Roll gleichberechtigt

**Nutzerwunsch:** Auch REAPERs **Piano-Roll-Ansicht** soll denselben Composition-Studio-Workflow wie Arrangement und Notenansicht unterstützen. Beide REAPER-MIDI-Editor-Darstellungen benutzen dieselben MIDI-Takes und Note-Selection-API. Die neu implementierte MIDI-Editor-Brücke ist deshalb nicht auf das grafische Notenbild beschränkt; keine separate Engine oder Palette.

**Aufträge im vorhandenen Composition Studio:**
- `Zeige die Piano-Roll` bzw. `Öffne den Piano-Roll`: öffnet den vorhandenen MIDI-Editor (bei markierten MIDI-Items nötigenfalls über REAPER-Main-Aktion `40153`), wechselt per bekannter nativer MIDI-Aktion **View: Mode: piano roll** in diese Darstellung. Der Notations-Shortcut (Notenschlüssel, Vier-Takte-Zoom) wird dabei **nicht** ausgeführt. Ist die Aktion unbekannt, erfolgt eine sichtbare Fehlermeldung mit manuellem Fallback **Alt+1**, keine unbestätigte Erfolgsmeldung.
- `Analysiere den Piano-Roll` oder `Analysiere die sichtbaren Noten im MIDI-Editor`: verwendet alle im MIDI-Editor enthaltenen MIDI-Takes als Analysekontext, ohne eine explizite Auswahl einzelner Noten zu verlangen; Kontext ist read-only und auf 2500 MIDI-Noten begrenzt.
- `Analysiere die markierten Noten im Piano-Roll`, `Verbessere die markierten Noten`, `Transponiere die ausgewählten MIDI-Noten um 2 Halbtöne`: nur die **ausdrücklich ausgewählten, editierbaren Noten** werden zum Bearbeitungsziel. Bei leerer Auswahl Abbruch, kein stiller Fallback auf vollständige Items.
- `Ergänze eine neue Gegenstimme zum Piano-Roll`, `Verlängere die Musik im MIDI-Editor`: bereits vorhandene KI-Kompositions- und Fortsetzungsfunktionen auf Basis der sichtbaren MIDI-Spuren; Vorschlag und Freigabe bleiben erhalten. Der Schutz gegen ungeprüfte Änderungen vollständiger Original-Items gilt genauso wie für die Partitur.

**Neu: harmonisch/kontrapunktisch informierte Einzelnotenarbeit.** Für den *ausdrücklich markierten* Ausschnitt wird vor dem KI-Aufruf ein eigener **read-only Referenzauszug** aus den zusätzlich sichtbaren Instrumentalstimmen angelegt (QN-Fenster des Auswahlbereichs ±2 Viertel, höchstens 160 Noten im Referenzauszug). Dieser Kontext wird in den Analyse-, Kompositions- und eingeschränkten Einzelnotenverbesserungspfad aufgenommen. Die Referenzstimmen sind **nicht** Bestandteil der Bearbeitungsfreigabe. KI-Änderungen werden nur auf die ursprünglich markierten Quellnoten und nur nach expliziter Bestätigung angewendet. Ist der Auszug unvollständig, wird dies gekennzeichnet.

Der Anwender kann den Editor-Modus nach eigenem Ermessen umschalten; der nächste musikalische Auftrag wertet den weiterhin geöffneten MIDI-Editor aus, **ohne** den Zoom oder die Darstellung automatisch zu wechseln.

**Objektive Prüfung:** neuer Produktionsfunktions-Mocktest für den nativen Piano-Roll-Modus ohne Notations-Shortcut, mehrspurige Referenzdaten mit nicht editierbarer Begleitspur, Abgrenzung von Notenauswahl vs. allen sichtbaren Noten, keine schreibenden Aktionen, Schutz bei leerer Selektion und Schutz gegen unkontrollierte `ACTION|`-Whole-Item-Kommandos. GitHub Actions prüft zusätzlich den vollständigen Lua-Code und die bisherigen Einzelnoten-/KI-Änderungs-Regressionstests. **Echter REAPER-7.83-Echtlauf und die Interaktion mit einem realen KI-Modell bleiben ausstehend.** `main` bleibt bei v1.1.7, PR #9 bleibt Draft.

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
