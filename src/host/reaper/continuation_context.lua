local function compact_music_excerpt(items,endpoint)
 local first=math.max(0,endpoint-32)
 local rows={string.format("Musikausschnitt: QN %.3f bis %.3f; Tempo %.2f BPM",first,endpoint,reaper.Master_GetTempo())}
 for _,it in ipairs(items) do
  local part={"Stimme: "..tostring(it.track_name or "Instrument")}
  local notes={}
  for _,n in ipairs(it.notes or {}) do
   if n.start_qn>=first and n.start_qn<endpoint then notes[#notes+1]=n end
  end
  table.sort(notes,function(a,b) return a.start_qn<b.start_qn end)
  for i=math.max(1,#notes-80),#notes do
   local n=notes[i]
   if n then part[#part+1]=string.format("%.3f:%.3f:%d",n.start_qn-first,n.duration_qn,n.pitch) end
  end
  rows[#rows+1]=table.concat(part," ")
 end
 return table.concat(rows,"\n")
end
local function continuation_prompt(request,items,tracks,count,at)
 return [[Komponiere die musikalische Fortsetzung des vorhandenen Werks: GENAU ]]..count..[[ NEUE Takte.
Schreibe nur diese neuen ]]..count..[[ Takte als vollständige LilyPond-Partitur mit \score { ... }.
Die App setzt sie nach dem Ende des bisher vorhandenen Werks bei Viertelposition ]]..at..[[ ein.
Du darfst vorhandene Takte nicht nochmals ausgeben. Keine MIDI-QN-Codierung.
Nutze die übergebenen Originalnoten als musikalischen Kontext und entwickle
eine wirkliche Variation mit neuer melodischer Gestalt, verändertem Rhythmus
und einer dazugehörigen eigenständigen Begleitung. Keine reine Oktavierung,
keine bloße Transposition, keine starre Viertelkette.
Für ein Klavierstück notiere rechte und linke Hand in separaten Staves.
LilyPond muss ausführbar sein; nur Quellcode, keine Erläuterung.

AUFTRAG:
]]..request.."\n\nMUSIKALISCHER KONTEXT:\n"..compact_music_excerpt(items,at)
end

