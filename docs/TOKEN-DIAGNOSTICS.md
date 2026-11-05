# Getrennte Token-Diagnose und sichtbare Teilantworten

Fix auf `fix/token-diagnostics-20261105`, noch nicht veröffentlicht. Keine neue Versionsnummer. Unabhängig vom kompakten Musikformat in PR #17 und ohne die pausierte automatische Abschnittssteuerung.

## Problem und Korrektur

Bisher addiert Studio Googles `candidatesTokenCount` und `thoughtsTokenCount`, exportiert aber nur die Summe und meldet Denken stets als nicht separat ausgewiesen. Bei MAX_TOKENS löscht es die Antwort, bevor eine sichtbare Teilantwort gesichert ist. Zusätzlich lädt die bisherige Wiederherstellung viele vorhandene Usage-Felder und den Stopgrund nach Neustart nicht zurück.

Der Fix bewahrt getrennte Angaben, deren Bedeutung und die ursprünglichen Usage-Metadaten. Die vorhandene Gesamtausgabe und die bisherige Kostensumme bleiben kompatibel. Export und Wiederherstellung nutzen jetzt dieselbe Feldkonfiguration; alte Diagnosen bleiben lesbar. Fehlende historische Werte werden nicht erfunden.

| Feld | Bedeutung |
| --- | --- |
| `usage_input_tokens` | Gemeldeter Eingabeverbrauch wie bisher |
| `usage_output_tokens` | Gesamtausgabe einschließlich gemeldeter Denktokens, bisherige Zählkonvention |
| `usage_answer_tokens` | Google: `candidatesTokenCount`; OpenAI: `output_tokens − output_tokens_details.reasoning_tokens`, falls gemeldet; sonst nicht separat bestimmbar |
| `usage_reasoning_tokens` | Explizit gemeldete Denktokens; ohne Angabe unbekannt, nicht fälschlich null |
| `usage_output_definition` | Anbieterabhängige Zählkonvention, insbesondere keine doppelte Addition bei OpenAI |
| `usage_breakdown_status` | Ob die Aufteilung vollständig oder nur teilweise bestimmbar ist |
| `usage_provider_json` | Ursprüngliche Usage-Metadaten, maximal 8192 Bytes; Begrenzung in `usage_provider_json_truncated` ausgewiesen |
| `usage_input_estimated_usd` / `usage_output_estimated_usd` | Kostenaufteilung nach dem beim Aufruf gesicherten Tarif einschließlich bestehender Cache-/Kontextregeln |
| `usage_answer_estimated_usd` / `usage_reasoning_estimated_usd` | Weitere Aufteilung nur bei vorhandenen getrennten Zahlen und Tarif |
| `api_stage` | Zuordnung etwa zu Controller, Komposition oder Ganztrack-Fenster |
| `api_requested_output_tokens` | Tatsächlich appseitig angefordertes Limit oder Anbietervorgabe; Anthropic-Standard 16000 wird ausdrücklich erfasst |
| `api_request_timeout_seconds` / `api_request_prompt_bytes` | Gesendetes Zeitlimit und Promptgröße in Bytes, keine Tokenabschätzung |
| `api_stop_reason` | Stopgrund, einschließlich OpenAI `max_output_tokens` |

Google meldet Antwort- und Denktokens getrennt. Bei OpenAI sind Denktokens bereits in `output_tokens` enthalten; sie werden für die Rechnung nicht erneut addiert. Der daraus berechnete Antwortanteil ist die übrige Ausgabe, keine aus Textlänge gemessene Tokenzahl. Anthropic weist in den hier unterstützten Feldern keinen separaten Denkanteil aus; Studio behauptet dafür keine Aufteilung. Anbieterfelder werden als gemeldet behandelt, nicht anhand der gewünschten Denkstufe geschätzt.

Der Kommunikationsverlauf enthält Antwort- und Denktokens pro abgeschlossenem Aufruf, sodass beim nächsten Aufruf nicht nur dessen oberster Diagnose-Snapshot übrig bleibt. Zu Beginn eines neuen Aufrufs werden die alten pro-Aufruf-Felder gelöscht und der Status auf PENDING gesetzt. Summen/Idempotenz der vorhandenen Kostenrechnung bleiben erhalten. USD-Werte sind weiterhin Schätzungen, keine Anbieterrechnungen.

## Sichtbare unvollständige Antwort

Bei Tokenabbruch und Timeout mit vorhandener Antwort werden vor dem Entfernen der temporären Transportdateien die sichtbaren Textblöcke gesichert:

- Google: Text aus dem ersten Kandidaten, nur wenn `thought` fehlt oder ausdrücklich false ist.
- OpenAI: ausschließlich `message`/`output_text`; keine Reasoning-/Summary-Blöcke.
- Anthropic: ausschließlich `content`-Blöcke vom Typ `text`, keine Thinking-Blöcke.

Textblöcke werden für die Diagnose mit Zeilenumbruch verbunden. `api_partial_answer` enthält maximal 262144 Bytes dieses Textes, UTF-8-sicher begrenzt. `api_partial_answer_bytes` nennt die gesamte zusammengesetzte Textlänge, `api_partial_retained_bytes` die gesicherte Länge und `api_partial_truncated` eine eventuelle Begrenzung. `api_response_bytes` erfasst die gesamte Transportantwort. Ab 2 MB Antwort wird die strukturierte Textextraktion ausgelassen und ausdrücklich als nicht verfügbar markiert. Ungültiges/unvollständiges Antwort-JSON wird nicht durch unsichere Textsuche „rekonstruiert“.

`api_partial_status` kennzeichnet die Antwort als unvollständig und nur zur Diagnose. Sie wird weder als musikalischer Vorschlag freigegeben noch importiert. Keine automatischen Wiederholungen oder zusätzlichen Anbieteraufrufe. Keine Sicherung von Request-/Authdaten oder als Denken gekennzeichneten Textblöcken. Die Diagnose enthält weiterhin musikalischen Nutzerinhalt und ist entsprechend eine lokale Projekt-/Supportdatei, kein öffentliches Protokoll.

JSON-Escaping berücksichtigt nun alle Steuerzeichen, damit auch ungewöhnlicher sichtbarer Text den Export nicht ungültig macht. Dieselben neuen Felder und Teilantworten bleiben nach Neustart erhalten.

## Nachweise und Grenzen

`tools/test_token_diagnostics.py` führt die Produktionsfunktionen aus: synthetische Google-Verteilungen 32768 Antwort + 0 Denken sowie 768 Antwort + 32000 Denken bleiben in der Gesamtausgabe 32768, sind aber jetzt unterscheidbar; die Rechnung bleibt jeweils gleich. Diese Beispiele sind **keine rückwirkend ermittelten Werte aus den Nutzerdiagnosen**.

Weitere Fälle: fehlende Denkzahlen, OpenAI ohne Doppelzählung, ungültige Zahlen, Anthropic ohne erfundene Aufteilung, gefilterte Thinking-Blöcke, verfügbare Teilantworten, Größenbegrenzung, Unicode/Steuerzeichen, Cachedatei/JSON-Export, frische Lua-Sitzung, Löschen veralteter Werte und alte Diagnosekompatibilität. Bestehende Transporttests prüfen die tatsächlichen angeforderten Limits. Vollständiger Offline-Runner mit 18 Python-Suiten und drei Lua-Dateien bestanden. Keine bezahlten Anbieteraufrufe und keine native Windows-/REAPER-Abnahme.

Bereits gelöschte Antwortdaten und nicht gespeicherte historische Aufteilungen lassen sich nicht zurückholen. Die neue Diagnose macht künftige Aufrufe überprüfbar; sie reduziert für sich genommen weder Denkaufwand noch Tokenkosten.
