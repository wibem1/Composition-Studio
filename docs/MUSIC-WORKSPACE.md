# Musikgedächtnis, Werkzusammenhang und erster Song-Aufbau

**Status:** Implementierter Entwicklungsstand auf `feat/music-workspace-20261105`,
noch nicht veröffentlicht. Die installierte Testfreigabe 1.1.11 enthält diese
Erweiterung noch nicht. Keine Übernahme der getrennten Notationsarbeit.

## Benutzung im vorhandenen Auftragsfeld

1. `Merke musikalisch: Das Anfangsmotiv soll erkennbar bleiben und die Begleitung schlicht.`
2. MIDI-Items, Spuren oder editierbare Einzelnoten auswählen.
3. `Analysiere den Werkzusammenhang.` oder
   `Prüfe den musikalischen Gesamtzusammenhang.`
4. `Entwickle die Auswahl zu einem vollständigen Song.`
5. Die angezeigte Songstruktur prüfen; erst **Änderungen anwenden** schreibt die
   Fassung auf zusätzliche Spuren. Für den Hörvergleich die neuen Spuren solo
   schalten: Originalspuren werden nicht automatisch stummgeschaltet.

`Zeige Musikgedächtnis` zeigt die aktiven musikalischen Entscheidungen;
`Lösche Musikgedächtnis` setzt diese ausdrücklich zurück. MIDI und frühere
Vorschläge werden dabei nicht gelöscht. Ohne ausgewähltes Quellmaterial wird
kein Song angefordert. Ausdrücklich markierte Noten bzw. Arrangement-Items
werden bei fehlender Auswahl nicht durch ganze Spuren ersetzt. Ein expliziter
Partitur-/Piano-Roll-Kontext nutzt die bestehenden read-only Auswahlfunktionen.

## Was diese erste Erweiterung tatsächlich leistet

| Bereich | Implementiertes Verhalten |
| --- | --- |
| Music Model | Versionierter, serialisierbarer Performance-Snapshot mit Parts, Ereignis-IDs, Quell-Item-Referenzen, Timing, Pitch, Velocity, Kanal und Tempo-/Taktkontext; keine Hosthandles |
| Music Memory | Nutzerentscheidungen pro REAPER-Projekt, gespeichert unter `MusicMemoryV1`; aktueller Auftrag hat Vorrang; Entscheidungen gehen in musikalische Folgeaufträge ein |
| Music Analysis / Quality Review | Bestehende Analyse erhält zusätzlich das gesamte ausgewählte Material im strukturierten Modell sowie den expliziten Auftrag, Motive, Phrasen, Stimmenrollen, Harmonik, Form und Entwicklung im Zusammenhang zu beurteilen |
| Song Construction / Arrangement | Ein expliziter Song-Auftrag erzeugt eine vollständige neue JSON-Fassung plus Abschnitte, Stimmenrollen und Formbeziehungen in einem Anbieteraufruf; bestehende Übersetzung und Commitlogik werden wiederverwendet |
| Workflow | Antwort technisch validieren → Vorschlag und Kontext dauerhaft speichern → Struktur anzeigen → Quelle erneut prüfen → ausdrücklich anwenden; keine automatische Übernahme |

Das Modell bezeichnet MIDI ausdrücklich als **Performance**. Es quantisiert
keine Einsätze/Dauern und behauptet daraus keine sichere Notation oder
motivische Interpretation. Parts entsprechen zunächst den Quellspuren, nicht
einer bewiesenen unabhängigen musikalischen Stimmtrennung. Ereignis-IDs gelten
für den erfassten Snapshot, nicht als dauerhafte Note-IDs nach beliebiger
Bearbeitung. Sourceguard und native Bindings sichern die Übernahme weiterhin.

Das Gedächtnis speichert zunächst ausdrücklich eingegebene musikalische
Entscheidungen. Automatische Motivgraphen und ein selbständig fortgeschriebenes
Werkgedächtnis sind weitere Ausbauschritte. Form- und Rollenbeschreibungen der KI
werden mit dem Songvorschlag gespeichert; sie sind Interpretationen und kein
unabhängiger Nachweis musikalischer Qualität. Die Gesamtprüfung ist ein
expliziter Analyseauftrag, keine automatische Verbesserungsschleife.

## Musikalische und technische Verträge

`music/model.lua` liefert `music_model.capture(items,tempo,num,den)` und
`validate_song(song,snapshot)`. Der Input trägt `Composition-Music-1`, das
Songresultat `Composition-Song-1`. Der Song erweitert das vorhandene
JSON-Partiturschema mit `sections`, optional `relationships` und Spur-`role`.
Die eigentlichen Noten, Programme, Kanäle und CC gehen durch den bestehenden
`engine_translate_json`-Adapter und die vorhandene CS-Operationsplanung.
Es entsteht keine zweite Composition Engine und keine neue MIDI-Engine.
Composition-Engine main `8b062ea6deea9e7421c62b0dd415cf652b47828a` wurde vor
Umsetzung erneut gelesen; Runtime und gemeinsamer Workflow-Kern bleiben
unverändert. Die vorhandenen nativen Analyse-/Kompositionspfade werden erweitert,
die JavaScript-Runtime wird nicht stillschweigend eingeschaltet.

- Alle Songoperationen erzeugen neue Spuren. CSMETA wird aus dem validierten
  Übergabeformat entfernt, damit die vorhandene Tempo-/Taktkarte erhalten bleibt.
  Abweichendes Projekttempo oder Taktmaß sowie neue `tempoEvents` werden abgewiesen.
- Abschnitte müssen lückenlos ab QN 0 beschreiben, wo das erzeugte Werk liegt.
  Die neue Fassung beginnt wie bisherige neue Kompositionen bei QN 0.
  Songnamen, IDs, Rollen und Formreferenzen werden auf zulässige Werte geprüft.
- Controller/Pedal bleiben innerhalb des beschriebenen Werkumfangs; benutztes
  Sustain muss wieder gelöst werden. Nicht unterstütztes Pitch Bend wird nicht
  still verworfen, sondern abgewiesen.
- Es gibt keine verpflichtende Songform, Abschnittslänge oder Komplexitätsregel.
  Die KI trifft die musikalischen Entscheidungen aus Auftrag und Quellmaterial.
  Abschnittsweise Mehrfachgenerierung, automatisches Nachbessern und musikalische
  Hörfreigabe sind nicht Bestandteil dieses ersten begrenzten Songpfads.
- Der neue Vorschlag speichert den Performance-Snapshot, die verwendeten
  Gedächtnispräferenzen und die KI-Strukturbeschreibung. Projektwechsel,
  veränderte Quellen, fehlende Bindings oder mehrfaches Anwenden blockieren
  Schreibzugriffe. API-Schlüssel werden nicht in diesen Daten gespeichert.

## Speicherung, Grenzen und Kosten

Projekt speichern, damit `MusicMemoryV1` nach erneutem Öffnen erhalten bleibt.
Das Gedächtnis wird pro Zugriff aus dem aktuellen Projekt gelesen; es gibt
keinen projektübergreifenden Cache. Unlesbare Daten werden nicht still gelöscht:
Musikaufträge werden mit Meldung angehalten, die lokale Löschanweisung bleibt
verfügbar. Frühere Vorschläge behalten ihre historischen Kontextdaten.

Technische Obergrenzen: 24 Nutzerentscheidungen mit jeweils höchstens 600
UTF-8-Bytes, höchstens 20000 Bytes kodiertes Gedächtnis; 2500 Quellnoten,
32 Quellparts, 256 Tempo-/Taktmarker und 256000 Bytes Quellsnapshot. Das Ergebnis
ist auf 32 Spuren, 32 Abschnitte, 20000 Noten, 20000 Controllerereignisse,
64 Formbeziehungen und 4096 QN begrenzt. Diese Grenzen sind keine musikalischen
Zielwerte. Übergröße führt zu einer Meldung, nicht zum stillen Abschneiden.

Speichern/Anzeigen/Löschen des Gedächtnisses kostet keinen Anbieteraufruf.
Jede neue Werkzusammenhang-Analyse und jeder explizite Song-Aufbau hat **genau
einen** Anbieteraufruf, ohne zusätzlichen Controller-, Rahmen-, Übersetzungs-
oder Retry-Aufruf. Vorhandene Providerzeitlimits, Tokenlimitfehler und
Kostenanzeige bleiben aktiv. Dies begrenzt die Zahl der Aufrufe, garantiert
aber keinen Geldbetrag; tatsächliche Kosten hängen von Modell, Kontext und
Denktokens ab. Es wurden für die Entwicklung keine bezahlten KI-Tests ausgeführt.

## Prüfstatus

Der Funktionstest `tools/test_music_workspace.py` lädt die tatsächlichen
Produktionsmodule, Routing-, Launch-, Poll-, Persistenz- und Freigabefunktionen.
Nur Provider und native Schreibgrenze werden ersetzt. Geprüft sind Projekt-
isolation, lokale kostenfreie Befehle, Präferenzübergabe, Save/Reload,
Auswahlgrenzen, ungültige Antworten, unveränderte Tempo-/Taktkarte,
Sourceguard, explizite Übernahme genau einmal, Providerfehler und Projektwechsel.
Zusätzlich bestanden alle 15 Python-Suiten und drei Lua-Dateien des vollständigen
Regressionstests einschließlich Installer, Update, UI, Auswahl, Originalschutz
und Rollback. Die frühere byteweise Legacy-Prüfung bleibt nach gezieltem
Entfernen der markierten neuen Integrationspunkte aktiv.

Kein Liveprovider-/Hörtest, kein nativer REAPER-/Windows-/macOS-Nachweis. Eine
syntaktisch und technisch gültige Songantwort beweist keine musikalische
Kohärenz. Vor einer Veröffentlichung ist der Entwicklungsstand gesondert zu
prüfen; der bisherige main-Updater bleibt unverändert auf der veröffentlichten
Fassung.
