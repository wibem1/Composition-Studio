# Composition Studio

Composition Studio ist die KI-Kompositions- und Bearbeitungsebene direkt in REAPER.

Aktueller Stand: **v1.0.73 · 10.10.2026**.

Denkaufwand im Hauptfenster: **Kurz / Mittel / Hoch / Automatisch**, mit **Mittel** als Voreinstellung. Die Auswahl wird dauerhaft gespeichert und gilt für die KI-Aufrufe des Auftrags einschließlich Konzeption und Komposition. Während eines laufenden Auftrags ist sie gesperrt. Automatisch sendet keine Denksteuerung und verwendet die Modellvorgabe.

OpenAI erhält `reasoning.effort`, Anthropic `output_config.effort`, Gemini 3 `generationConfig.thinkingConfig.thinkingLevel` (jeweils low/medium/high). Gemini 2.5 verwendet stattdessen die appseitig zugeordneten Denkbudgets 2048/8192/24576 Tokens; das Hauptfenster weist darauf hin. Diagnose und Kommunikationsprotokoll enthalten die Auswahl und die tatsächlich gesendeten Parameter. Diese dokumentieren die Anforderung, nicht eine garantierte Qualität oder Tokenzahl.

Die langfristige Zielsetzung des Notationsmoduls ist in [NOTATION-MODULE.md](NOTATION-MODULE.md) dokumentiert.

Die bestehende Updatefunktion bleibt der normale Installationsweg: **Studio-Menü → Update**.
