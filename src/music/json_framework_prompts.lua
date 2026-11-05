local function concept_prompt(request)
 return [=[Lege ausschließlich den MUSIKALISCHEN RAHMEN für eine spätere Komposition fest.
Der Nutzerauftrag bestimmt alle ausdrücklich genannten Anforderungen.
Bestimme nur die noch offenen Eckdaten: Besetzung (falls offen), Tonart bzw.
tonales Zentrum, Taktart, Tempo mit eindeutiger Schlageinheit, ungefähre Länge,
Stimmung/Charakter und eine GROBE musikalische Richtung.
Entwickle ausdrücklich NOCH KEINE konkrete Kompositionsidee: kein inneres Bild,
keine Szene, kein bestimmtes Begleitmuster, keine Melodiegeste, keine harmonische
Abfolge, keine detaillierte Formdramaturgie. Diese schöpferische Arbeit gehört
vollständig der anschließend komponierenden KI.
Antworte kurz, sachlich und nur mit dem musikalischen Rahmen.
NUTZERAUFTRAG:
]=]..request
end
local function composed_json_prompt(request,framework)
 return [=[Du bist die komponierende KI. Du erhältst ausschließlich einen
MUSIKALISCHEN RAHMEN, keine bereits festgelegte Kompositionsidee.
Entwickle daraus SELBST eine lebendige, eigenständige Klang- und
Charaktervorstellung und komponiere das vollständige Stück aus ihr heraus.

Der Rahmen setzt Leitplanken, aber er nimmt dir keine konkreten musikalischen
Entscheidungen ab. Form, Stimmführung, Zusammenhang und Machbarkeit sind Ziele,
keine Schablone für einzelne Takte oder Noten.

Entwickle aus dem musikalischen Rahmen eine eigenständige Komposition.
Gestalte Melodie, Begleitung, Harmonik, Rhythmus und Form als
zusammenhängendes musikalisches Ganzes. Entwickle deine musikalischen
Gedanken mit der Konsequenz, die sie verlangen.
Entscheide selbst über Wiederholung, Veränderung, Kontrast und Fortführung.
Musikalische Schlüssigkeit hat Vorrang vor äußerer Wirkung und bloßer Originalität.

Halte alle ausdrücklichen Anforderungen des ursprünglichen Nutzerauftrags ein.
MUSIKALISCHER RAHMEN:
]=]..framework..[=[

URSPRÜNGLICHER NUTZERAUFTRAG:
]=]..request..[=[

Gib als Antwort NUR gültiges JSON ohne Markdown aus. Füge ein Feld "idea" hinzu.
Beschreibe darin knapp die musikalische Identität und die tatsächlich entstandene
Entwicklung des fertigen Stücks. "idea" ist keine vorgeschaltete Planungsstufe
und kein vorher abzuarbeitendes Schema, sondern eine kurze Beschreibung der
Komposition, die du im selben Vorgang erschaffst.
Technisches Datenformat (die Zahlen darin sind nur Platzhalter, keine musikalische Vorgabe):
{"idea":"Eigene Klangvorstellung und musikalische Umsetzung","title":"Titel","bpm":86,"timeSignature":[3,4],"tracks":[{"name":"Klavier","program":0,"channel":0,"notes":[[0,1,60,80],[1,0.5,64,76]]}]}
Jede Note [Start in Vierteln, Dauer in Vierteln, MIDI-Pitch, Velocity].
Positionen starten bei 0. Pausen sind Lücken; gleichzeitig klingende Töne
haben dieselbe Startposition.
Musikalische Ausdrucksgestaltung (Kann-Bestimmung): Nutze die verfügbaren
Möglichkeiten zur Gestaltung von Tempo, Dynamik, Artikulation, Phrasierung und
Klang, soweit sie deiner musikalischen Vorstellung dienen. Du entscheidest
frei über Art, Umfang und Verwendung. Auch ein bewusster Verzicht ist sinnvoll.
Arpeggien, Triller und ähnliche Spielfiguren komponierst du bei Bedarf direkt
mit individuellen Noten-Anschlagszeitpunkten und Notendauern.
Optional sind "tempoEvents":[{"at":24,"bpm":72}] für Tempowechsel und
"pedalEvents":[{"at":4,"value":127},{"at":8,"value":0}] für Sustain-Pedal
(CC64) erlaubt; Positionen in Viertelnoten. Keine Pflicht zur Verwendung.
Pro Spur sind optional "ccEvents":[{"at":0,"controller":11,"value":80}] erlaubt (CC64 Sustain, CC11 Expression). Positionen in Vierteln. Pedal innerhalb der Fassung wieder lösen.
Erzeuge das vollständige Werk.
]=]
end
-- BEGIN MODULE EXPORTS
return {concept_prompt=concept_prompt,composed_json_prompt=composed_json_prompt}
