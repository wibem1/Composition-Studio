# REAPER Notation – ein Shortcut, vier Takte, Instrumentenschlüssel

**Status:** Eigenständiger Testkandidat auf Branch `feat/reaper-notation-one-shot-20261102`, zusätzlich zu und unabhängig von `Notation Studio.lua`. Keine grafische Palette, keine Bestätigung, keine KI-API, kein ReaImGui, kein SWS, keine Anzeigequantisierung. Ausgangsdatei auf `main` bleibt erhalten.

## Einmalige Einrichtung

1. Datei [REAPER Notation - 4 Takte und Instrumentenschluessel.lua](../REAPER%20Notation%20-%204%20Takte%20und%20Instrumentenschluessel.lua) herunterladen und auf dem Rechner ablegen.
2. Den REAPER-MIDI-Editor öffnen.
3. **Aktionen → Aktionsliste anzeigen**, als Bereich **MIDI Editor** wählen, **ReaScript: Laden** und diese Datei hinzufügen.
4. In dieser Aktionsliste dem Skript eine selbst gewählte Tastenkombination zuweisen.

## Ausführung

Shortcut einmal im geöffneten MIDI-Noteneditor drücken. Das Skript betrachtet die derzeit im MIDI-Editor enthaltenen MIDI-Takes (einschließlich nicht editierbarer), fasst sie nach Track zusammen und setzt automatisch bekannte Default-Clef-Trackwerte gemäß Instrumentnamen. Es zoomt mit der vorhandenen MIDI-Aktion `View: Zoom to project loop selection` auf vier komplette Takte ab dem aktuellen Projekt-Bearbeitungscursor. Die ursprüngliche Loop- und Zeitauswahl wird danach wiederhergestellt; es werden keine MIDI-Noten, keine CC und keine Anzeigequantisierung verändert. Bei unbekannten Instrumentnamen oder komplexen SCORE-Zeilen werden die Spuren ausgelassen. Alle Änderungen an Tracks gehören zu einem REAPER-Undo-Schritt. Keine störenden Dialoge; Fehler/Überspringungen erscheinen nur in der REAPER-Konsole.

## Zuordnung der Schlüssel (Testkandidat)

| Trackname | Ziel-SCORE |
| --- | --- |
| Violine/Violin/Geige, Flöte | `SCORE 0 4 0 0` (aus ausdrücklichem Nutzerhinweis) |
| Bratsche/Viola | `SCORE 0 3 0 0` (noch nicht mit REAPER-Ansicht bestätigt) |
| Cello/Violoncello/Kontrabass | `SCORE 0 2 0 0` (noch nicht mit REAPER-Ansicht bestätigt) |
| Klavier/Piano | `SCORE 0 1 0 0` (Klaviersystem) |

**Wichtige Einschränkung:** REAPER dokumentiert das SCORE-Chunk-Feld nicht als stabile API. Frühere Versuche zur Nummernzuordnung widersprechen sich teilweise. Darum ist das gesamte Skript bis zur Verifikation der tatsächlichen Notation in REAPER **nicht für unbeaufsichtigte Produktivprojekte freigegeben**. Ziel ist trotzdem eine einzige Shortcutauslösung ohne Rückfragen.

## Offline-Test

[GitHub Actions – Run 41488463631](https://github.com/wibem1/Composition-Studio/actions/runs/41488463631): Lua-5.4-Syntaxprüfung und 10 simulierte Testfälle bestanden. Testet mehrere Tracks, den vom Nutzer vorgegebenen Treble-SCORE-Eintrag, Loop-Wiederherstellung, Zoom-Aktion, Undo-Gruppierung, wiederholte Ausführung und unbekannte Instrumente. **Nicht** damit nachgewiesen: die tatsächliche REAPER-Score-Anzeige, die Instrumentmapping-Nummern für alle Schlüssel oder die exakte optische Darstellung von vier Takten.

## Nächster Schritt

Ein einmaliger praktischer Test auf einer gesicherten Kopie des 8-Takt-REAPER-Notationstestprojekts: Kontrollieren, ob Violine (nur G-System), Bratsche (Alt-C), Violoncello (F) tatsächlich korrekt angezeigt werden und vier Takte horizontal ins Fenster passen. Bei falscher Schlüsselnummer anhand des realen REAPER-`SCORE`-Zustands korrigieren, nicht weiter raten. Erst nach positiver Rückmeldung Merge/produktive Freigabe erwägen.
