-- Local connection to the existing Composition Engine JavaScript runtime.
-- The engine and bridge are downloaded from our GitHub repositories.
-- They are not installed as separate REAPER apps.
local JSON_ENGINE_VERSION="2.20.1"
local function engine_json_prompt(request)
 return [=[Komponiere das verlangte Musikstück vollständig und eigenständig.
Gib ausschließlich gültiges JSON aus, ohne Markdown oder Erläuterungen.
Das JSON hat dieses technische Format:
{"title":"Titel","bpm":120,"timeSignature":[4,4],"tracks":[{"name":"Klavier","program":0,"channel":0,"notes":[[0,1,60,80],[1,1,64,80]]}]}
Jede Note ist [StartInVierteln,DauerInVierteln,MIDIPitch,Velocity].
Alle Positionen beginnen bei 0 und sind in Viertelnoten-Einheiten.
MIDI-Pitch 0..127, Velocity 1..127, Instrumentenprogramm 0..127, Kanal 0..15.
Pausen sind Lücken; Akkordtöne haben dieselbe Startposition.
Wähle Musik, Instrumentierung, Artikulation, Form, Harmonik und Rhythmus frei entsprechend dem Auftrag.
Keine zusätzliche musikalische Vorgabe. Alle geforderten Takte vollständig komponieren.
Dynamik durch Velocity, Artikulation und Phrasierung durch tatsächliche Notendauern und Einsätze gestalten.
Optional "tempoEvents":[{"at":8,"bpm":96}] für Tempowechsel und "pedalEvents":[{"at":0,"value":127},{"at":4,"value":0}] für gemeinsames Sustain-Pedal.
Pro Spur sind außerdem "ccEvents":[{"at":0,"controller":11,"value":80},{"at":4,"controller":64,"value":0}] erlaubt.
Alle Positionen in Vierteln. CC64 ist Sustain, CC11 Expression. Schließe benutztes Pedal innerhalb der Fassung wieder.
AUFTRAG:
]=]..request
end
-- Experimental two-stage musical workflow. Preserves direct JSON as an option.
local COMPOSITION_MODE_KEY="CompositionModeV1"
local composition_mode=reaper.GetExtState(EXT_SECTION,COMPOSITION_MODE_KEY)
if composition_mode~="concept" and composition_mode~="direct" then composition_mode="concept" end
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
local function launch_new_json(request,key,data)
 data=data or {request=request,full={},music_tracks={}}
 if composition_mode=="concept" then
  local p=concept_prompt(request)
  diag_set("composition_mode","Konzeption + Komposition")
  diag_set("concept_prompt",p)
  update_status="Musikalisches Grundgerüst wird entwickelt …"
  return launch("engine_concept",p,key,data)
 end
 diag_set("composition_mode","Direktes JSON")
 local p=engine_json_prompt(request)
 diag_set("composition_prompt",p)
 return launch("engine_json",p,key,data)
end
