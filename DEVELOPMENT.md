# Entwicklung

CURRENT: Composition Studio 1.0.4
Lokale Engine: Composition Engine 2.3.1, Build 231
Runtime: Composition Studio.lua

Regeln: Vor Aenderungen den tatsaechlichen Quellstand pruefen. Keine Patch-Ketten. Jede Änderung erhält eine eindeutige Versionsnummer. Die aktive Update-Linie bleibt auf main; keine parallelen Nutzerinstallationen. SAFE wird erst nach praktischer Prüfung vergeben. Bei reiner Engine-Arbeit bleiben REAPER-UI, MIDI-Anwendung, Providerzugriff und Updater unangetastet, soweit nicht zwingend erforderlich. Technische Tests beweisen keine musikalische Qualitaet.

Zielvertrag: Nutzerauftrag -> fertige freie Komposition -> rein technische Uebersetzung -> optional kurze Beschreibung danach. Keine vorgeschaltete verbale Klangvorstellung, kein Formplan und kein musikalischer Entwurf vor der Komposition. Die technische Uebersetzung trifft keine eigenen musikalischen Entscheidungen.

Migration 2026-09-26: Der produktive REAPER-Stand wurde aus Reaper-Composition, Branch composition-studio, in dieses Repository ueberfuehrt. Das Quellrepository bleibt bis zum abgeschlossenen Vergleich als Sicherung bestehen.


## 2026-10-04 – Notationsmodul

- v1.0.5 führt den ersten kleinen Notations-Prototypen ein.
- Keine neue App und kein separater Updater: Integration in das bestehende `Composition Studio.lua`.
- Phase 1 verändert ausschließlich REAPER-Notation-Displaydaten (`disp_len`), nicht die MIDI-Performance.
- Bedienung: Studio-Menü → Notation → Auto / 1/8 / 1/16 / 1/32 / Originale Darstellung.
- Jede Änderung ist als REAPER-Undo-Block gekapselt.
- Nächste Stufen erst nach Test: dargestellte Positionen, Stimmen/Systeme, Artikulation/Spielanweisungen, KI-Notensatz, semantische Playback-Schicht, Mehrspur-SWAM, MusicXML/PDF.


## 2026-10-04 – Notation-Prototyp 0.2 / v1.0.7

Aus dem ersten Praxistest ergab sich: Darstellungsquantisierung allein reicht nicht; die Noten stehen in REAPER bei langen/dichten Items horizontal zu eng. Deshalb hat Notenbild/Spacing Vorrang vor weiteren Notationsfunktionen.

Neu:
- Lesbar machen: Zoom to content + vier horizontale Zoom-in-Schritte.
- Breiter / Schmaler: direkte horizontale Feineinstellung.
- Auswahl einpassen: REAPER-Aktion View: Zoom to selected notes/CC.
- Inhalt einpassen: REAPER-Aktion View: Zoom to content.
- Aktions-IDs werden nach Möglichkeit dynamisch aus dem MIDI-Editor-Aktionsbereich ermittelt, statt versionsabhängig fest verdrahtet zu werden.

Nächster Schritt erst nach Sichttest des Notenbilds.


## 2026-10-04 – Notation-Prototyp 0.3 / v1.0.8

Nach Sichttest von v1.0.7 wird REAPERs eigene Option **Notation: Proportional (musical) note spacing** in das Modul integriert. Sie verteilt kurze Noten großzügiger und lange Werte kompakter als das absolute Piano-Roll-Zeitraster.

- sichtbarer Schalter Musikalische Abstände
- Lesbar machen aktiviert diesen Modus automatisch
- danach Zoom to content + drei horizontale Zoom-in-Schritte
- MIDI-Daten bleiben unverändert
- Toggle-State wird über REAPERs MIDI-Editor Action Section abgefragt


## 2026-10-04 – Notation-Prototyp 0.4 / v1.0.9

Erste automatische Notensatzbereinigung. Wichtig: `disp_pos` ist als REAPER-Notationseigenschaft nachgewiesen, seine direkte numerische Semantik ist aber nicht ausreichend dokumentiert. Deshalb wird in dieser Stufe **kein eigener disp_pos-Wert geraten**. Stattdessen werden ausschließlich native REAPER-Notation-Aktionen verwendet.

Profil „Notensatz bereinigen“:
- Proportional (musical) note spacing an
- Display quantization 1/16
- Minimum display quantization note length 1/64
- Automatically detect triplets an
- Automatically voice overlapping notes an
- anschließend Ansicht einpassen + moderat vergrößern

MIDI-Performance bleibt unverändert. Alle Änderungen liegen in einem REAPER-Undo-Block.


## 2026-10-04 – v1.0.10 Updater-Fix

Praxisfehler: lokale v1.0.8 meldete trotz v1.0.9 auf main „Bereits aktuell“. Diagnose: der Raw-GitHub-Abruf lieferte offenbar eine veraltete Kopie. Der Updater verwendet nun Cache-Control/Pragma no-cache und bei verdächtig identischer Remote-Version einen zweiten Abruf über die GitHub Contents API mit Raw-Accept-Header.


## 2026-10-04 – v1.0.11 Lesbar-machen-Fix

Praxisfehler: „Lesbar machen“ führte bei jedem Klick weitere horizontale Zoom-in-Schritte aus. Das widerspricht der Bedeutung einer festen Arbeitsansicht.

Fix:
- feste Zoom-in-Serie entfernt
- Lesbar machen = musikalische Abstände aktivieren + View: Zoom to content
- wiederholtes Klicken soll dieselbe Ansicht ergeben
- Breiter/Schmaler bleibt ausschließlich manuelle Feineinstellung


## 2026-10-04 – Notation-Prototyp 0.5 / v1.0.12

Recherche bestätigt `disp_pos` als individuelle REAPER-Notationseigenschaft pro Note. Eine belastbare öffentliche Beschreibung der numerischen Einheit wurde nicht gefunden. Deshalb kein geratenes Spacing, sondern ein Mess-Prototyp:
- ausgewählte Note(n): -0.50, -0.25, 0, +0.25, +0.50, +1.00
- Notation Event bleibt am Note-On gekoppelt
- tatsächliche MIDI-Position bleibt unverändert
- erst nach Sichttest wird daraus ein automatischer Abstandalgorithmus entwickelt


## 2026-10-04 – v1.0.13 / Notation Workspace 0.1

Architekturwechsel: Notation ist keine Unterseite des Studio-Hauptfensters mehr. Der sichtbare REAPER-Notation-Prototyp (Spacing, Lesbar machen, disp_pos-Messung) wird nicht weitergeführt. Der Button „Notation“ öffnet ein separates ReaImGui-Fenster innerhalb von REAPER. Dieses Fenster ist der feste Host für den kommenden editierbaren Score-Editor.

Der Workspace 0.1 enthält bewusst noch keinen Score-Renderer. Menüs zeigen nur die geplante Funktionsstruktur und sind deaktiviert. Ziel des Tests ist ausschließlich: eigenes Fenster, unabhängiges Öffnen/Schließen und keine Regression im Hauptfenster.


## 2026-10-04 – v1.0.14 / Notation Workspace 0.2

Bedienprinzip korrigiert: keine „MIDI laden“-Funktion. Beim Klick auf „Notation“ wird die aktuelle REAPER-Auswahl automatisch in den Workspace übernommen. Mehrere ausgewählte MIDI-Items werden gemeinsam erfasst.

Erster funktionaler Datenkern: Notenliste, Notenauswahl, ±1 Halbton und Dauer halbieren/verdoppeln; Änderungen gehen direkt in das zugrunde liegende REAPER-MIDI und sind per REAPER Undo rückgängig. Der grafische Score-Renderer folgt als nächste Stufe.


## 2026-10-04 – v1.0.15 / Scope-Fix

Fehler in v1.0.14: `score_capture_selection` wurde durch die Reihenfolge der Lua-Deklarationen nicht als lokale Funktion aufgelöst und beim Klick auf „Notation“ als nil-global aufgerufen. Die gesamte Score-Bridge-Hilfsschicht steht nun vor dem Hauptloop. Zusätzlich geprüft: genau eine Definition von `score_capture_selection`, Definition vor allen Aufrufstellen.


## 2026-10-04 – v1.0.16 / Notation Workspace 0.3

Erster grafischer Score-Prototyp in ReaImGui. Aus dem bereits funktionierenden Score-Modell werden zwei Systeme, Taktlinien und Notenköpfe gezeichnet. Die Darstellung ist ausdrücklich noch kein endgültiger Notensatz, sondern ein Interaktions-Prototyp.

Neu:
- grafische Note ↔ Score-Note ↔ REAPER-MIDI Zuordnung
- Klick auf Notenkopf setzt dieselbe Auswahl wie die Diagnose-Liste
- vorhandene Tonhöhen-/Dauer-Befehle wirken auf grafisch gewählte Note
- grafische Ansicht aktualisiert sich nach MIDI-Änderung

Erst wenn diese Zuordnung stabil ist, wird der hochwertige Renderer eingebettet.


## 2026-10-04 – v1.0.17 / Partiturfarben

Der technische Score-Prototyp bleibt bewusst funktional statt gravurorientiert. Darstellung geändert auf klassisches Notenbild: weißer Hintergrund, schwarze Linien/Noten/Taktstriche; nur die aktuell ausgewählte Note bleibt farbig markiert.


## 2026-10-04 – v1.0.18 / ScoreFlow-Renderer-Integration

Der selbst gezeichnete ReaImGui-Score wird nicht weitergeführt. Verifizierte Basis:
- ScoreFlow (IlyaSkorik/scoreflow), MIT, VexFlow-Engine mit Grand Staff, Beaming, Pausen, Tuplets, Artikulationen, Dynamik und eigenem Layout/Collision-System.
- reaper_webview (SadFrozz/reaper_webview), MIT, dockbare/freie WebView-Panels in REAPER; macOS via WKWebView.

Prototype 0.4:
- aktuelle REAPER-MIDI-Auswahl wird automatisch in ScoreFlow-kompatibles JSON übersetzt
- lokaler HTML-Host wird unter dem REAPER Resource Path erzeugt
- ScoreFlow-Engine wird auf einen festen Commit gepinnt und für diesen Prototyp über jsDelivr geladen
- WEBVIEW_Navigate öffnet die Partitur als REAPER-Panel
- bei fehlender reaper_webview-Erweiterung saubere Fallback-Meldung statt Fehler

Der Prototyp ist zunächst 4/4 + Piano/Grand Staff. Nächste Stufe: WebView↔Lua-Rückkanal für direkte Score-Bearbeitung und danach lokale Bündelung der ScoreFlow-Assets.


## 2026-10-04 – v1.0.19 / ScoreFlow-Rückkanal

Die veröffentlichte reaper_webview 0.2.0 bietet nur WEBVIEW_Navigate. Für echte Bearbeitung benötigt Composition Studio einen Rückkanal aus WKWebView nach Lua. Statt Polling-Server oder Dateihacks wird ein minimaler macOS-Patch gebaut:
- zusätzlicher WKScriptMessageHandler csBridge
- JavaScript API window.compositionStudioBridge.postMessage(...)
- native Übergabe in REAPER ExtState (ScoreBridgeMessage + monotone ScoreBridgeSeq)
- Composition Studio pollt ExtState im normalen defer-loop
- NoteTap bzw. Toolbar-Befehl wird wieder auf score_state.csid und damit konkrete REAPER-MIDI-Note abgebildet
- nach MIDI-Änderung wird die bestehende ScoreFlow-WebView-Instanz neu navigiert/rendered

Build ist reproduzierbar über .github/workflows/build-webview-bridge.yml; Grundlage ist exakt reaper_webview v0.2.0. Keine lokale Serverkomponente.


## 2026-10-04 – v1.0.20 / ScoreFlow-Auswahl

Fehlerursache für wirkungsloses Anklicken: Der Polyfill für onNoteTap lag in einem klassischen Script und griff auf `score` zu, das als `const` nur im ES-Modul-Scope existierte. Der ReferenceError wurde durch try/catch verschluckt.

Korrektur:
- Score wird als `window.csScore` explizit für die Interaktionsschicht veröffentlicht.
- Einzelklick: nearest-note Hit-Test über ScoreFlows vorhandene `state.noteHits`, sichtbare blaue Markierung.
- Klick-Drag: Rechteckauswahl über die Zentren der vorhandenen ScoreFlow-Hitboxes.
- Auswahl wird als csid-Liste über die WebView-Bridge übertragen.
- ±1 Halbton und Dauerfaktor werden in einem einzigen REAPER-Undo-Schritt auf die komplette Auswahl angewandt.


## 2026-10-04 – v1.0.21 / Drag + Bridge-Diagnose

Zwei getrennte Fehlerbilder:
- Drag-Selektion wurde korrekt im pointerup erzeugt, danach aber vom normalen ScoreFlow-click-Handler wieder auf eine einzelne Note reduziert. Ein Capture-click-Suppressor unterdrückt nun genau den Folgeclick nach einem echten Drag.
- Sichtbare Markierung ist reine Browserfunktion und beweist nicht, dass der native csBridge installiert ist. Die ScoreFlow-Toolbar zeigt deshalb nun explizit „Bridge aktiv“ bzw. „Bridge fehlt“. Bearbeitungsbuttons melden ebenfalls sofort, wenn kein nativer Rückkanal vorhanden ist.


## 2026-10-04 – v1.0.23 / Player + Noten verschieben

Notation Workspace erweitert:
- eigene Playerleiste im ScoreFlow-WebView (Anfang, Play, Pause, Stop), Befehle gehen über csBridge an REAPER und nutzen den nativen REAPER-Transport.
- direkter Drag auf einer Note verschiebt sie; bei bestehender Mehrfachauswahl wird die ganze Gruppe verschoben.
- Drag im freien Bereich bleibt Rechteckauswahl.
- vertikale Mausdistanz -> Halbtonschritte; horizontale Distanz -> QN-Verschiebung, auf 0.25 QN gerundet.
- MIDI-Start und -Ende werden gemeinsam verschoben; Dauer bleibt erhalten; Änderungen sind ein REAPER-Undo-Schritt.


## 2026-10-04 – v1.0.25 / MIDI→Notation Transkription

Der bisherige Konverter war die Hauptursache des schlechten Notenbilds: fester 4/4-Takt, starre MIDI-60-Systemtrennung und Restauffüllung bis 1/64. Ersetzt durch:
- echte REAPER-Taktgrenzen via TimeMap_QNToMeasures / TimeMap_GetMeasureInfo
- Taktartwechsel als ScoreFlow _ts
- Quantisierung von Start/Dauer auf 1/16, bei real sehr kurzen Noten adaptiv 1/32
- beschränkte, saubere Restwerte ohne punktierte Mikrorestketten
- Instrument-/Tracknamen-basierte Systemzuweisung für Streicher und typische Orchesterinstrumente

Offen: echte Tonart, Single-Staff-Renderer, Stimmenanalyse, taktübergreifende Haltebögen.


## 2026-10-04 – v1.0.26 / Single Staff + Notationsdauer

Zwei strukturelle Korrekturen:
- ScoreFlow wurde als kleiner MIT-konformer Renderer-Fork unter web/scoreflow-cs-render.js übernommen. Ergänzt wurde staffMode = single-treble / single-bass / grand. Einzelinstrumente bekommen damit erstmals wirklich nur einen Notenständer statt eines erzwungenen Klavier-Grand-Staffs.
- Notationsdauer wird bei kurzen artikulierten MIDI-Tönen aus dem Abstand zum nächsten Anschlag rekonstruiert. MIDI Note-Off bleibt relevant, ist aber nicht mehr automatisch gleichbedeutend mit dem geschriebenen Notenwert. Das verhindert viele falsche 16/32tel plus Mikro-Pausen.


## 2026-10-04 – v1.0.27 / Blank Renderer Fix

v1.0.26 band den lokalen Renderer-Fork über raw.githubusercontent.com als ES-Modul ein. WKWebView lädt Raw-GitHub nicht zuverlässig mit einem für ES-Module akzeptierten MIME-Typ; dadurch wurde das Modulskript gar nicht ausgeführt und die Partitur blieb komplett leer. Import jetzt über jsDelivr, auf Commit 5e7c7c5ef5a95d2a29ef8a8f9f13a2e2d5d364ed gepinnt. Laufzeitfehler des Renderers werden sichtbar im Notationsfenster ausgegeben.


## 2026-10-04 – v1.0.28 / Mehrspur-Partitur

Mehrere ausgewählte REAPER-Tracks werden nicht mehr in einen gemeinsamen Notenpool gemischt. score_capture_selection trägt track_guid in jede Note; scoreflow_score_json gruppiert nach Track und erzeugt score.parts[]. Der Renderer hat einen Mehrspurpfad mit gemeinsamer Taktgeometrie: pro Takt wird die maximale benötigte Breite aller Parts bestimmt, daraus werden gemeinsame Zeilenumbrüche und X-Positionen berechnet. Jeder Part wird anschließend in diese Geometrie gezeichnet. Trackname erscheint links. Klavier kann grand staff bleiben, Einzelinstrumente single staff.


## 2026-10-04 – v1.0.29 / Instrumenterkennung

Fehler: Track-/Take-Namen wie „SWAM Cello 3“ wurden als harte Instrumentangabe verwendet. Bei tatsächlich hohen Violinstimmen führte das zu Bassschlüssel und falschen Labels. Neue Regel: tatsächliche MIDI-Lage (low/high/average pitch) hat Vorrang; Namen sind nur sekundäre Hinweise und müssen zur Lage passen. Widersprüchliche Labels werden neutralisiert, doppelte Namen disambiguiert.


## 2026-10-04 – v1.0.32 / Verovio Prototype 0.1

ScoreFlow bleibt als historische Testbasis im Repository, wird aber nicht mehr als sichtbarer Notationsrenderer verwendet. Composition Studio erzeugt nun MEI direkt aus dem REAPER-MIDI-Modell und rendert es mit Verovio 6.3.0 im bestehenden WebView. Jede MIDI-Note trägt eine stabile xml:id csn<csid>, die Verovio in die SVG-Element-IDs übernimmt. Dadurch bleiben Klick, Rechteckauswahl, Drag, Transposition und Daueränderung als Composition-Studio-Funktionen erhalten. Verovios eigene experimentelle Editor-API wird nicht zur Abhängigkeit. Mehrere Tracks werden als getrennte staffDef/staff-Partien kodiert; Piano kann als zweistaviges staffGrp ausgegeben werden.


## 2026-10-04 – v1.0.33 / Flüssiger Noten-Drag

Verovio-Drag erhielt eine lokale SVG-Vorschau: während pointermove werden die aktuell markierten csn-Elemente per CSS transform unmittelbar mit der Maus bewegt. Erst bei pointerup werden die Pixelwege in musikalische Delta-Werte quantisiert und über csBridge nach REAPER geschrieben. Sensitivität: ca. 5 px/Halbton, 28 px/Viertel, horizontal weiterhin 0.25 QN Raster. pointercancel setzt Vorschau zurück.


## 2026-10-04 – v1.0.34 / Drag-Overlay + metrische Balken

Drag-Performance: echte Verovio-SVG-Noten werden während pointermove nicht mehr transformiert und ihre Bounding-Boxes nicht ständig neu gelesen. Beim pointerdown werden einmalig leichte Overlay-Rechtecke erzeugt; pointermove ändert nur transform des Overlay-Containers. Status wird nur bei Änderung des quantisierten Ziels aktualisiert. Overlay bleibt nach pointerup bis zum erfolgreichen Neurender sichtbar.

MEI-Transkription: Achtel und kürzere Ereignisse werden nun in <beam>-Gruppen innerhalb metrischer Beats kodiert. Simple Meter: Viertelbeat (4/den); Compound Meter 6/8, 9/8, 12/8: punktierte Viertel (1.5 QN). Pausen unterbrechen Balkengruppen.


## 2026-10-04 – v1.0.35 / Sichtbares Drag-Ziel

Das reine Rechteck-Overlay war zwar schnell, aber musikalisch nicht orientierend. Beim Drag wird jetzt einmalig die tatsächliche SVG-Gruppe jeder markierten Verovio-Note geklont und in ein separates Overlay-SVG gelegt. pointermove transformiert nur den gemeinsamen Ghost-Container. Die Vorschau snappt bereits während des Ziehens auf dieselben quantisierten dpitch/dqn-Werte, die bei pointerup nach REAPER geschrieben werden. Damit entspricht die sichtbare Ghost-Position dem tatsächlichen Ziel.


## 2026-10-04 – v1.0.36 / Notation Studio Palette

Strategiewechsel zurück zum nativen REAPER-Notationseditor. Das WebView/Verovio-Fenster wird aus dem sichtbaren Workflow entfernt; die experimentellen Funktionen bleiben vorerst im Code, werden aber nicht mehr über den Hauptbutton geöffnet.

Neue Oberfläche: kompaktes ReaImGui-Fenster „Notation Studio“ mit CollapsingHeader-Gruppen. Standardmäßig offen ist nur „Lesbarkeit“. Weitere Gruppen: Darstellung/Quantisierung, Stimmen/Notation, Artikulation, Dynamik, Spielweise/SWAM. Zielworkflow: Auswahl im nativen REAPER-Notationseditor -> Rechtsklick -> ein einziger Eintrag „Notation Studio…“ -> Werkzeugpalette.


## 2026-10-04 – v1.0.37 / KI + Rechtsklick-Launcher

Notation Studio enthält jetzt eine eigene KI-Gruppe. Die aktive Notenauswahl im MIDI-/Notationseditor wird als NOTATION_SELECTION/SELNOTE-Kontext an den Controller übergeben. Buttons: Auswahl analysieren, Artikulation/Dynamik beurteilen, freier KI-Auftrag zur Auswahl, SWAM-Interpretation.

Zusätzlich erzeugt Composition Studio automatisch Scripts/Composition Studio/Notation Studio.lua und registriert es via AddRemoveReaScript in Section 32060 (MIDI Editor). Das Launcher-Script setzt ExtState OpenNotationStudio und startet Composition Studio bei Bedarf. Wenn in reaper-menu.ini bereits ein [MIDI notation note context]-Block existiert, wird der Launcher dort verlustfrei angehängt; vorher wird eine Backup-Datei geschrieben. Fehlt der Block, wird er absichtlich nicht neu erzeugt, weil ein neu erzeugter Custom-Block REAPERs vollständiges Factory-Kontextmenü ersetzen würde.


## 2026-10-04 – v1.0.38 / Saubere Rechtsklick-Integration

Die automatische Manipulation von reaper-menu.ini aus v1.0.37 wurde entfernt. Composition Studio erzeugt weiterhin Scripts/Composition Studio/Notation Studio.lua und registriert es via AddRemoveReaScript in MIDI-Editor Section 32060. Die Einbindung in „MIDI notation note context“ erfolgt einmalig über REAPERs offiziellen Menü-Customizer. Dadurch bleibt REAPERs Standardmenü vollständig unangetastet.


## 2026-10-04 – v1.0.39 / Updater-Reparatur

Beim Umbau auf 1.0.38 war der komplette fetch_update/install_update-Block versehentlich mit entfernt worden. v1.0.39 stellt ihn wieder her. Die Primärquelle ist jetzt die GitHub Contents API mit Accept: application/vnd.github.raw+json; raw.githubusercontent.com ist nur noch Fallback. Syntaxprüfung, Backup und Versionsvergleich bleiben erhalten.
