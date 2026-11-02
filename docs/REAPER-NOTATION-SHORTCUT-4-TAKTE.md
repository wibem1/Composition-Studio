# REAPER Notation – ein Shortcut, vier Takte, MIDI-basierte Schlüsselwahl und proportionale Abstände

**Stand der aktuellen Entwicklung:** Tracknamen werden **überhaupt nicht mehr** zur Schlüsselwahl verwendet. Das Skript analysiert die Tonhöhen der sichtbaren MIDI-Takes, wählt anhand der Hilfslinienbelastung einen einzelnen G-/F-/Alt-/Tenorschlüssel und verwendet die bereits in **Notation Studio v0.1.17–v0.1.24** vorhandene SCORE-Wertzuordnung und Methode zum Ersetzen beziehungsweise Einfügen des Track-SCORE-Eintrags. Bei weniger als vier Noten, nicht eindeutigem Register oder überlappenden hohen und tiefen Stimmen ohne gesicherten Grand-Staff-Code wird **kein** Schlüssel erzwungen. Der Vier-Takte-Zoom und die proportionale Anzeige sind unverändert.

**SCORE-Zahlen des vorhandenen Notation Studio v0.1.24:** `treble=1`, `bass=2`, `alto=3`, `tenor=4`. Dort wird ein vorhandener `SCORE`-Eintrag ersetzt oder ein fehlender Eintrag nach der `VU`-Zeile angelegt. Eine direkte, dokumentierte REAPER-API zum Setzen des Default-Schlüssels gibt es weiterhin nicht. Erfolg im realen Editor ist bei dieser neuen Kombination noch zu prüfen.

**Status:** Eigenständiger Testkandidat auf Branch `feat/reaper-notation-one-shot-20261102`, zusätzlich zu und unabhängig von `Notation Studio.lua`. Keine grafische Palette, keine Bestätigung, keine KI-API, kein ReaImGui, kein SWS, keine Anzeigequantisierung. Proportionale musikalische Abstände werden bei eindeutigem REAPER-Status nur eingeschaltet, niemals unabsichtlich ausgeschaltet. Ausgangsdatei auf `main` bleibt erhalten.

## Einmalige Einrichtung

1. Datei [REAPER Notation - 4 Takte und Instrumentenschluessel.lua](../REAPER%20Notation%20-%204%20Takte%20und%20Instrumentenschluessel.lua) herunterladen und auf dem Rechner ablegen.
2. Den REAPER-MIDI-Editor öffnen.
3. **Aktionen → Aktionsliste anzeigen**, als Bereich **MIDI Editor** wählen, **ReaScript: Laden** und diese Datei hinzufügen.
4. In dieser Aktionsliste dem Skript eine selbst gewählte Tastenkombination zuweisen.

## Ausführung

Shortcut einmal im geöffneten MIDI-Noteneditor drücken. Das Skript betrachtet die derzeit im MIDI-Editor enthaltenen MIDI-Takes (einschließlich nicht editierbarer), fasst sie nach Track zusammen und bewertet deren **tatsächliche Tonhöhen**, ohne Track- oder Take-Namen auszulesen. Der Shortcut aktiviert außerdem **proportionale musikalische Notenabstände**, sofern sie noch deaktiviert sind. Bei bereits aktiver Option führt er keinen erneuten Toggle aus. Wenn REAPER die Aktion oder ihren Status nicht bereitstellt, verändert er diese Einstellung nicht und führt die anderen Funktionen trotzdem aus. Es zoomt mit der vorhandenen MIDI-Aktion `View: Zoom to project loop selection` auf vier komplette Takte ab dem aktuellen Projekt-Bearbeitungscursor. Die ursprüngliche Loop- und Zeitauswahl wird danach wiederhergestellt; es werden keine MIDI-Noten, keine CC und keine Anzeigequantisierung verändert. Bei weniger als vier MIDI-Noten, mehrdeutigen Tonlagen oder nicht sicher zu schreibenden SCORE-Zeilen werden die Spuren ausgelassen. Alle Änderungen an Tracks gehören zu einem REAPER-Undo-Schritt. Keine störenden Dialoge; Fehler/Überspringungen erscheinen nur in der REAPER-Konsole.

## Automatischer vertikaler Zoom (neuer Testkandidat)

Nach Schlüsselanalyse und Proportionalanzeige stellt das Skript den vertikalen Notationszoom automatisch ein. Da es in der nativen ReaScript-API keine dokumentierte absolute `staff_size`- oder vertikale Notationszoom-Einstellung gibt, nutzt es zwei vorhandene **MIDI-Editor-Aktionen**: erst `View: Zoom to content` als reproduzierbaren Ausgangspunkt, danach `View: Zoom in vertically` für eine begrenzte Anzahl Schritte. Die frühere `Notation Studio.lua` v0.1.24 verwendete bereits `View: Zoom in vertically` (drei Schritte), allerdings ohne Rücksetzung, was bei Wiederholung kumulative Vergrößerung erzeugt.

Die Anzahl Schritte wird anhand der tatsächlichen Längen der im MIDI-Editor sichtbaren Items berechnet (über `GetMediaItemInfo_Value(...,"D_POSITION"/"D_LENGTH")` und Taktgrenzen): bis zwei Vier-Takte-Systeme fünf Schritte, bis vier Systeme vier, bis acht Systeme drei, darüber zwei. Bei mindestens drei sichtbaren Spuren wird ein Schritt abgezogen, bei mindestens fünf zwei. Minimum ein Schritt. Fehlen die Item-Längen, werden drei Schritte genutzt.

**Wichtig:** `View: Zoom to content` verändert auch die horizontale Ansicht. **Deshalb wird der schon real bestätigte Vier-Takte-Zoom danach als letzte Aktion ausgeführt.** So bleiben die Projekt-Loop- und Zeitauswahl erhalten. Sind die erforderlichen MIDI-Aktionen nicht verfügbar, **bleibt der vertikale Zoom unverändert**, die restlichen Funktionen laufen weiter.

Dies ist eine Näherung zur Verbesserung der **sichtbaren Seitenansicht**, kein Eingriff in MIDI-Noten, keine Löschung zusätzlicher Bildschirm-Leertakte und kein Garant dafür, dass die letzte musikalische Zeile exakt am Fensterrand liegt. Ob `Zoom to content` auf der konkreten REAPER-Installation die vertikale Darstellung tatsächlich reproduzierbar zurücksetzt, muss **real grafisch geprüft werden**. GitHub Actions [Run 41525473203](https://github.com/wibem1/Composition-Studio/actions/runs/41525473203) bestätigte erfolgreich Syntax und 28/28 vollständige Offline-Mocktests, einschließlich Wiederholung ohne Zoom-Drift, adaptiver Anzahl, fehlender Aktionen, unverändertem Vier-Takte-Zoom und Noten-/SCORE-Schutz.

## Schlüsselwahl anhand musikalischer MIDI-Daten

Die MIDI-Noten werden pro sichtbarerer Spur eingelesen; für jeden der vier Einzelschlüssel wird die Zahl der nötigen Hilfslinien über alle Tonhöhen bewertet. Eine hohe Melodie bekommt so in der Regel einen Violinschlüssel, eine mittlere Lage eventuell einen Altschlüssel und eine tiefe Lage einen Bassschlüssel, **unabhängig vom Namen der Spur**. Diese Heuristik kann bei überlappenden Registerbereichen nicht den Instrumententyp beweisen. Deshalb werden unsichere Fälle übersprungen.

**Korrekte Zieltabelle aus dem älteren Notation Studio:** G=`SCORE 0 1 0 0`, F=`SCORE 0 2 0 0`, Alt-C=`SCORE 0 3 0 0`, Tenor-C=`SCORE 0 4 0 0`. Die bisherige fehlerhafte, verschobene Tabelle des Einmal-Skripts wurde entfernt. Für Klavier-Doppelsysteme wird kein unbelegter nummerischer SCORE-Wert ausgegeben; diese Einstellung bleibt erhalten.

**Einschränkung:** Die SCORE-Track-Chunk-Operation gehört zum früheren Projektcode, bleibt aber eine undokumentierte REAPER-Schnittstelle. Ein erfolgreicher Mock oder ein gespeicherter Zahlenwert beweist noch nicht, dass der geöffnete Editor den passenden Schlüssel zeichnet. Deshalb bis zur visuellen Abnahme nur an einer gesicherten Projektkopie anwenden.

## Automatisierte Prüfung

GitHub Actions überprüft die Lua-Syntax und einen vollständigen Offline-Mock: bewusst irreführende Tracknamen (die nicht gelesen werden dürfen), helle/mittlere/tiefe Register, zu kurze und mehrdeutige Ausschnitte, tatsächliche Registerüberlappung, SCORE-Werte aus v0.1.24, Vier-Takte-Zoom, Loop-Wiederherstellung sowie sicheres Einschalten der Proportionalanzeige. **Diese Tests ersetzen keinen REAPER-Notationsbildvergleich.**

## Nächster Schritt

Ein einmaliger praktischer Test auf einer gesicherten Kopie des 8-Takt-REAPER-Notationstestprojekts: Kontrollieren, ob Violine (nur G-System), Bratsche (Alt-C), Violoncello (F) tatsächlich korrekt angezeigt werden und vier Takte horizontal ins Fenster passen. Bei falscher Schlüsselnummer anhand des realen REAPER-`SCORE`-Zustands korrigieren, nicht weiter raten. Erst nach positiver Rückmeldung Merge/produktive Freigabe erwägen.
