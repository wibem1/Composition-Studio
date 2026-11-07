# Native Notation Studio – eigenständige Testfassung

Stand: 07.11.2026. Branch `feat/semantic-notation-analysis-20261104`. Die eigenständige Aktion verbessert die rhythmische Darstellung, wählt Track-Schlüssel und setzt einen lesbaren horizontalen Zoom. Keine Integration in Composition Studio, kein Merge und keine Produktionsfreigabe. Kennzeichnung weiterhin `0.1.0-test`; maßgeblich ist der Git-Commit.

## Bedienung und Umfang

Die gewünschten Tracks gemeinsam im nativen REAPER-MIDI-/Notationseditor darstellen und einmal **Native Notation Studio - Lesbare Notation erstellen** starten. Keine Einzelnoten markieren und keinen musikalischen Prompt eingeben. Ziel sind alle von `MIDIEditor_EnumTakes(editor,index,false)` gemeldeten dargestellten Takes mit ihren gesamten Noteninhalten, auch außerhalb des horizontal sichtbaren Ausschnitts. Arrangement-Auswahl ist kein Ersatz für den geöffneten Editor.

Ein vorbereiteter KI-Auftrag interpretiert die musikalisch gemeinten Einsätze und Dauern. Take-Zugehörigkeit, Taktgrenzen, Kanal, Tonhöhe, Velocity und Stummschaltung bilden den Kontext. Nur konservativ geprüfte Vorschläge werden als `disp_pos`-/`disp_len`-Notationseigenschaften übernommen. Unsichere Zuordnungen, sehr kurze Vorschläge und stark abweichende Werte bleiben unverändert; vorhandene manuelle Anzeigeoffsets werden nicht überschrieben. Es gibt keinen automatischen Retry und keine bezahlte Kontrollanfrage.

### Automatische Schlüsselwahl

Die Schlüsselwahl erfolgt lokal und ohne zusätzlichen KI-Aufruf für **jeden dargestellten Track**, aggregiert über seine dargestellten Takes. Sie bewertet die Tonlagen und die gewichtete Zahl nötiger Hilfslinien. Stumme Noten beeinflussen die Entscheidung nicht; Tracknamen dienen nicht als Instrumentenheuristik.

- Hohe Stimmen erhalten vorzugsweise Violin-, tiefe Stimmen Bassschlüssel. Bei nahezu gleichen Ergebnissen bleibt ein geeigneter bestehender Schlüssel erhalten.
- Bereits verwendete Alt-/Tenorschlüssel bleiben bestehen, wenn sie zur Tonlage passen. Oktavierte Schlüssel, vorhandene Schlagzeug-/Einliniensysteme und Chart-Konfigurationen werden erhalten.
- Reines GM-Schlagzeug auf MIDI-Kanal 10 erhält einen Schlagzeugschlüssel.
- Eine Einzelstimme wird nicht wegen ihres großen Tonumfangs in ein Klaviersystem verwandelt. Ein schon bestehendes Violin-/Bass-Doppelsystem bleibt nur bei klar gleichzeitig erklingenden breiten Akkorden erhalten; ein neues Doppelsystem wird nicht erzeugt.

Technisch wird nur der Schlüsselwert der **TRACK-eigenen SCORE-Zeile** geändert; die anderen SCORE-Felder und verschachtelte Item-/Plugin-/Source-Daten werden erhalten. Vorherige Track-Zustände sind gesichert. Nach dem Schreiben werden alle MIDI-Takes auf den betroffenen Tracks, einschließlich nicht dargestellter Items, über GUIDs erneut aufgelöst und ihre Puffer/Zeitbezüge geprüft. Diese Auflösung berücksichtigt, dass Track-Zugriffe Item-/Take-Pointer ersetzen können.

REAPER 7.84 ordnet SCORE-Zeilen beim Einlesen um und ergänzt gegebenenfalls `LANEREC -1 -1 -1 0`. Ausschließlich diese im echten REAPER beobachteten Normalisierungen werden toleriert; sämtliche SCORE-Werte und die übrigen Track-Bytes bleiben Vergleichsgrundlage. Unbekannte, mehrdeutige oder mindestens 4 MiB große Track-Zustände werden abgewiesen. Das interne SCORE-Schema ist keine öffentlich dokumentierte stabile Clef-API; die bekannte Struktur ist deshalb eng geprüft und nach dem Schreiben kontrolliert.

### Zoomfaktor

Die Hauptaktion aktiviert die native Notationsansicht und proportionale Abstände. Anschließend setzt sie **absolut** einen horizontalen Zoom: je nach größter Notendichte eines dargestellten Takts 80, 90, 105 oder 120 Pixel pro Viertelnote, multipliziert mit dem gespeicherten Zoomfaktor. Standard ist **100 %**, einstellbar sind **50–250 %**. Wiederholtes Anwenden summiert den Zoom nicht auf. Bei Sekunden-Zeitbasis erfolgt die Umrechnung mit dem Tempo am Edit-Cursor.

Die zusätzliche Aktion **Native Notation Studio - Zoomfaktor einstellen** fragt nur den Prozentwert ab, wendet ihn direkt an und merkt ihn für spätere Aufrufe. Sie benötigt **keinen API-Schlüssel, keinen KI-Aufruf und keine MIDI-Schreiboperation**. Beide Lua-Dateien müssen im selben Ordner liegen. Der reine Zoom funktioniert auch bei geloopten, gepoolten oder zeitgestreckten Items; deren Bearbeitungssperren gelten nur für die Notationsanalyse. Die Eingabe kann abgebrochen werden; fehlgeschlagene Zoom-Übernahmen stellen nach Möglichkeit den vorherigen Wert wieder her und melden ein Scheitern ausdrücklich.

Der Faktor betrifft die horizontale Notenskalierung. Er ist kein Betriebssystem-/Schriftzoom und garantiert nicht exakt vier Takte pro Fenster. Vertikaler System-/Seitenzoom bleibt REAPER überlassen. Anzeigequantisierung und Mindestnotenlänge werden nicht automatisch verändert. Der Zoom ist eine Editor-Einstellung; Schlüssel und Rhythmusmetadaten liegen gemeinsam im Projekt-Undo-Block, der Zoomfaktor wird separat gespeichert.

## Einrichtung

1. `Native-Notation-Studio.lua` und optional `Native-Notation-Studio-Zoom.lua` in den dauerhaften **Scripts**-Ordner des REAPER-Ressourcenverzeichnisses kopieren. Über **Actions → Show action list**, Bereich **MIDI Editor**, **ReaScript → Load** die gewünschten Dateien laden. Beide Aktionen lassen sich einem Toolbar-Knopf oder Shortcut zuweisen.
2. Für die Hauptaktion muss REAPER die Umgebungsvariable `OPENAI_API_KEY` sehen. Der Schlüssel wird nicht in Skript oder Auftragsdateien gespeichert. Ein Browser-Abonnement ersetzt den API-Zugang nicht. Standardmodell ist die bereits verwendete Kennung `gpt-5.4`; optional einmalig über `NATIVE_NOTATION_MODEL` ändern. Der tatsächliche Modell-/Providerzugang wurde nicht live abgefragt. Die Zoom-Aktion braucht diese Einrichtung nicht.
3. Windows: System-PowerShell und `%SystemRoot%/System32/curl.exe`. macOS: `/bin/sh` und `/usr/bin/curl`. curl muss `--fail-with-body` unterstützen. Fehlender Zugang, Programme oder Optionen führen zum Fehler ohne Projektübernahme. Keine zusätzlichen REAPER-Erweiterungen erforderlich.

Es werden keine Composition-Studio-Einstellungen verwendet. Der Entwickler-Testhook `NativeNotationStudio/TestResponseFile` muss im normalen Betrieb leer sein; ein gesetzter Pfad ersetzt den Provider durch eine vorbereitete DISPLAY-Datei. Die automatisierten Tests setzen diesen Hook nur in einer isolierten Simulation bzw. einem separaten REAPER-Testprofil.

## Prüfnachweise

[Vollständiges aktuelles Prüfprotokoll](NATIVE-NOTATION-STANDALONE-RESULTS.txt).

**Simulation:** 138 Standalone-Tests unter Lua 5.4 und zusätzlich TeX-Lua/Lua 5.3 bestanden. Die vollständigen Produktionsdateien werden geladen. MIDI-Fixtures enthalten expressive Einsätze, Überlappungen, mehrere Kanäle, Note-Off-Velocity, Pedal, SysEx, Selektions-/Mute-Flags, negative Deltas, vorhandene Artikulation und leere Endereignisse. Verglichen werden sämtliche Nicht-Notationsevents mit absoluten Ticks, Flags und Nachrichtenbytes.

Zusätzlich geprüft: alle dargestellten Takes unabhängig von Notenauswahl, echte vs. nur aktivierte Loop-source-Option, individuelle vs. tatsächlich mehrfach verwendete Pool-GUIDs, JSON/Unicode/Surrogatpaare, Responses-Struktur, Größen-/Zeitgrenzen, Abbruch, veraltete Quellen/Sichtbarkeit, Schreib-/Rücklesefehler, Mehr-Take-Rollback und expliziter Rollbackfehler. Neue Prüfungen sichern Schlüssel je Track, Einzelstimmen ohne Klaviersystem, Erhalt anderer SCORE-Felder und verschachtelter Daten, GUID-Auflösung nach ersetzten Pointern, Schutz versteckter Takes, gemeinsame Rücknahme, feste Zoomfaktoren, Tempo-Umrechnung, Zoomfehler und Laden der zusätzlichen Zoom-Aktion.

**Echter Unix-Prozess:** Drei tatsächlich ausgeführte Wrapperprüfungen mit lokalem curl-Ersatz, Exitcodes 0/22/28 und problematischen Pfadzeichen bestanden.

**Echter REAPER 7.84/Linux x86_64:** Vollständiger Standalone-Ablauf in separater Instanz mit temporärem Profil, zwei dargestellten Tracks und vorbereiteter DISPLAY-Antwort bestanden. Normale MIDI-Items hatten `Loop source = 1`; deren einmalige Pool-Identitäten wurden korrekt akzeptiert. Vier Anzeigeoffsets, Bassschlüssel für den tiefen und Violinschlüssel für den hohen Track übernommen. Die Performance-Ereignisse blieben identisch. Native Zoom-API: 100 % = 81920 bei QN-Zeitbasis; 150 % wiederholt = 122880 ohne Aufsummierung; Rückkehr auf 100 % erfolgreich. **Echtes Undo stellte Original-MIDI und beide ursprünglichen Schlüssel wieder her; echtes Redo stellte die neue Schlüsselwahl wieder her.**

Keiner dieser Tests hat eine externe KI-Anfrage gestellt oder API-Kosten verursacht. Kein Hörvergleich und keine visuelle Bewertung des Notenbilds; native Windows-/macOS-Abnahme und musikalische Qualität echter Modellantworten bleiben offen.

### Tests selbst ausführen (Entwicklung)

- Offline-Suite: `python tools/test_native_notation_standalone.py`.
- Lua 5.4 ohne pip-Abhängigkeiten auf einem System mit liblua5.4: `python tools/run_lua54.py tests/test_native_notation_standalone.lua`.
- Optional echter REAPER: `python tools/test_native_notation_reaper.py /voller/pfad/zu/reaper`. Der Runner startet ausschließlich einen eigenen Prozess mit leerem Projekt und temporärem Profil; das Lua-Testskript verweigert nicht leere Projekte. Kein Download und kein Providerzugriff. Der Runner beendet danach nur seinen eigenen Testprozess.

## Ein einziger abschließender Praxistest

Eine gespeicherte Projektkopie mit etwa vier Takten einer expressiven Passage und zwei oder drei dargestellten Tracks verwenden, darunter eine hohe und eine tiefe Stimme; zusammen höchstens 500 Noten. Einen weiteren Track ausgeblendet lassen. **Einmal „Lesbare Notation erstellen“ ausführen**, während der Analyse keine Projektbearbeitung vornehmen.

Danach denselben Ausschnitt ansehen und anhören: passende Schlüssel pro dargestelltem Track, lesbarere Rhythmen und Abstände, ausgeblendeter Track unverändert, gleiche Wiedergabe. Einmal Undo/Redo prüfen. Falls die Darstellung zu groß oder klein ist, lässt sich innerhalb dieses gebündelten Praxistests der Faktor über die reine Zoom-Aktion ändern, ohne die KI nochmals aufzurufen. Ergebnis und gegebenenfalls ein Screenshot derselben Takte genügen; keine weiteren Benutzertest-Runden sind vorausgesetzt.

## Grenzen und Fehlerbehandlung

- Noch keine vollständige Stimmen-/Handrekonstruktion, keine neu erzeugten Vorschlagsnoten und keine druckreife Partiturerzeugung. Schlüsselwahl ist eine lokale, nachvollziehbare Tonlagenheuristik, keine Instrumentenerkennung. Manuelle Schlüsselwechsel innerhalb eines Stücks werden erhalten und nicht automatisch neu gesetzt. Die musikalische Wirkung einer echten KI-Antwort ist nicht bewiesen.
- Höchstens 500 Noten pro Gesamtauftrag. Bei Überschreitung vollständiger Abbruch vor API-Aufruf, keine stille Teilbearbeitung.
- Tatsächlich wiederholte Quellen, tatsächlich mehrfach verwendete Pool-Identitäten und Take-Playrate ungleich 1 bleiben abgewiesen. Eine einzelne nichtnullige Pool-GUID ist kein Beweis für Pooling: Alle MIDI-Items können eine eigene solche Identität besitzen. Zum Quellschutz werden die MIDI-Pool-Referenzen im gesamten Projekt gezählt. Loop-Quellen mit eigenem Tempo oder unklarer Länge bleiben abgewiesen.
- Esc, Fenster schließen oder anklicken verhindert die Übernahme. Ein bereits gesendeter Serverauftrag wird dadurch nicht storniert und kann Kosten verursachen; der Hintergrundprozess darf bis zu seinem 90-Sekunden-Limit weiterlaufen. Es gibt keinen Retry. Projektänderungen während der Analyse verwerfen das Ergebnis.
- Regulärer Prozessabschluss entfernt die Auftragsdateien. Nach Absturz, erzwungenem Abbruch oder Zeitlimit können schlüsselfreie `NNS-*`-Diagnosedateien verbleiben. `NativeNotationStudio-notes.txt` und `NativeNotationStudio-prompt.txt` bleiben im Ressourcenverzeichnis und werden beim nächsten Aufruf ersetzt.
- Scheitert eine Schreiboperation, werden angefasste Track-Zustände und MIDI-Puffer zurückgeschrieben und geprüft. Ein Fehler bei dieser Wiederherstellung wird ausdrücklich gemeldet und auf REAPER Undo verwiesen; er wird niemals als Erfolg behandelt.

API-Grundlage: [offizielle ReaScript-Dokumentation](https://www.reaper.fm/sdk/reascript/reascripthelp.html), insbesondere `MIDIEditor_SetSetting_int`, `MIDIEditor_GetSetting_int`, `MIDIEditor_EnumTakes`, Track-State-, MIDI- und Undo-Funktionen. Die Schlüsselzuordnung wurde zusätzlich gegen die bestehende Projektimplementierung und den echten REAPER-Zustand geprüft; das interne SCORE-Format ist nicht als öffentliche stabile API dokumentiert.
