# Composition Studio – verbindliche Arbeitsregeln

Diese Datei enthält die dauerhaften Arbeitsregeln für die Entwicklung von **Composition Studio**. Sie gilt unabhängig davon, auf welchem Gerät oder in welchem Chat die Arbeit fortgesetzt wird.

## Grundregel

**GitHub ist die einzige verbindliche Quelle für den technischen Entwicklungsstand.**

Chatverläufe, ChatGPT-Erinnerungen, lokale Gesprächszusammenfassungen und Aussagen aus früheren Sitzungen dürfen niemals ungeprüft als aktueller Projektstand verwendet werden.

Bei einem Widerspruch zwischen Chat und Repository gilt der aktuelle GitHub-Stand.

## Vor jeder Entwicklungsarbeit

Bevor Code geändert, ein neuer Entwicklungsweg begonnen oder eine technische Aussage über den aktuellen Stand gemacht wird:

1. `AGENTS.md` lesen.
2. `PROJECT_STATUS.md` lesen.
3. aktuellen Repository-Stand prüfen: Branches, relevante Commits und aktuelle Builds/Workflows.
4. feststellen, welcher Stand tatsächlich der jüngste ist.
5. erst danach die Arbeit fortsetzen.

Ein älterer Chat darf niemals dazu führen, dass auf einen früheren Entwicklungsstand zurückgesprungen oder bereits geleistete Arbeit überschrieben wird.

## Nach jeder abgeschlossenen Entwicklungsphase

Eine Entwicklungsphase gilt erst als abgeschlossen, wenn der gemeinsame GitHub-Stand aktualisiert wurde.

Dazu gehören:

1. Code und sonstige Projektänderungen in GitHub sichern.
2. Build bzw. automatisierbare Prüfungen durchführen.
3. `PROJECT_STATUS.md` auf denselben tatsächlichen Stand bringen.
4. dort mindestens dokumentieren:
   - relevanter Branch und Commit,
   - Build-/Testergebnis,
   - nachgewiesen funktionierende Funktionen,
   - bekannte nicht funktionierende oder noch ungeprüfte Funktionen,
   - nächster technischer Schritt.

Build-Erfolg und praktischer Funktionsnachweis sind ausdrücklich getrennt zu dokumentieren.

## Geräte- und Chatwechsel

Ein Wechsel zwischen Mac, Android, iPad, Web, Work oder einem neuen Chat erfordert keine Übertragung des Chatverlaufs.

Der neue Chat rekonstruiert den Projektstand ausschließlich aus GitHub nach dem oben beschriebenen Verfahren.

Damit darf fehlende Chat-Synchronisation keinen eigenen Entwicklungszweig erzeugen.

## Parallelentwicklung

Es soll nur **einen eindeutig dokumentierten aktiven Entwicklungsstand** geben.

Werden experimentelle Branches verwendet, müssen Zweck und Verhältnis zum aktiven Stand eindeutig dokumentiert sein. Ein experimenteller oder älterer Branch darf nicht stillschweigend zum neuen Ausgangspunkt werden.

## Dauerhaft verbindliche Projektentscheidungen

Solange sie nicht ausdrücklich geändert und anschließend in GitHub dokumentiert werden:

- Zielprodukt ist **Composition Studio by Klangwerke**.
- Der freigegebene helle Composition-Studio-GUI-Entwurf bleibt das visuelle Ziel und wird nicht wegen technischer Neuaufbauten neu erfunden.
- Grundarchitektur: **Composition Studio → EngineBridge → MAGDA**; MAGDA soll möglichst wenig verändert werden.
- Funktion vor Umfang: zuerst belastbare Funktionsketten, dann Erweiterung.
- Keine Attrappen als Funktionsnachweis.
- Keine Klecker-Versionen zur Abnahme.

## Bedeutung der Statusdateien

- `AGENTS.md` = dauerhafte Arbeits- und Synchronisationsregeln.
- `PROJECT_STATUS.md` = aktueller technischer Projektstand und nächster Schritt.

`PROJECT_STATUS.md` muss deshalb mit der Entwicklung mitgeführt werden. Eine veraltete Statusdatei ist ein Projektfehler und muss vor weiterer Entwicklungsarbeit korrigiert werden.
