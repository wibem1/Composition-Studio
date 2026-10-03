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
