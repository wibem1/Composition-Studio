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
