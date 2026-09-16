# Composition Studio – verbindliche Arbeitsregeln

Diese Datei enthält die dauerhaften Arbeitsregeln für die Entwicklung von **Composition Studio**. Sie gilt unabhängig davon, auf welchem Gerät oder in welchem Chat die Arbeit fortgesetzt wird.

## Grundregel

**GitHub ist die einzige verbindliche Quelle für den technischen Entwicklungsstand.**

Chatverläufe, ChatGPT-Erinnerungen, lokale Gesprächszusammenfassungen und Aussagen aus früheren Sitzungen dürfen niemals ungeprüft als aktueller Projektstand verwendet werden. Bei einem Widerspruch zwischen Chat und Repository gilt der aktuelle GitHub-Stand.

## Vor jeder Entwicklungsarbeit

1. `AGENTS.md` lesen.
2. `PROJECT_STATUS.md` lesen.
3. aktuellen Repository-Stand prüfen: Branches, relevante Commits und aktuelle Builds/Workflows.
4. feststellen, welcher Stand tatsächlich der jüngste ist.
5. erst danach die Arbeit fortsetzen.

Ein älterer Chat darf niemals dazu führen, dass auf einen früheren Entwicklungsstand zurückgesprungen oder bereits geleistete Arbeit überschrieben wird.

## Nach jeder abgeschlossenen Entwicklungs- oder Forschungsphase

Eine Phase gilt erst als abgeschlossen, wenn der gemeinsame GitHub-Stand aktualisiert wurde. Dazu gehören:

1. Code, Forschungsunterlagen und sonstige Projektänderungen in GitHub sichern.
2. Build bzw. automatisierbare Prüfungen durchführen, soweit die Phase Code betrifft.
3. `PROJECT_STATUS.md` auf denselben tatsächlichen Stand bringen.
4. Forschungsbefunde im Forschungsjournal und im jeweiligen Katalog/Testdokument festhalten.
5. mindestens dokumentieren: relevanter Branch/Commit, Fragestellung, untersuchter Code, Testmethode, Ergebnis, nachgewiesene Funktionen, Fehler/Schwächen/offene Punkte, Schlussfolgerung und nächster Schritt.

**Build-Erfolg, technisches Verständnis und praktischer Funktionsnachweis sind getrennt zu dokumentieren.** Auch Fehlversuche werden dokumentiert, damit derselbe Irrweg nicht wiederholt wird.

## Geräte- und Chatwechsel

Ein Wechsel zwischen Mac, Android, iPad, Web, Work oder einem neuen Chat erfordert keine Übertragung des Chatverlaufs. Der neue Chat rekonstruiert den Projektstand ausschließlich aus GitHub nach dem oben beschriebenen Verfahren.

## Parallelentwicklung

Es soll nur **einen eindeutig dokumentierten aktiven Entwicklungsstand** geben. Experimentelle Branches müssen Zweck und Verhältnis zum aktiven Stand eindeutig dokumentieren. Ein experimenteller oder älterer Branch darf nicht stillschweigend zum neuen Ausgangspunkt werden.

## Dauerhaft verbindliche Projektentscheidungen

- Zielprodukt ist **Composition Studio by Klangwerke**.
- Der freigegebene helle Composition-Studio-GUI-Entwurf bleibt das visuelle Ziel und wird nicht wegen technischer Neuaufbauten neu erfunden.
- Funktion vor Umfang: zuerst belastbare Funktionsketten, dann Erweiterung.
- Keine Attrappen als Funktionsnachweis.
- Keine Klecker-Versionen zur Abnahme.

## Neue Engine-Strategie: MAGDA als Forschungs- und Referenzsystem

Die frühere Zielarchitektur `Composition Studio → EngineBridge → MAGDA` ist **nicht mehr das langfristige Ziel**.

MAGDA wird ab jetzt als **Forschungsobjekt, Referenzimplementierung und Quelle technischer Anregungen** behandelt. Ziel ist ein eigener, modularer **Composition Studio Core**, der langfristig möglichst wenig oder keinen MAGDA-Code benötigt.

Langfristiges Zielbild:

`Composition Studio → Composition Studio Core → gezielt gewählte Basistechnologien`

Dabei wird ausdrücklich untersucht, welche Funktionalität tatsächlich MAGDA-eigene Logik ist, welche nur JUCE/Tracktion oder andere Bibliotheken kapselt und welche Architektur für Composition Studio einfacher oder besser neu entwickelt werden kann.

### Forschungsprinzip pro Modul

Jedes relevante MAGDA-Modul wird so weit untersucht, dass wir:

- seine äußere API verstehen,
- seine innere Implementierung und Zustandsverwaltung verstehen,
- Abhängigkeiten und Lebenszeiten kennen,
- Thread- und Echtzeitanforderungen kennen,
- Daten- und Kontrollfluss nachvollziehen können,
- Fehlerursachen lokalisieren können,
- reproduzierbare isolierte Tests besitzen,
- und bei Bedarf gezielte Änderungen im Originalcode vornehmen könnten.

Erst dann wird entschieden: **als Referenz verwenden / vorübergehend kapseln / vereinfachen / selbst neu implementieren / nicht benötigt**.

### Änderungen an MAGDA

Falls während der Forschung ein Fehler oder eine Schwäche in MAGDA korrigiert werden muss, gilt:

`Fehlerbeschreibung → Ursache → reproduzierbarer Test → Änderung → Regressionstest → Dokumentation`

Keine undokumentierten Patches im Fremdcode.

### Basis-DAW als Labor

Die Basis-DAW ist kein Wegwerfprodukt. Sie dient als Testbank für die schrittweise entstehenden Composition-Studio-Core-Module. Ein Modul wird dort erst integriert, nachdem sein isolierter Test verstanden und bestanden ist.

## Verbindliches Qualitätsmanagement für MiniDAW und Composition Studio

Der Anwender ist **Abnehmer**, nicht primärer Fehlersucher. Ein neuer Stand wird nicht zur manuellen Abnahme vorgelegt, solange die automatisierbaren und intern reproduzierbaren Prüfungen nicht bestanden sind.

Für jede Entwicklungsstufe gelten drei Gates:

1. **Architektur-Gate:** Vor der Implementierung müssen die betroffenen MAGDA-/JUCE-/Tracktion-Module, ihre Zustände, Ownership/Lifetimes, Abhängigkeiten, Threadgrenzen sowie Daten- und Kontrollflüsse konkret verstanden und im Katalog/Journaleintrag nachvollziehbar sein. Keine Integration nach Klassenname, Vermutung oder Hoffnung.
2. **Technisches Gate:** Die begrenzte Funktion wird implementiert und mit reproduzierbaren Tests geprüft. Build-Erfolg allein ist kein Funktionsnachweis. Bestehende bestandene Tests werden als Regressionstests erneut ausgeführt.
3. **Release-Gate:** Eine Testversion für den Anwender gibt es erst, wenn die neue Funktion intern nachgewiesen ist und die bereits nachgewiesenen Funktionen weiterhin bestehen. Nicht automatisierbare Hardware-/Audio-/Plugin-Prüfungen werden ausdrücklich als solche ausgewiesen.

Fehlschläge bleiben in der Entwicklungswerkstatt. Keine Serie von Zwischenbuilds zur Fehlersuche durch den Anwender und kein Weiterbauen über einen ungeklärten Fehler hinweg.

## Verbindliches Zeitmanagement

Entwicklungsgeschwindigkeit ist ein Qualitätsmerkmal. Unnötige Vollbuilds, Neuinstallationen und Wiederholungsanalysen sind zu vermeiden.

### Cache-Prinzip

- Bereits verifizierte, unveränderte Analyseergebnisse, Abhängigkeitsstände und geeignete Build-Artefakte werden wiederverwendet.
- Unveränderte Komponenten werden nicht ohne technischen Grund erneut analysiert oder vollständig gebaut.
- Der Cache ersetzt niemals Verständnis oder Validierung: geändert/unklar = neu prüfen; verstanden/verifiziert/unverändert = wiederverwenden.
- Cache-Schlüssel müssen mindestens Quellstand/Commit und relevante Abhängigkeits- bzw. Buildparameter eindeutig machen, damit keine veralteten Ergebnisse als aktuell gelten.

### Web-first-Entwicklung

Soweit technisch sinnvoll wird während der Entwicklungsphase zuerst die vorhandene WebApp/Testoberfläche verwendet, um schnelle Iterationen ohne Intel-Mac-Kompilation und Installation zu ermöglichen. Dazu gehören insbesondere UI-/Arrangementlogik, Tracks/Clips als Modell und Darstellung, Timeline/Playhead-Darstellung, Projektmodell, Piano-Roll und andere plattformunabhängige Bedien- und Datenlogik.

Native Tests sind zwingend, sobald die zu prüfende Funktion von CoreAudio, JUCE-/Tracktion-Audiogeräten, nativer MIDI-I/O, VST3/AU-Hosting, Echtzeit-Audiographen oder anderen nicht realistisch im Browser prüfbaren Komponenten abhängt. Die WebApp darf native Funktionalität nicht vortäuschen.

### Selbstständiger Entwicklungsauftrag

Innerhalb einer ausdrücklich beauftragten Entwicklungsstufe wird selbstständig über Analyse-, Implementierungs-, Build-, Diagnose- und Korrekturschritte hinweg gearbeitet. Es ist keine Zwischenfreigabe des Anwenders erforderlich. Vorgelegt wird erst ein in sich geschlossener Testkandidat, der die oben genannten Gates bestanden hat.

## Forschungsdokumentation

- `AGENTS.md` = dauerhafte Arbeits-, Forschungs-, Qualitäts-, Zeitmanagement- und Synchronisationsregeln.
- `PROJECT_STATUS.md` = aktueller technischer Projektstand und nächster Schritt.
- `docs/RESEARCH_ROADMAP.md` = verbindliche Forschungs- und Entwicklungs-To-do-Liste.
- `docs/MAGDA_CATALOG.md` = systematischer Katalog des untersuchten MAGDA-Systems.
- `docs/RESEARCH_JOURNAL.md` = chronologisches Laborbuch mit Versuchen, Fehlern und Erkenntnissen.

Eine veraltete Statusdatei oder ein nicht dokumentierter wesentlicher Forschungsbefund ist ein Projektfehler und muss vor weiterer darauf aufbauender Entwicklung korrigiert werden.
