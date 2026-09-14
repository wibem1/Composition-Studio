# Composition Studio

Composition Studio ist das eigenständige Zielprojekt für eine moderne Musikproduktions- und Kompositionsumgebung mit eigener Oberfläche und KI-Workflow.

## Aktueller Stand

Die GUI-Richtung ist festgelegt. Die Entwicklung konzentriert sich jetzt auf eine schlanke native Architektur und auf gebrauchsfähige Funktionspakete statt auf reine GUI-Zwischenstände.

MAGDA dient als technische Basis für Audio, MIDI, Plugin-Hosting und weitere DAW-Funktionen. Composition Studio bleibt jedoch eine eigene Anwendung mit eigener Oberfläche. Die Verbindung erfolgt ausschließlich über eine definierte EngineBridge.

Die verbindliche Architektur ist in `docs/ARCHITECTURE.md` beschrieben.

## Architektur

Composition Studio besteht aus drei klar getrennten Schichten:

1. **MAGDA Engine** – Audio, MIDI, Plugins, Routing, Projektfunktionen
2. **CompositionStudioCore / EngineBridge** – kleine, kontrollierte Schnittstelle zwischen Engine und App
3. **Composition Studio App** – eigenes macOS-GUI, Arrangement, Browser, Inspector, Editor/Notation und KI-Dialog

Frühere parallele Entwicklungswege werden nicht weitergeführt. Insbesondere wird die komplette MAGDA-Oberfläche nicht gleichzeitig als zweite Composition-Studio-Anwendung umgebaut.

## Zielaufbau der Oberfläche

- KI-Chat links
- großes Arrangement in der Mitte
- Browser rechts
- Editor/Notation im unteren Bereich
- zentrierte Transportgruppe
- helle, freundliche Oberfläche mit klarer Helligkeitsstaffelung
- kräftige Kontraste ohne unnötige Buntheit
- deutlich voneinander abgegrenzte Funktionsbereiche
- dezente Spurfarben und passende Clipfarben

## Entwicklungsstufen

- **V0.6** – technischer Kern: Engine, Transport, Projekt laden/speichern
- **V0.7** – Tracks, MIDI-Clips, MIDI-Import/Export
- **V0.8** – Instrumente, Plugins und Routing
- **V0.9** – Arrangement und Editor
- **V1.0** – erster vollständig gebrauchsfähiger Studio-Workflow einschließlich erstem sinnvollen KI-Kompositionsworkflow

Ein Build wird nur dann als neuer Benutzer-Teststand behandelt, wenn er ein klar definiertes Nutzungspaket ergänzt.

## Designrichtung

Die Oberfläche verbindet die klare Gliederung moderner DAWs, kräftige Kontraste und eine eigene Composition-Studio-Identität. Nicht gewünscht sind monotones Einheitsgrau, schwache Weiß-auf-Grau-Kontraste, eine dominierende weiße obere Transportleiste oder ein überladenes Farbschema.

Der frühere HTML-Prototyp `index.html` bleibt als visuelle Referenz erhalten; die aktive Produktentwicklung findet im nativen Pfad statt.
