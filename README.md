# Composition Studio

Composition Studio ist das neue Zielprojekt für eine moderne Musikproduktions- und Kompositionsumgebung.

## Aktueller Stand

**GUI-Prototyp V0.2**

Die funktionale Entwicklung ist vorerst eingefroren. Der aktuelle Schwerpunkt liegt auf Interface und visueller Struktur. Der klickfreie Referenzprototyp liegt in `index.html`.

## Rolle im Gesamtsystem

Composition Studio soll bewährte Teile der drei anderen aktiven Projekte zusammenführen, ohne deren historische Architektur vollständig zu übernehmen:

- **Music Chat Lab** — Dialog- und Workflow-Referenz
- **Minimal Composer** — Minimalarchitektur und Kompositionsforschung
- **Composition Lab Native** — macOS, Notation, MusicXML, MIDI-I/O und CLAB

Composition Studio bleibt dabei ein eigenständiges, möglichst schlankes Zielsystem.

## Zielaufbau

- KI-Chat links
- großes Arrangement in der Mitte
- Browser rechts
- Editor im unteren Bereich
- zentrierte Transportgruppe
- helle, freundliche Oberfläche mit klarer Helligkeitsstaffelung
- kräftige Kontraste ohne unnötige Buntheit
- deutlich voneinander abgegrenzte Funktionsbereiche
- dezente Spurfarben und passende Clipfarben

## Designrichtung

Die Oberfläche verbindet die klare Gliederung moderner DAWs, kräftige Kontraste und eine eigene Composition-Studio-Identität. Nicht gewünscht sind monotones Einheitsgrau, schwache Weiß-auf-Grau-Kontraste, eine dominierende weiße obere Transportleiste oder ein überladenes Farbschema.

## Versionsprinzip

- `V0.x` — GUI-Prototypen
- `V1.0` — erster konsolidierter Composition-Studio-Stand

Relevante Zwischenstände werden im Repository gesichert; Wegwerf-Patches und einmalige Migrationshilfen sollen nicht dauerhaft im aktiven Quellbaum verbleiben.
