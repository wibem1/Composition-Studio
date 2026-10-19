# Composition Studio 1.1.0 · Testversion · 19.10.2026

In Composition Studio **Studio-Menü → Update** wählen. Die vorhandene Updatefunktion lädt und prüft die neue `Composition Studio.lua`, sichert die bisherige Datei und startet das Skript neu. Ein manueller Dateiaustausch ist nicht nötig.

Neue Bedienung:

- Kompositions- und Bearbeitungsergebnisse werden als Vorschlag gespeichert. Erst **Änderungen anwenden** erzeugt MIDI.
- Nach einer Analyse ein gewünschtes Modell wählen und **Überarbeitung aus Analyse erstellen** drücken. Das vorhandene Auftragsfeld kann konkrete Änderungswünsche enthalten. Dies ist ein neuer KI-Aufruf; das Laden aus dem Verlauf ruft keine KI auf.
- **Verlauf** zeigt gespeicherte Ergebnisse zum erneuten Laden. Sie liegen zusätzlich zu den Projektmetadaten unter REAPER-Ressourcen/CompositionStudioResults. Beim Projektwechsel werden die passenden Ergebnisse geladen.
- **Übergang** wechselt zwischen Schluss erhalten und zwei/drei/vier freigegebenen Schlusstakten. Für eine Fortsetzung alle zum Stück gehörenden MIDI-Items auswählen. Eine Verlängerung um 16 Takte mit zwei Übergangstakten erzeugt zwei Ersatztakte plus 16 neue Takte.
- Der Übergang entsteht als neue Fassung mit erhaltenem Anfang. Das Original bleibt hörbar vorhanden: Zum Vergleich die gewünschte Fassung solo schalten. Der gesamte Import ist ein Undo-Schritt.
- Im Modellmenü **Verfügbare Modelle aktualisieren** wählen. Vorhandene Anbieter-Keys werden verwendet; die Liste bleibt beim nächsten Start erhalten.

Fortsetzungen verwenden wie bisher LilyPond unter Windows. Dessen Pfad im Studio-Menü einstellen. Taktwechsel, überspannende Noten oder Sustain und uneindeutige Spurzuordnung im Übergang werden abgelehnt. Änderungen am Original nach dem KI-Auftrag blockieren das Anwenden. Erneut einlesen bzw. einen neuen Auftrag starten.

Technisch geprüft mit Lua 5.4 und simulierten REAPER-Schnittstellen. Der praktische Test in REAPER und das Abhören stehen aus. Die Fassung wird über den bestehenden Online-Updater ausgeliefert.
