# Tokenverbrauch der fehlgeschlagenen Techno-Bearbeitung

Reine Analyse auf Basis der vom Nutzer bereitgestellten Diagnosen 1.2.1 und 1.3.0 sowie veröffentlichtem Studio-Code `9a339b90f7a4dfb8b58f27268efc66e7c18ff93b`. Keine Anbieteraufrufe, keine funktionalen Änderungen oder Veröffentlichung. Die zuvor begonnene automatische Auftragssteuerung bleibt auf ihrem getrennten Arbeitsbranch pausiert. Keine Nutzernoten, Originaldiagnosen, Itemkennungen oder lokalen Nutzerpfade eingecheckt.

## 1. Tatsächlich gemeldeter Verbrauch

| Kompositionsaufruf | 1.2.1 | 1.3.0 |
| --- | ---: | ---: |
| Denkaufwand angefordert | high | medium |
| Eingabetokens | 33.961 | 33.932 |
| Ausgabe einschließlich gemeldeter Denktokens | 32.768 | 32.768 |
| Cachetokens | 0 | 0 |
| Eingabekosten laut hinterlegtem Tarif | 0,067922 USD | 0,067864 USD |
| Ausgabe-/Denkkosten laut hinterlegtem Tarif | 0,327680 USD | 0,327680 USD |
| Gesamtschätzung des Kompositionsaufrufs | 0,395602 USD | 0,395544 USD |
| Anteil Ausgabe/Denken an diesen Kosten | 82,83 % | 82,84 % |

Tarif des gewählten Argon-Modells: 2/10 USD je Million Eingabe-/Ausgabetokens zum Diagnosezeitpunkt. Schätzungen, keine Anbieterrechnung. Der erfolgreiche Controlleraufruf der letzten Diagnose kostet zusätzlich 0,003298 USD; Auftragssumme damit 0,398842 USD. Kein Nachweis eines automatischen Retry in diesem Auftrag: Controller, danach genau ein fehlgeschlagener Kompositionsaufruf. Der ältere Fehlersatz im mitgesendeten Controllerdialog ist Historie und kein zusätzlicher API-Aufruf.

**Der Hauptkostenblock ist Ausgabe/Denken, nicht der Controller.** Die Umstellung high → medium führte in diesen zwei Versuchen nicht zu einem kleineren gemeldeten Gesamtverbrauch. Daraus folgt weder, dass das Modell die Einstellung ignorierte, noch dass beide Male gleich viel gedacht wurde.

## 2. Eingabe: unnötige Wiederholung der Quellidentität

Beide Diagnosen enthalten dieselben 549 Quellnoten: 415 und 134 Noten aus zwei Items. Keine identischen doppelten Notenzeilen. Der gesamte Quellnotenbestand wird im Kompositionsprompt einmal übertragen, nicht mehrfach mit kompletter Dialoghistorie. `recent_dialog` fließt in den Controller ein, nicht in den untersuchten Kompositionsaufruf.

Gemessene Zeichen des letzten Aufrufs, **keine Tokenaufteilung**:

| Bestandteil | Zeichen |
| --- | ---: |
| Kompositionsprompt vor gemeinsamem Regeltext | 38.262 |
| Zusätzlich tatsächlich gesendeter gemeinsamer Regeltext samt Trennzeichen | 882 |
| Gesamter gesendeter Prompt | 39.144 |
| Davon 549 Notenzeilen | 36.350 |
| Davon allein die erneut pro Note ausgeschriebenen Itemkennungen | 20.862 |
| Sonstiger Prompt einschließlich gemeinsamen Regeln | 2.794 |

Notenzeilen belegen 92,86 % der Promptzeichen, die wiederholten Kennungen allein 53,30 %. Das Format lautet sinngemäß `N {38-Zeichen-Itemkennung} Start Dauer Pitch Velocity Kanal`. Die Herkunft wird zusätzlich bereits in den Itemköpfen beschrieben.

Codebeleg: `src/host/reaper/context.lua`, `music_context` schreibt für jede Note erneut `it.guid` und feste fünf Nachkommastellen. `composition_prompt` in `src/music/prompts.lua` hängt diese Darstellung an. Sowohl diese Funktion als auch `music_context` sind bytegenau identisch zur veröffentlichten 1.1.10 (`4743491d7081cf009f144a88b70c373047febeab`). Die Redundanz wurde nicht erst durch die Modularisierung eingeführt.

Eine rein lokale, **nicht implementierte** verlustfreie Formatprobe ordnet jeder vollständigen Quellkennung einmal eine kurze lokale Referenz zu und bewahrt für jede Note Quelle, Start, Dauer, Pitch, Velocity und Kanal:

- Gruppierung mit kurzen Referenzen: Notenzeilen und Zuordnung 16.134 statt 36.350 Zeichen. Gesamter Prompt rechnerisch 18.928 statt 39.144 Zeichen (−51,65 %).
- Zusätzlich ausschließlich überflüssige Dezimalnullen entfernen: 14.222 Zeichen für Zuordnung/Noten, gesamter Prompt 17.016 Zeichen (−56,53 %).
- Alle 549 Ereignisse inklusive Herkunft und numerischen Werten offline per Multimengenvergleich identisch zurückgewonnen. Keine Noten entfernt, vereinfacht, quantisiert oder in musikalische Blöcke zerlegt.

Das sind **Zeichenersparnisse**, keine behaupteten Gemini-Token- oder Kosteneinsparungen. Exakte Tokens pro Bestandteil fehlen; es wurde kein Anbieter-Tokenzählendpunkt aufgerufen. Das reale Zahlen-/Kennungsformat lässt sich nicht zuverlässig mit der Faustregel „vier Zeichen pro Token“ bewerten.

## 3. Ausgabe: Ursache durch Diagnoseverlust nicht mehr trennbar

`src/ai/costs.lua`, `costs.usage`, liest Googles `candidatesTokenCount` und `thoughtsTokenCount`, speichert aber nur deren Summe in `n.output`. `costs.record` exportiert diese als `usage_output_tokens` und setzt `usage_reasoning_tokens` dennoch immer auf „nicht separat ausgewiesen“. Die Felder könnten in der ursprünglichen Anbieterantwort getrennt vorgelegen haben; der Export bewahrt die Trennung nicht.

Offline-Nachweis mit tatsächlichen veröffentlichten Produktionsfunktionen und zwei **synthetischen, nicht real gemessenen** Antworten:

| Synthetische Antwort | Sichtbare Antworttokens | Denktokens | Studio-Ausgabezählung | Studio-Denkanzeige |
| --- | ---: | ---: | ---: | --- |
| A | 32.768 | 0 | 32.768 | nicht separat ausgewiesen |
| B | 768 | 32.000 | 32.768 | nicht separat ausgewiesen |

Beide ergeben dieselbe Schätzung von 0,395544 USD bei 33.932 Eingabetokens. Die Rechnung ist innerhalb dieser Tarifannahme konsistent; die Diagnose ist für die Ursachenklärung unzureichend. **Die 32.768 Tokens dürfen nicht pauschal als 32.768 Tokens fertiger Musik bezeichnet werden.**

Zusätzlich prüft `ai_poll` in `src/ai/requests.lua` MAX_TOKENS vor der Textextraktion. Es löscht dann die Request-/Antwort-/Statusdateien und gibt nur einen Fehler zurück. Weder die sichtbare unvollständige Antwort noch deren Länge oder Notenanzahl wird in der Diagnose erhalten. `composition_answer` und `api_response_excerpt` sind in diesen Diagnosen leer. Aus ihnen ist daher nicht rekonstruierbar, wie viel Musik bereits ausgegeben wurde, ob die Ausgabe unnötig wiederholte oder wie viel Budget in Denken floss.

Der untersuchte alte Einzelaufruf setzt für Google kein eigenes `maxOutputTokens`; die 2048-/8192-Grenzen des Ganztrack-Ablaufs waren hier nicht aktiv. Es gibt keinen Beleg, dass ein appseitiges 32768-Limit diesen Einzelaufruf begrenzte. MAX_TOKENS und die Verbrauchssumme beweisen allein auch kein bestimmtes größeres unterstütztes Modelllimit.

## 4. Konsequenz für das Konzept langer Kompositionen

1. Zuerst Diagnose vervollständigen: Kandidaten-/Denktokens getrennt, HTTP-/Stopstatus und sichtbare unvollständige Antwort beziehungsweise deren sichere lokale Ablage samt Größen-/Notenstatistik erhalten. Keine verborgenen Denktexte erforderlich. Keine neue kostenpflichtige Versuchsschleife allein für diese Untersuchung.
2. Danach die bereits belegte Eingaberedundanz verlustfrei reduzieren: kurze Quellreferenzen statt Kennung pro Note, überflüssige Zahlenformatierung entfernen. Gesamtes Werk und alle Noten bleiben als Kontext erhalten. Umsetzung erst nach besprochenem Konzept.
3. Mit getrennten Daten klären, ob Antwortumfang, Denkbudget oder beides die Ausgabegrenze ausschöpfen. Erst dann Ausgabeformat, Modellparameter oder mehrere technische Lieferungen bewerten. Inputkomprimierung allein behebt einen Ausgabelimitabbruch nicht nachweislich.
4. Frühere erfolgreiche 72-Takte-Kompositionen anhand ihrer tatsächlichen Modell-/Prompt-/Usage-/Ausgabedaten vergleichen. Diese Vergleichsdiagnosen liegen hier nicht vor; die genaue Abweichung lässt sich deshalb noch nicht belegen. Taktzahl allein ist keine Tokenmetrik.

Diese Analyse begründet keine feste musikalische Abschnittslänge und keine automatische Zerlegung des Werks. Der nächste technische Schritt wäre bessere Messbarkeit, nicht eine weitere Änderung der Kompositionssteuerung.
