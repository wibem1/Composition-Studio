# Composition Studio – Notationsmodul

### Vier verbindliche Qualitätsanforderungen – 02.11.2026

Die Zielerreichung wird ab jetzt **an genau diesen vier sichtbaren Eigenschaften des eingebauten REAPER-Notationseditors** beurteilt:

1. **Optimierte horizontale Notenabstände:** Proportionale musikalische Abstände und sinnvoller Zoom müssen dichte Passagen entzerren; eng benachbarte Noten, Vorzeichen, Notenhälse und Balken sollen auch beim Bearbeiten auseinanderzuhalten sein. Nicht einfach so weit zoomen, dass nur wenige Noten sichtbar sind.
2. **Keine unsinnigen Minipausen:** Kurze rechnerische Pausen, insbesondere durch 1-Tick-Note-Off-Lücken aus MIDI, dürfen das Notenbild nicht dominieren. Echte musikalische Pausen und eigenständige Stimmen bleiben dagegen sichtbar. Zuerst Anzeigequantisierung/Mindestnotenlänge und REAPERs native Bindungs-/Stimmenoptionen prüfen, niemals Note-On/Off-Zeiten stillschweigend verändern oder echte Pausen löschen. Nicht behaupten, reine Displayquantisierung könne jedes Polyphonie-/Pausenproblem lösen.
3. **Darstellungsquantisierung (getrennt von MIDI-Quantisierung):** Für jede Spur/Instrument passend (zunächst 1/16 mit Mindestnotenlänge 1/32 als **Testkandidat**, nicht als universeller Endwert), bei Bedarf Triolen. REAPER-Handbuch bestätigt die Unabhängigkeit der `Display quantization`- und `Minimum note length`-Werte vom ursprünglichen MIDI-Timing. Echte kürzere Noten dürfen durch zu grobe Darstellung nicht irreführend werden.
4. **Getrennte Notenzeilen und passende Schlüssel je Instrument:** Jede sichtbare MIDI-Instrumentalspur erhält ihr eigenes System bzw. ihre eigene Notenzeile. REAPER kann mehrere gleichzeitig sichtbare MIDI-Tracks im Notationseditor anzeigen (bei mehreren Tracks in kontinuierlicher Ansicht); Schlüssel sind über das Kontextmenü `Default clef` je Spur wählbar. Für die bekannte Orgelphantasie zuerst Manual I (Violinschlüssel), Manual II (Schlüssel nach tatsächlichem Tonumfang), Pedal (Bassschlüssel) testen. Nicht automatisch alle Systeme in ein einziges System zusammenrechnen.

**Annahmekriterium:** Derselbe kurze musikalische Abschnitt ist nach Konfiguration im **REAPER-eigenen** Noteneditor ohne Minipausenflut, mit gut erkennbaren Stimmen, passenden Schlüsseln und ausreichendem Abstand tatsächlich les- und bearbeitbar; Original-MIDI/Wiedergabe bleiben erhalten. Der praktische A/B-Test entscheidet, nicht ein automatischer Lua-Mocktest. Erst an der verbleibenden konkret sichtbaren Schwachstelle ansetzen.

**Technikstatus:** Dies ist eine verbindliche Anforderung, **noch keine neue Implementierung und noch kein realer Test aller vier Punkte**. Vorhandene Schaltfläche `Lesbarkeit verbessern` (Notation Studio 0.1.24) nicht blind verwenden, da sie auch Track-`SCORE`-Metadaten überschreibt. Keine Eigenentwicklung eines Renderers.

**Quelle:** Offizielles REAPER-Handbuch, Notation View Options und Staff-/Track-Kontextmenüs: https://www.reaper.fm/userguide.php


## Verbindliche Zielkorrektur – 02.11.2026

**Priorität 1: Den bereits vorhandenen REAPER-Noteneditor zu einer im Alltag brauchbaren Arbeitsnotation bringen.** Er muss nicht einen eigenständigen Notensatz wie MuseScore oder Dorico bieten, sondern rhythmisch verständlich, ausreichend übersichtlich und musikalisch sicher sein, sodass Komposition, Korrektur und Orientierung in der Partitur möglich bleiben. KEIN eigener Renderer, KEIN Nachbau von REAPER-Notator und KEIN Ersatz des Noteneditors in dieser Phase.

**Geprüfte Ausgangslage:** `Notation Studio.lua` v0.1.24 auf `main` besitzt bereits Steuerelemente für proportionale musikalische Abstände, horizontale/vertikale Skalierung, Darstellungsquantisierung 1/8, 1/16 und 1/32 sowie eine Funktion zur Lesbarkeitsverbesserung, welche REAPER-MIDI-Editor-Aktionen aufruft. Diese Funktionen sind zunächst an der echten REAPER-Notation zu erproben, nicht durch eigene Zeichenfunktionen zu ersetzen. Eine frühere Implementierung ist kein Nachweis einer aktuellen brauchbaren Darstellung.

**Kompakter Machbarkeitstest statt großer Entwicklung:**
- Auf höchstens zwei repräsentativen Abschnitten: eine weitgehend einstimmige Passage und eine polyphone Passage, bevorzugt aus den bereits bekannten Test-MIDI-Dateien. Vorher-/Nachher-Bild desselben Bereichs des **REAPER-eigenen Notationseditors**.
- Vorhandene Anzeigenoptionen einzeln und nachvollziehbar prüfen: proportionale Notenabstände, Anzeigequantisierung und Mindestnotenlänge (ohne MIDI-Quantisierung), Schlüssel/Systemzuordnung, automatische oder manuelle Stimmenzuordnung, Anzeige von Bindungen und Balken, sinnvolle Zoomeinstellung. Kein universelles Preset für jeden Instrumententyp erzwingen.
- Prüfkriterien: keine dominierenden künstlichen Kleinstpausen, Takt- und Tonhöhenwerte nachvollziehbar, Stimmen/Einzelsysteme unterscheidbar, genug Abstand zum Bearbeiten und **MIDI/Wiedergabe unverändert**. Korrektheit hat Vorrang vor Schönheit.
- Einmaliger, begrenzter A/B-Test; danach **Go/No-Go**, ob REAPERs bestehender Editor mit Konfiguration und ggf. wenigen gezielten REAPER-Aktionen als Arbeitsnotation taugt. Eine grundsätzlich unsteuerbare Notensatzschwäche ist offen zu benennen, nicht durch monatelangen Eigenbau zu kaschieren.

**Beendeter Abzweig:** Das experimentelle eigene ReaImGui-Notenfenster aus Draft-PR #4 (`feat/notation-score-preview-20261101`, 0.2.0–0.2.3-test) wird nicht weiterentwickelt und nicht in `main` übernommen. Die isolierten GPL-Notator-Analysen aus Draft-PR #3 bleiben nur Forschung; keine automatische Übernahme in die produktive Software. Frühere Abschnitte „Architekturwechsel – 2026-10-04“ und „Renderer-Basis – ScoreFlow + reaper_webview“ dokumentieren historische Entscheidungen und sind für die aktuelle Priorität **überholt**.

**Grenzen:** REAPERs interner Notensatz kann mit ReaScript nicht beliebig ersetzt werden. Nur belegte, vorhandene Anzeige-/Notationseinstellungen verwenden; MIDI-Performance nur mit ausdrücklicher Zustimmung verändern.


## Zielsetzung

Der REAPER-Notationseditor soll zu einem echten Kompositionsarbeitsplatz erweitert werden. Die vorhandene REAPER-Notation wird nicht ersetzt, sondern durch Composition Studio komfortabler, musikalisch intelligenter und mit der KI-, Playback- und Exportebene verbunden.

Das Modul soll zwei gleichberechtigte Arbeitsweisen unterstützen:

1. **Manuelles Komponieren und Notieren** direkt im REAPER-Notationseditor.
2. **KI-unterstütztes Arbeiten** auf der aktuellen musikalischen Auswahl, z. B. „transponiere nach G-Dur“, „erfinde eine Improvisation hierzu“, „führe das Motiv weiter“, „schreibe eine Gegenstimme“ oder „optimiere den Notensatz“.

## Grundprinzip

Notation ist nicht nur Grafik. Zwischen Partitur und Wiedergabe wird eine semantische musikalische Ebene aufgebaut:

**Notation ↔ musikalische Bedeutung ↔ MIDI/Controller ↔ Instrument/Playback**

Damit sollen Spielanweisungen in beide Richtungen funktionieren. Von Composition Studio oder der KI erzeugte musikalische Absichten erscheinen im Notenbild; manuell eingetragene Angaben werden erkannt und bei der Wiedergabe berücksichtigt.

Beispiele: Triller werden hörbar ausgeführt, ritardando verändert das Tempo, crescendo steuert Dynamik/Expression, pizzicato/arco schaltet die Spielweise, Legato/Staccato beeinflusst Artikulation und Phrasierung.

## SWAM

Die vorhandene SWAM-Integration wird nicht auf eine einzelne Violine beschränkt. Ziel ist eine **mehrspurige Ensemble-Architektur** mit instrumentenspezifischen Profilen, z. B. Violine I/II, Viola, Cello, Flöte, Klarinette und weitere SWAM-Instrumente.

Eine musikalische Anweisung wird instrumentenspezifisch übersetzt. Dieselbe Angabe wie crescendo, vibrato oder legato darf bei Streicher und Holzbläser unterschiedliche Controller- und Artikulationsdaten erzeugen.

## Notensatz und Layout

Geplante Funktionen:

- Darstellungsquantisierung ohne Änderung der MIDI-Performance
- Stimmen- und Systemzuordnung
- Schlüssel, 8va/8vb, Beaming, Bindungen und enharmonische Schreibweise
- Dynamik, Artikulationen, Ornamente und Spielanweisungen
- KI-gestützte Notationsinterpretation eingespielter MIDI-Daten
- Arbeitszoom und Druckansicht
- Takte pro System, System- und Seitenumbrüche
- für A4-Ausdruck optimiertes Notenbild

## Export

Priorität hat **MusicXML** als Austauschformat für Dorico, MuseScore und andere Notensatzprogramme. Zusätzlich vorgesehen: MIDI und PDF; LilyPond kann später ergänzt werden.

## Entwicklungsprinzip

Keine neue DAW und keine parallele Spezial-App. REAPER bleibt DAW, Audio-/MIDI-Engine, Plugin-Host und Undo-System. Composition Studio ergänzt nur die Funktionen, die REAPER im Notations- und KI-Bereich fehlen.

Die Entwicklung erfolgt modular und in kleinen, testbaren Stufen. Jede Stufe muss über die bestehende eingebaute Updatefunktion ausgeliefert werden und im Infofenster klar angeben, was neu ist und was getestet werden soll.

## Phase 1 – v1.0.5 / Notation-Prototyp 0.1

Implementiert:

- neues Menü **Notation** im vorhandenen Composition-Studio-Fenster
- Anzeige der Zahl aktuell ausgewählter Noten im aktiven MIDI-/Notationseditor
- Darstellungsraster **Auto**, **1/8**, **1/16**, **1/32**
- **Originale Darstellung** zum Entfernen eigener Display-Längen
- Änderung ausschließlich der REAPER-Notationseigenschaft `disp_len`; MIDI-Noten, Anschläge und echtes Timing bleiben unangetastet
- REAPER Undo/Redo bleibt erhalten

### Zu testen

1. Notationseditor öffnen und mehrere Noten auswählen.
2. Composition Studio → **… → Notation**.
3. Auto, 1/8, 1/16 und 1/32 vergleichen.
4. Kontrollieren, dass die Wiedergabe zeitlich identisch bleibt.
5. **Originale Darstellung** testen.
6. REAPER Undo/Redo testen.

Erst nach erfolgreichem Test wird Phase 2 begonnen.


## Phase 1b – v1.0.7 / Notenbild

Der erste reale Test zeigte, dass korrekte Darstellungsquantisierung bei zu geringer horizontaler Notendichte nicht genügt. Die Lesbarkeit des Notenbilds hat daher Vorrang.

Implementiert: Lesbar machen, Breiter, Schmaler, Auswahl einpassen, Inhalt einpassen. Diese Funktionen steuern REAPERs vorhandene MIDI-Editor-Zoom-Aktionen; sie verändern keine Musikdaten.


## Phase 1c – v1.0.8 / musikalische Abstände

REAPERs **Proportional (musical) note spacing** wird nun direkt angesteuert. Dieser Modus ist Grundlage für das weitere Notensatzkonzept, weil rhythmisch kurze Werte mehr optischen Raum erhalten als bei absoluter Zeitdarstellung. Der Schalter ist einzeln testbar und Teil von Lesbar machen.


## Phase 1d – v1.0.9 / automatische Bereinigung

Ein erster deterministischer Notensatz-Button bündelt REAPERs vorhandene semantische Notationsfunktionen. Ziel ist eine belastbare Basis vor KI-Notensatz und individuellen Display-Offsets. Direkte `disp_pos`-Manipulation wird erst eingesetzt, wenn Einheit und Verhalten vollständig verifiziert sind.


## Architekturwechsel – 2026-10-04 / Workspace 0.1

Die REAPER-eigene Notationsansicht ist nicht länger Zieloberfläche von Composition Studio. REAPER bleibt DAW, MIDI-/Audio-Engine und Plugin-Host. Composition Studio erhält ein eigenes integriertes Notationsfenster.

### Feste Zielstruktur
- Hauptfenster: Chat, Komposition, REAPER-Steuerung, Modellwahl, Einstieg „Notation“
- Notationsfenster: editierbarer Score, Stimmen, Dynamik, Artikulationen, Spielanweisungen, Layout, MusicXML/PDF, KI-Bearbeitung und SWAM-Semantik
- gemeinsame Musikdaten: REAPER MIDI ⇄ Score-Modell
- kein separates Bedienprogramm, solange die integrierte Lösung technisch und qualitativ überzeugt

Workspace 0.1 testet zunächst nur Fensterarchitektur und Unabhängigkeit vom Hauptfenster. Der eigentliche Score-Kern folgt als getrennte technische Stufe.


## Renderer-Basis – ScoreFlow + reaper_webview

Nach Verifikation der verfügbaren Projekte wird ScoreFlow als aktuelle Renderer-/Editor-Basis untersucht. ScoreFlow ist MIT-lizenziert und trennt seinen modularen VexFlow-JavaScript-Kern von der Flutter-Hülle. Die Engine bietet bereits Note-Hit-Testing und einen stabilen Score-JSON-Vertrag. Für die Einbettung in REAPER wird die ebenfalls MIT-lizenzierte Erweiterung reaper_webview verwendet (macOS WKWebView / Windows WebView2). Dadurch bleibt Composition Studio eine REAPER-integrierte Anwendung und benötigt kein separates Notationsprogramm.
