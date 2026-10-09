# Composition Studio v1.0.62 – Windows/macOS JSON-Verarbeitung

Die REAPER-App benötigt für den JSON→MIDI-Pfad **weder Node.js noch PowerShell**.
Die technische Schnittstelle ist direkt in REAPER-Lua implementiert und funktioniert
damit auf Windows und macOS. Der Code liest das seit Minimal Composer verwendete
JSON-Partiturformat und erzeugt vorhandene REAPER-CS-MIDI-Ereignisse.

**Wichtige Architekturaussage:** Dies ist ein lokaler *Kompatibilitätsadapter*
zum gemeinsamen Partitur-Datenschema, **keine Ausführung** der JavaScript-Datei
`composition-engine.js`. Die ursprünglich vorbereitete Node-Bridge liegt weiter
als Entwicklungsreferenz im Repository, ist aber im Standardweg nicht aktiv.
Die musikalische Komposition macht die gewählte KI in einem Aufruf.

Neu-Kompositionen: Auftrag → KI-JSON → Lua-Parser → vorhandener REAPER-MIDI-Importer.
Fortsetzungen und Variationen sind noch nicht umgestellt.
Keine externen JavaScript-Laufzeiten, kein Installer, kein LilyPond nötig für
diesen Weg. Der Lua-Parser verwirft ungültige JSON-Daten/Noten, ohne musikalische
Korrekturen zu erfinden.

Die Script-Syntax und ein echter Windows- und macOS-REAPER-Durchlauf müssen vor
Kennzeichnung als vollständig stabil geprüft werden.
