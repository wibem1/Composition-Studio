return function(music_context,parse_notes,trim)
local function analysis_prompt(request,items,tracks) return [[Du analysierst das konkret übergebene MIDI-Material. Antworte musikalisch präzise als normaler Text. Erfinde nichts. Erzeuge kein MIDI und keine CS-Zeilen.]].."\nAUFTRAG:\n"..request.."\nMUSIK:\n"..music_context(items,tracks,false) end
local function composition_prompt(request,items,tracks,is_new)
 if is_new then
  return [[Komponiere jetzt das verlangte Stück vollständig. Erzeuge die Musik selbst – keinen Entwurf, keinen Formplan, kein Konzept, keine Klangbeschreibung und keine Erläuterung darüber, wie das Stück später komponiert werden könnte. Triff die musikalischen Entscheidungen unmittelbar in der Komposition: konkrete Stimmen, Tonhöhen, Dauern, Rhythmus, Harmonik, Artikulation, Dynamik und Verlauf. Die Komposition muss so vollständig und eindeutig notiert sein, dass eine nachfolgende technische Instanz sie ohne eigene musikalische Entscheidungen lediglich übertragen kann. Gib der fertigen Komposition einen kurzen Werktitel und, soweit musikalisch bestimmbar, Tonart und Tempo an. Denke nicht an MIDI-Codierung, QN-Werte, CS-Zeilen oder das technische Zielformat. Keine Analyse und keine Beschreibung der Arbeitsweise.]].."\n\nAUFTRAG:\n"..request
 end
 local has_note_selection=false
 for _,it in ipairs(items) do if it.selection_source and #it.selection_source>0 then has_note_selection=true; break end end
 if has_note_selection then request=request.."\nNOTATIONSAUSWAHL: Nur markierte Noten sind das Material. Nicht markierte Noten müssen unverändert bleiben. Ausschließlich CS|revised-Variante auf neuer Spur oder CS|new-Stimme erzeugen, niemals CS|target oder CS|track." end
 for _,it in ipairs(items) do
  if it.score_context then
   request=request.."\nPARTITURKONTEXT: Alle sichtbaren MIDI-Items sind Kontext. Vorhandene Spuren nicht verändern. Nur CS|unchanged, CS|revised auf separater Spur oder CS|new für zusätzliche Stimme. CS|target und CS|track sind untersagt."
   break
  end
 end
 return [[Du komponierst Musik in Composition Studio. Nutze das konkret übergebene vorhandene Material als musikalischen Kontext und erfülle den freien Auftrag eigenständig; füge keine unnötigen Regeln hinzu. Bei einer reinen Ergänzung einer weiteren Stimme bleiben alle vorhandenen Stimmen unverändert: erzeuge die zusätzliche Stimme mit CS|new und kennzeichne vorhandene Items mit CS|unchanged. TIME_SELECTION ist nur bei ausdrücklichem Bezug auf den markierten Bereich ein Zielbereich. Eine ausgewählte TRACK_GUID kann auch ohne ausgewähltes MIDI-Item direkt Ziel sein. Jedes neu erzeugte MIDI-Item MUSS einen passenden General-MIDI-Program-Change (0-127) erhalten.
Antworte ausschließlich:
CS|unchanged|SOURCE_GUID
CS|target|SOURCE_GUID|NAME|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
CS|track|TRACK_GUID|NAME|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
CS|revised|SOURCE_GUID|NAME|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
CS|new|-|NAME|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
Optional für Ausdruck:
CSCTRL|NAME|startQN|CHANNEL|cc|CONTROLLER|VALUE
NAME identisch zur zugehörigen CS-Zeile; Kanal 0..15, Controller und Wert 0..127. Sustain = CC64, Expression = CC11.
Dynamik, Artikulation und Phrasierung in Velocity, Notendauern und Einsätzen konkret umsetzen.]].."\nAUFTRAG:\n"..request.."\nMUSIK:\n"..music_context(items,tracks,false)
end
local function midi_translation_prompt(request,draft)
 return [[Du bist jetzt ausschließlich Notations- und MIDI-Übersetzer. Übertrage die folgende bereits fertige Komposition so vollständig und werkgetreu wie möglich in Composition-Studios MIDI-Daten. Komponiere NICHT neu, vereinfache NICHT, regularisiere NICHT den Rhythmus und ersetze keine ungewöhnlichen musikalischen Entscheidungen durch Standards. Bewahre insbesondere rhythmische Vielfalt, Pausen, Stimmführung, Phrasierung, Dynamik und Artikulation der Komposition.
Übertrage alle im Entwurf ausdrücklich vorgesehenen Tempo- und Taktartwechsel mit CSMETA. Erfinde keine Wechsel.
CSMETA|tempo|startQN|BPM
CSMETA|timesig|startQN|ZAEHLER|NENNER
Artikulation und Dynamik müssen möglichst werkgetreu in MIDI erhalten bleiben: legato durch nahezu volle oder leicht überlappende Notendauern, staccato durch deutlich verkürzte Dauern, tenuto durch nahezu volle Dauer, Akzente/marcato durch passende Velocity. Crescendo und Diminuendo dürfen zusätzlich mit CC11 Expression übertragen werden. Ausdrücklich notierte instrumentale Spielweisen dürfen durch MIDI-Controller oder Program Changes umgesetzt werden; erfinde keine Spielweisen.
Erzeuge für jedes Instrument genau eine Zeile:
CS|new|-|NAME|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
Zusätzlich sind bei Bedarf erlaubt:
CSCTRL|NAME|startQN|CHANNEL|cc|CONTROLLER|VALUE
CSCTRL|NAME|startQN|CHANNEL|program|PROGRAM
NAME muss exakt dem NAME der CS-Zeile entsprechen. CHANNEL 0-15; CONTROLLER, VALUE und PROGRAM 0-127. PROGRAM der CS-Zeile ist General MIDI 0-127. startQN und durationQN dürfen beliebige sinnvolle Dezimalwerte haben. Antworte ausschließlich mit CSMETA-, CSCTRL- und CS-Zeilen.]].."\n\nFERTIGE KOMPOSITION:\n"..draft
end

-- Long works are translated in short independently validated sections.
local function numbered_measure_count(draft)
 local highest=0
 for n in tostring(draft or ""):gmatch("[Tt]%.%s*(%d+)") do highest=math.max(highest,tonumber(n) or 0) end
 return highest
end
local function chunk_prompt(draft,first_bar,last_bar)
 -- Send only the target bars: repeating the entire composition was unnecessarily slow.
 local header={}
 local found={}
 local current=nil
 for line in (tostring(draft or "").."\n"):gmatch("([^\n]*)\n") do
  local bar=tonumber(line:match("[Tt]%.%s*(%d+)"))
  if bar then current=bar end
  if current and current>=first_bar and current<=last_bar then found[#found+1]=line
  elseif not current and #header<20 then header[#header+1]=line end
 end
 local base_qn=(first_bar-1)*4
 return [[Übertrage den folgenden vollständigen musikalischen Abschnitt in REAPER-MIDI-Daten.
Antworte ausschließlich mit vollständigen Datenzeilen:
CS|new|-|NAME|PROGRAM|startQN,durationQN,pitch,velocity,channel;...
CSMETA|tempo|startQN|BPM
CSMETA|timesig|startQN|ZAEHLER|NENNER
CSCTRL|NAME|startQN|CHANNEL|cc|CONTROLLER|VALUE
Alle startQN sind ABSOLUT ab Stückbeginn, nicht relativ zum Abschnitt.
Für 4/4 beginnt dieser Abschnitt bei QN ]]..base_qn..[[. Andere Taktarten entsprechend berücksichtigen.
Übertrage exakt alle Noten, Pausen, Akkorde und Dauern der Takte ]]..first_bar..[[ bis ]]..last_bar..[[, ohne Noten zu erfinden oder auszulassen. Gib jede MIDI-Note mit fünf numerischen Werten an. Gib nur diese Takte aus. Für Klavier nutze konsequent NAME=Klavier für beide Hände und MIDI-Kanal 0 (oder 1 für die linke Hand). Die Ausgabe muss vollständig sein.
STÜCKINFORMATION:
]]..table.concat(header,"\n").."\nTAKTE:\n"..table.concat(found,"\n")
end

local function check_translation_chunk(s)
 local found=false
 for line in tostring(s or ""):gmatch("[^\r\n]+") do
  line=trim(line)
  if line:match("^CS|") then
   local kind,guid,rest=line:match("^CS|([^|]+)|([^|]+)|(.+)$")
   if not kind then return false,"Unvollständiger CS-Kopf" end
   if kind=="new" or kind=="track" or kind=="target" or kind=="revised" then
    local name,program,notes=rest:match("^([^|]+)|(%d+)|(.+)$")
    if not name or not program or not parse_notes(notes) then return false,"Unvollständige oder ungültige Notenliste" end
    found=true
   elseif kind~="unchanged" then return false,"Unbekannter CS-Typ" end
  elseif not line:match("^CSMETA|") and not line:match("^CSCTRL|") then
   return false,"Zusätzlicher Text statt Daten"
  end
 end
 return found,nil
end
-- BEGIN MODULE EXPORTS
return {analysis_prompt=analysis_prompt,composition_prompt=composition_prompt,midi_translation_prompt=midi_translation_prompt,numbered_measure_count=numbered_measure_count,chunk_prompt=chunk_prompt,check_translation_chunk=check_translation_chunk}
end
