# Notationsskript 0.1.2 – Bratschenzeile, 03.11.2026

## Ursache

Die reale 8-Takt-Testreferenz enthält drei Instrumente: Violine, Bratsche und Violoncello. Auf dem Nutzer-Screenshot wurde die Bratsche in einem Violin-/Bass-Doppelsystem dargestellt. Die vorige Vermutung, die SCORE-Zahl für Alt sei falsch, wurde durch einen nativen Test widerlegt: REAPER 7.83 speichert die per Kontextmenü gewählte Einstellung Default clef → Alto als `SCORE 0 3 0 0` und rendert einen korrekten Altschlüssel.

Die tatsächliche Produktionsfunktion `note_analysis()` erkennt die 36 Bratschennoten der JSON-Referenz als Alt (Kosten 0.06000000000000002), aber mit Abstand zum Tenorschlüssel von lediglich 0.053333333333333365. `main()` verlangte mindestens 0.20 und übersprang deshalb die Änderung. Der vorhandene Standard Treble+bass blieb unangetastet. Die vier statt drei Zeilen sind somit durch einen unterlassenen Schlüsselwechsel erklärbar; zusätzliche Ergänzungspausen folgen aus dem Doppelsystem.

## Eng begrenzte Korrektur

Die bestehende Hilfslinien-/Tonlagenanalyse bleibt erhalten. Zusätzlich ist ein einzelnes System zulässig, wenn alle analysierten Töne auf dessen fünf Linien/Zwischenräumen liegen und der diatonische Tonumfang mindestens eine Quinte umfasst. Ein kleiner Kostenabstand zwischen zwei gleich gut lesbaren Einzelschlüsseln verhindert dann nicht mehr den Wechsel aus einem unpassenden Doppelsystem. Echte simultane tiefe/hohe Klavierstimmen behalten den vorhandenen Grand-Staff-Schutz; monotone/zu kurze Fragmente werden weiter nicht willkürlich umgeschlüsselt. Kein Instrumentenname oder Programmwechsel wird für diese Entscheidung ausgewertet.

SCORE-Werte bleiben unverändert: Violin 1, Bass 2, Alt 3, Tenor 4. Zoom-/Öffnungs-/Undo-Verfahren aus 0.1.1 unverändert. Keine neuen MIDI-, CC- oder Timingoperationen.

## Nachweise

- Vollständige Lua-5.4-Syntax und **42 Offline-Regressionsprüfungen** bestanden. Neu: echte Bratschen-Tonhöhen der 8-Takt-Referenz, Ausgangszustand Default-Grand, korrekter Altschlüssel trotz Abstand <0.20, idempotenter erneuter Aufruf.
- **Echte REAPER-7.83/linux-x86_64-GUI** in isolierter portabler Testinstanz: Default clef → Alto manuell ausgewählt, SCORE-Zeile nachgelesen und gerenderten Altschlüssel visuell geprüft. Keine erfundene Zuordnung aus Mocks.
- Anschließend alle **117 Noten der Testreferenz** mit originalen PPQ-Einsätzen/-Enden, Tonhöhen, Velocity und getrennten Kanälen in drei frischen Test-Takes rekonstruiert; getestetes 0.1.2-Produktionsskript direkt ausgeführt. Ergebnis visuell: **drei** Notenzeilen, Violine/Alt/Bass. Keine Aufteilung der Bratsche auf zwei Systeme.
- `MIDI_GetAllEvts`-Bytevergleich vor/nach Skriptausführung in jeder der drei Takes: **identisch**. REAPER-Rücklesung:

```text
VERSION 7.83/linux-x86_64
script true nil
Violine - G-Schluessel: SCORE 0 1 0 0 MIDI_UNCHANGED=true
Bratsche - Alt-C-Schluessel: SCORE 0 3 0 0 MIDI_UNCHANGED=true
Violoncello - F-Schluessel: SCORE 0 2 0 0 MIDI_UNCHANGED=true
```

Getestete Produktionsdatei SHA-256: `eb1759ea0c6aff2865fedae6048887e87d69a5fa675379fdb78f6ce76420b747`.

Die native Prüfung verwendete rekonstruierte Noten-Takes, nicht den kompletten MIDI-Dateiimport einschließlich Metaereignissen. Testtempo/-tonart blieben in dieser isolierten Instanz auf Standardwerten; hier geht es ausschließlich um Schlüssel-/Systemkorrektheit und unveränderte Take-Ereignisdaten. Keine Audio-/Klangbeurteilung. Die grafische Linux-Prüfung ersetzt noch keinen erneuten Test in der konkreten macOS-Installation. Keine allgemeine Lesbarkeitsgarantie für komplexe Klaviermusik und keine neue Composition-Studio-Version.

## Übernahme und Rückweg

Nur die bisher registrierte Datei `REAPER Notation - 4 Takte und Instrumentenschluessel.lua` durch 0.1.2 ersetzen; Dateinamen beibehalten. Für die Gegenprobe dieselbe 8-Takt-Testdatei und dieselben drei MIDI-Spuren verwenden. Erwartung: genau drei Systeme, Alt-C-Schlüssel für die Bratsche. Die vorherige Fassung bleibt im Git-Verlauf vor dieser Korrektur (Branchkopf `ed3399401331933752a7aa2a8013b1b8ae14aac1`) verfügbar. Schlüsseländerung im Projekt über REAPER Undo rücknehmbar.
