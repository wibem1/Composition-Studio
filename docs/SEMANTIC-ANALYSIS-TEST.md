# Musikalische Notationsanalyse – ein abschließender REAPER-Test

Testkandidat aus PR #12, Branch `feat/semantic-notation-analysis-20261104`, Basis 1.1.10. Keine endgültige Veröffentlichung. Der Kandidat ist auf Analyse beschränkt: Er erzeugt noch keine korrigierte Partitur und wendet keine Notationsmetadaten an.

## Installation und ein Testdurchlauf

1. Stabiles Composition Studio schließen. `Composition-Studio-Semantic-Test-Install.lua` aus diesem Branch herunterladen (Dateiendung **.lua**, nicht .txt). In REAPER unter **Aktionen → Aktionsliste anzeigen → ReaScript: Laden** laden und einmal ausführen. Der Installer legt die dauerhafte Testaktion unter **REAPER-Ressourcenordner/Scripts/CompositionStudioSemanticTest/Composition Studio Semantic Test.lua** an, registriert sie und öffnet das Fenster **Semantik-Test · Basis 1.1.10**. Die heruntergeladene Installerdatei wird danach nicht mehr benötigt. Bestehende Modell-/API-Einstellungen werden lesend übernommen; Testeinstellungen und Ergebnisverlauf sind getrennt.
2. Eine **Projektkopie** mit einem repräsentativen MIDI-Abschnitt öffnen. Im nativen MIDI-Editor (Piano-Roll oder Notenansicht) die zu untersuchenden Noten aus **vier Takten** markieren, bei Mehrstimmigkeit in den beteiligten editierbaren Takes. Den Editor geöffnet lassen. Im Semantik-Test diesen einen Auftrag absenden:

   > Analysiere die markierten Noten für eine konventionell lesbare Notation. Rekonstruiere jeden Takt musikalisch: Melodie, Bass, Begleitung, Mittelstimmen, rhythmische Absicht, echte Pausen, expressive Abweichungen und Handverteilung. Kennzeichne Unsicherheit und liefere die SEMNOTE-Zuordnungen. Verändere keine MIDI-Daten.

3. Nach der Antwort prüfen: Ist die taktweise Deutung musikalisch nachvollziehbar? Werden Unsicherheiten und Alternativen benannt? Der Abschluss zeigt **akzeptierte, verworfene, unsichere/vorläufige und nicht zugeordnete Noten** sowie **Originalprüfung: unverändert**. Fehlende SEMNOTE-Zuordnungen sind sichtbar und gelten nicht als vollständige Analyse. Bei **veraltet** muss der Durchlauf als fehlgeschlagen gewertet werden. Original anhören; es muss unverändert klingen. Testfenster schließen, die dauerhaft installierte **Composition Studio Semantic Test.lua** über die Aktionsliste erneut öffnen und im **Verlauf** die gespeicherte Analyse aufrufen. Dafür ist kein zweiter KI-Aufruf erforderlich.

Bitte als ein Ergebnis zurückmelden: **Start erfolgreich/Fehler; Analyse musikalisch brauchbar/nicht brauchbar; Abschlussmeldung; nach Neustart wieder vorhanden/fehlt.** Bei einem Problem genügt die betreffende Meldung und die betroffene Taktstelle. Kein weiterer Testauftrag und kein Update der stabilen Version sind Teil dieses Durchlaufs.

## Technische Prüfung und ihre Grenzen

- Auf dem Entwicklungsstand nach vollständigem lokalen Testlauf: **12 Lua-Dateien vollständig mit Lua 5.4 kompiliert, vier Lua-Testsuiten und 13 Python-Testsuiten bestanden**. Lua-Ausführung über `lupa==2.8`, Python 3.12, `imgui-bundle==1.93.0` für echte Dear-ImGui-Tests mit ersetzter REAPER-Anbindung.
- Reproduzierbarer Gesamtbefehl: `python tools/run_regressions.py`. Vorher `python -m pip install lupa==2.8 imgui-bundle==1.93.0`. Installer reproduzierbar mit `python tools/build_offline_installer.py` und `python tools/build_semantic_test_installer.py`.
- Produktionsfunktionen vom Auftrag über simulierte Modellantwort, Parser und echte JSON-Dateispeicherung bis zum Neuladen ausgeführt. Sichtbare Partitur und markierte Einzelnoten werden jeweils ohne zusätzlichen Controller-Aufruf analysiert. Externe Referenznoten erweitern das Zuordnungsziel nicht.
- Parser: 22 Fälle, darunter falsche/mehrdeutige Identitäten, Duplikate, nichtendliche Zahlen, unzulässige Rollen, leere Felder, Kanal 16, zusätzliche Felder und ignorierte MIDI-Schreibbefehle. Originalkanäle sind 0–15.
- Speicherung enthält die Originalnoten des Analysebereichs, akzeptierte Identitäten samt Originalwerten, abgewiesene Zeilen, Sicherheit und Abdeckungszahlen. Zwischenzeitlich veränderte Quellen werden als veraltet gekennzeichnet. Bei Speicherfehlern wird kein ungesicherter Datensatz als gespeichert angeboten; der bestehende Verlauf bleibt im getesteten Schreibfehlerfall erhalten.
- Der Analysepfad benötigt keine MIDI-/CC-/Tempo-Schreib-APIs. Die Tests lassen solche Aufrufe nicht zu. Der Originalvergleich verwendet vollständige Item-Chunks, Spuridentitäten/-namen und Tempodaten. Testinstallation, Registrierung und erster UI-Frame wurden mit echten temporären Dateien geprüft: stabile Skriptbytes, Autostartdatei, ActiveScriptPath und stabile Einstellungen bleiben erhalten; Schreib-/Umbenennungsfehler werden gemeldet.
- Weitere Regressionen: 64 Dear-ImGui-Layouts, Modellauswahl, Kosten/Denkmodus, echter curl-Transport gegen lokalen HTTP-Server, bestehende Update-/Backup-/Offline-Installationspfade, Notenauswahl und Editorintegration.
- **Ausgelassen:** echter LilyPond-Compiler (hier nicht installiert; diese Analyse verwendet ihn nicht). Kein laufendes REAPER, keine native macOS-/Windows-Abnahme und kein echter Anbieteraufruf. Keine kostenpflichtigen KI-Anfragen für die Entwicklung. Modellantworten sind bewusst Fixtures; musikalische Qualität einer echten Antwort und reale REAPER-Integration bleiben dem oben beschriebenen einen Praxistest vorbehalten.

**GitHub-Nachweis am unveränderten getesteten Quellcommit `7a1a586bac4b8a3b9ea6e9d088efadf424a7d4e1`:**

| Prüfung | Tatsächliches Ergebnis |
| --- | --- |
| [Semantische Gesamtprüfung einschließlich reproduzierbarer Installer](https://github.com/wibem1/Composition-Studio/actions/runs/41918164902) | success |
| [Modellauswahl, Layout, Offline-Installation](https://github.com/wibem1/Composition-Studio/actions/runs/41918164858) | success |
| [Notenauswahl](https://github.com/wibem1/Composition-Studio/actions/runs/41918164815) | success |
| [Score-Workspace-Brücke](https://github.com/wibem1/Composition-Studio/actions/runs/41918164796) | success |

Nach dem Sichern wurden Skript, beide Installer, Projektstand und Testanleitung erneut über GitHub gelesen und ihre Git-Blob-SHAs gegen die lokal geprüften Dateien abgeglichen: identisch. `main` blieb bei `cefc7e78a64b5bb2f0c0fc3b7f8e06c450c699db`; PR #12 blieb ungemergter Draft. Der anschließende Dokumentationscommit ändert die geprüften Programmbytes nicht.

Vollständiges lokales Prüfprotokoll: [SEMANTIC-ANALYSIS-TEST-RESULTS.txt](SEMANTIC-ANALYSIS-TEST-RESULTS.txt). GitHub Actions wiederholt den Gesamtbefehl bei Änderungen am PR. Der Python-Helfer `tools/semantic_notation.py` ist ein unabhängig getesteter Offline-Planprüfer; die REAPER-Analyse verwendet den eingebauten Lua-Parser und benötigt kein Python.

## Behobene Fehler und Status

Der vorgefundene Offline-Installer enthielt nicht die aktuellen Skriptbytes. Der Workflow-Test lud den neuen Produktionsparser nicht und brach beim Analysespeichern ab. Der Modelltransport-Test stellte keine Schlüssel im inzwischen verwendeten anbieterspezifischen Speicher bereit; seine Loopback-Verbindung ist nun zusätzlich unabhängig von HTTP-Proxy-Einstellungen. Diese Fehler sind korrigiert. Zusätzlich wurden Kanalgrenze, Rollen-/Leerfeldprüfung, Original-/Abdeckungsdaten, veraltete Quellen und Speicherfehlerrückmeldung gehärtet. Der unabhängige Python-Prüfer weist nun auch NaN/Infinity und mehrere fehlerhafte Datenformen zurück.

Der Testinstaller verwendet eine separate Namenskennung, temporäre Dateien und Ergebnisse. Er überschreibt keine stabile Installation und installiert keinen Autostart. Anwendung, Revision und reguläres Update sind im Kandidaten gesperrt. Die Basisversionsnummer bleibt 1.1.10; die sichtbare Kennzeichnung unterscheidet den Kandidaten von der stabilen Anwendung. `main` bleibt unverändert. **PR #12 bleibt Draft; kein Merge und keine endgültige Veröffentlichung vor erfolgreichem Nutzer-Praxistest.**
