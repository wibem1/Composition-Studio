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
-- BEGIN MODULE EXPORTS
return {engine_json_prompt=engine_json_prompt}
