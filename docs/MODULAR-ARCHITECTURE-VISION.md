# Composition Studio – langfristige Zielsetzung und Modularchitektur

**Status:** Verbindliche konzeptionelle Zielsetzung, **nicht implementiert**.  
**Beschlossen:** 05.11.2026.  
**Projekt:** Weiterentwicklung des bestehenden `wibem1/Composition-Studio`; **kein neues Repository und kein neues Produkt**.

## 1. Leitbild

Composition Studio wird von einem überwiegend monolithischen REAPER-Skript zu einer modular aufgebauten, KI-gestützten Kompositionsumgebung weiterentwickelt. Die Software soll nicht nur zueinander passende MIDI-Spuren erzeugen, sondern musikalisch zusammenhängende Werke analysieren, gestalten, arrangieren, weiterentwickeln und gezielt überarbeiten können.

**Musikalische Kohärenz vor bloßer Spurkompatibilität:** Motive, Phrasen, Harmonik, Rhythmik, Stimmenfunktionen, Form, Kontraste und Spannungsverlauf sollen über Spuren und Abschnitte hinweg bewusst miteinander verbunden werden. Komplexität ist kein Selbstzweck; musikalisch sinnvolle Einfachheit, Wiederholung und Zurückhaltung sind ausdrücklich erlaubt.

REAPER ist zunächst die Referenzanwendung. Die Architektur soll später sinngemäß oder durch tatsächlich wiederverwendbare Module auch für das MuseScore-Plugin und die Maestro-App nutzbar sein. Es wird **kein** neues universelles Großframework als Voraussetzung gebaut.

## 2. Verbindliche Architekturprinzipien

1. **Weiterentwicklung statt Neuentwicklung:** Bestehendes Repository, bewährte Funktionen, Daten, Einstellungen, Updater und Arbeitsabläufe erhalten; zuerst Bestandsaufnahme, dann behutsames Refactoring.
2. **Modularer Aufbau:** Klar dokumentierte Verantwortung, Ein-/Ausgabeformate und Abhängigkeiten je Modul. Neue Module sollen sich ohne Umbau des gesamten Programms integrieren lassen.
3. **Trennung von musikalischem Kern und Host-Anbindung:** Kompositorische Entscheidungen sollen weder REAPER-MIDI-Items noch MuseScore- oder Maestro-API-Befehle unmittelbar voraussetzen. Host-Adapter übernehmen Datenaustausch, Darstellung, Auswahl, Commit/Undo.
4. **Gemeinsames Musikmodell:** Musik als Werk/Abschnitte/Stimmen/Instrumente/Noten/Ereignisse/Motive/Formbeziehungen abbilden; bewusst zwischen *musikalischer Struktur*, *Notation* und *Aufführung* unterscheiden. Unsicherheit der Interpretation bewahren, insbesondere bei expressivem MIDI.
5. **Konzeptuelle vor binärer Wiederverwendung:** Datenverträge, Algorithmen und Tests plattformübergreifend gestalten. Identischer ausführbarer Code ist nur dort Ziel, wo Laufzeit, Abhängigkeiten und APIs es rechtfertigen.
6. **Vorhandene Composition Engine beachten:** `wibem1/Composition-Engine` und dessen tatsächlich freigegebene APIs prüfen. Keine zweite konkurrierende Engine oder stillschweigende Übernahme nur aufgrund einer höheren Versionsnummer.
7. **Freies kompositorisches Denken:** Die KI trifft musikalische Entscheidungen entsprechend dem Benutzerauftrag und dem Werkzusammenhang. Keine verpflichtenden Acht-Takt-Variationen, vorgegebene Standard-Songform oder mechanischen Komplexitätsregeln.
8. **Strukturierter Modulaustausch:** Neben Textanweisungen maschinenprüfbare musikalische Daten, Referenzen, Vorschläge und Änderungen verwenden; Quelle, Zielbereich und nicht zu verändernde Teile eindeutig unterscheiden.
9. **Sichere, nachvollziehbare Ausführung:** Originalschutz, explizite Übernahme, Undo, Diagnose, begrenzte API-Kosten, Wiederherstellbarkeit und reproduzierbare Tests erhalten.
10. **Kleine Entwicklungsschritte:** Bei der Modularisierung zunächst keine absichtliche Änderung des musikalischen Verhaltens. Nach jedem Schritt belegte Regressionstests; REAPER-Praxisprüfung vor Produktfreigabe.

## 3. Zielmodule und Verantwortlichkeiten

| Bereich | Verantwortung | Einordnung |
| --- | --- | --- |
| Core | Start, Lebenszyklus, Modulregistrierung, gemeinsame Schnittstellen | Infrastruktur |
| Host Bridge / REAPER | Auswahl, Tracks, Items, MIDI, Tempo, Projektzustand, Undo, UI-Anbindung | Host-spezifisch |
| AI Interface | Anbieter, Modelle, API-Kommunikation, Budget, Diagnose | Wiederverwendbare Infrastruktur |
| Music Model | Kanonische musikalische Daten und strukturierte Änderungsoperationen | Gemeinsamer Kern |
| Music Analysis | Phrasierung, Stimmen, Motive, Harmonik, Rhythmus, Form und Beziehungsanalyse | Musikalischer Kern |
| Composition | Neue musikalische Inhalte entwickeln; technische Übersetzung separat halten | Musikalischer Kern |
| Arrangement | Rollen und Zusammenwirken von Instrumenten, Dichte, Kontrast, Übergänge | Musikalischer Kern |
| Editing | Gezielte Änderungen auf Basis validierter Aufträge und Originalschutz | Kern + Host-Commit |
| Music Memory | Werkbezogene Motive, Beziehungen, Entscheidungen, Abschnittsidentitäten und Historie | Musikalischer Kern |
| Workflow | Planung und Koordination mehrstufiger Schritte, Status und begrenzte Prüfzyklen | Gemeinsamer Kern |
| Musical Form & Development | Formale Entwicklung längerer Werke ohne starre Formschablonen | Musikalischer Kern |
| Song Construction | Spezialisierung für vollständige Songs: Abschnitte, Übergänge, Arrangement, Dramaturgie | **Spätere Erweiterung** |
| Quality Review | Kritische musikalische Gesamtprüfung und gezielte Verbesserungsvorschläge | Musikalischer Kern |
| Notation | Spätere Integration der separat laufenden Notationsentwicklung | **Vorerst zurückgestellt** |
| Diagnostics | Technische Prüfungen, nachvollziehbare KI-Aufträge/Ergebnisse, Fehlerdiagnose | Infrastruktur |

Die Tabelle ist ein **konzeptioneller Zuschnitt**, keine Vorgabe, sofort für jeden Eintrag eine eigene Datei oder einen Prozess zu erzeugen. Endgültige Modulgrenzen ergeben sich aus Codeinventar und Abhängigkeitsanalyse.

## 4. Musikalisches Datenmodell – Entwurfsanforderungen

- Werk, Satz/Abschnitt, zeitliche Position, Takt-/Tempoereignisse und strukturierte Abschnitte (z. B. Strophe, Refrain, Bridge).
- Instrumente und unabhängige musikalische Stimmen, inklusive Funktion (führend, begleitend, antwortend etc.).
- Tonhöhen, rhythmische Positionen/Dauern, Phrasierung, Dynamik, Artikulation, Controller und Interpretationsinformationen.
- Motive samt Varianten und Bezügen zwischen Stimmen und Abschnitten; Harmonik und Formbeziehungen.
- Trennung von **kompositorisch gemeinter Struktur**, **lesbarer Notation** und **expressiver Aufführung/MIDI**; keine pauschale Gleichsetzung.
- Referenzen auf Originalelemente, Auswahlbereiche, Vorschläge, Änderungsoperationen und prüfbare Invarianten.
- Versioniertes, serialisierbares Format und Adapter für REAPER; später für MuseScore und Maestro, unter Berücksichtigung der jeweiligen API-Grenzen.

Ein erster Schnitt muss nur die aktuell tatsächlich benötigten Daten abbilden; weitere Eigenschaften sollen versioniert erweiterbar sein.

## 5. Zielbild Song Construction

Ein Nutzer kann aus einem bestehenden 8-taktigen Loop bzw. mehreren zusammenpassenden Spuren einen vollständigen Song entwickeln lassen. Die KI betrachtet die Stimmen **als zusammenhängende Komposition** und bewertet zunächst, ob sie lediglich kompatibel nebeneinanderstehen oder eine gemeinsame musikalische Idee tragen.

Das Songmodul koordiniert statt zu duplizieren:
1. Gemeinsame musikalische Analyse und Identifikation tragender Ideen.
2. Werkbezogenes, revidierbares musikalisches Konzept.
3. Aus dem Material entwickelte Form und Dramaturgie, nicht erzwungenes Standardraster.
4. Abschnittsweise Komposition, Variation und motivische Beziehungen.
5. Bewusstes Arrangement und Zusammenspiel der Instrumente.
6. Begrenzte musikalische Gesamtprüfung und gezielte Überarbeitung.
7. Sicheres Einfügen als REAPER-MIDI mit Projekt- und Quellschutz sowie Undo.

Die Steuerung soll ohne fortwährende Benutzerbestätigung für jeden internen Zwischenschritt arbeiten können, aber vor tatsächlichen Projektänderungen die bestehenden Schutz- und Freigaberegeln respektieren. Kosten-/Abbruchgrenzen und Wiederaufnahme müssen nachvollziehbar sein. Ziel ist **keine** bloße Verlängerung eines Flickwerks auf hundert Takte.

## 6. Hostübergreifende Perspektive

**REAPER:** zunächst vollständiger Referenzadapter für MIDI-Arrangement, Piano-Roll und vorhandene Notenansicht.

**MuseScore-Plugin:** späterer Adapter für Partitur, Stimmen, Notationselemente, Auswahl und Undo; musikalische Module und Datenverträge sollen wiederverwendbar sein.

**Maestro-App:** späterer Adapter entsprechend der tatsächlich verfügbaren Schnittstellen; keine Annahme, dass REAPER-APIs oder Lua-Module dort unverändert laufen.

Die gemeinsamen Module werden zunächst **im bestehenden Composition-Studio-Repository** entworfen und stabilisiert. Eine spätere Auslagerung in eine gemeinsam genutzte Bibliothek ist eine separate, evidenzbasierte Entscheidung. Die bereits vorhandene zentrale Composition Engine darf nicht dupliziert werden.

## 7. Abgrenzung: Notationsentwicklung

Die laufende experimentelle Notationsarbeit, insbesondere [PR #12](https://github.com/wibem1/Composition-Studio/pull/12), wird **nicht** in die erste Modularisierungsphase aufgenommen. Sie darf unabhängig weitergeführt werden; es erfolgt kein unkontrollierter Merge. Nur eine künftige Integrationsschnittstelle wird berücksichtigt. Reale Notationsqualität in REAPER bleibt eine eigene Prüfaufgabe.

## 8. Entwicklungsreihenfolge und Abnahme

**Phase 1 – Architektur-Audit (nächster einzelner Schritt):**
- Aktuelle Produktionsquellen, bestehende Tests, Aufrufketten und Schnittstellen inventarisieren.
- Zuordnung der vorhandenen Funktionen zu vorgeschlagenen Verantwortlichkeiten und Abhängigkeitsrichtungen dokumentieren.
- Beziehung zu `wibem1/Composition-Engine` technisch abgrenzen.
- Einen **kleinen, isolierbaren ersten Extraktionsschritt** mit Regressionstest bestimmen; noch keine Neuentwicklung.

**Phase 2 – Verhaltenserhaltendes Refactoring:** Module schrittweise abtrennen, zentrale Schnittstellen absichern, vorhandene Funktionen und Update-/Wiederherstellungswege erhalten.

**Phase 3 – Musikalische Grundlagen:** Gemeinsames Musikmodell, werksbezogenes Music Memory, übergreifende Analyse, Arrangement, Workflow und Qualitätsprüfung inkrementell ergänzen.

**Phase 4 – Song Construction:** Vollständige musikalische Songentwicklung auf Basis der getesteten Module; später weitere Form-Spezialisierungen nach Bedarf.

**Abnahmekriterium für die Architekturreform:** Bisherige REAPER-Funktionen verhalten sich nachweislich wie zuvor; Tests der Modulgrenzen, Projektpersistenz, Quelle/Ziel-Schutz, Undo, Update und der relevanten Host-Funktionen sind dokumentiert. Statische oder simulierte Tests sind kein Ersatz für reale REAPER-Prüfung.

## 9. Projektverwaltung

- Repository bleibt `wibem1/Composition-Studio`; `main` bleibt bis zur geprüften Freigabe geschützt.
- Die künftige Implementierung kann auf einem separaten Refactoring-Branch erfolgen; Branchanlage und Codeänderung sind **nicht** Teil dieser Konzeptdokumentation.
- `PROJECT_STATE.md` protokolliert nachgewiesene Resultate, Grenzen und jeweils einen nächsten Schritt.
- Es gelten weiterhin `wibem1/AI-Development-Standards/DEVELOPMENT_STANDARDS.md` und die Projekt-`AGENTS.md`.

## 10. Status dieser Entscheidung

Diese Datei dokumentiert eine beschlossene **Zielsetzung**, keine Behauptung, dass Module, Song Construction, Music Memory oder hostübergreifende Wiederverwendung bereits existieren. Die aktuelle Produktversion, der Updatekanal, vorhandene MIDI-Projekte und laufende PRs werden dadurch nicht verändert.
