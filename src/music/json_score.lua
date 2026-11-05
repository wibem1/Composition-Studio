return function(decode_engine_json)
local function engine_translate_json(answer)
 local ok,object=pcall(decode_engine_json,answer)
 if not ok then return nil,"Kompositions-JSON ungültig: "..tostring(object) end
 local score=type(object)=="table" and (object.score or object) or nil
 if type(score)~="table" or type(score.tracks)~="table" or #score.tracks<1 then return nil,"JSON enthält keine Spuren." end
 local function numeric(x) return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge end
 local bpm=tonumber(score.bpm)
 local ts=score.timeSignature or {4,4};local num,den=tonumber(ts[1]),tonumber(ts[2])
 if not numeric(bpm) or bpm<20 or bpm>400 then return nil,"Tempo ungültig." end
 if not numeric(num) or num%1~=0 or num<1 or num>32 or not numeric(den) or den%1~=0 or den<1 or den>64 then return nil,"Taktart ungültig." end
 local lines={"CSMETA|tempo|0|"..bpm,"CSMETA|timesig|0|"..num.."|"..den}
 if score.tempoEvents~=nil then
  if type(score.tempoEvents)~="table" then return nil,"Tempoereignisse müssen eine Liste sein." end
  for j,e in ipairs(score.tempoEvents) do
   local at=type(e)=="table" and tonumber(e.at)
   local value=type(e)=="table" and tonumber(e.bpm)
   if not numeric(at) or at<0 or not numeric(value) or value<20 or value>400 then return nil,"Ungültiges Tempoereignis "..j end
   lines[#lines+1]=string.format("CSMETA|tempo|%.6f|%.6f",at,value)
  end
 end
 if score.pedalEvents~=nil then
  if type(score.pedalEvents)~="table" then return nil,"Pedalereignisse müssen eine Liste sein." end
  for j,e in ipairs(score.pedalEvents) do
   local at=type(e)=="table" and tonumber(e.at)
   local value=type(e)=="table" and tonumber(e.value)
   if not numeric(at) or at<0 or not numeric(value) or value%1~=0 or value<0 or value>127 then return nil,"Ungültiges Pedalereignis "..j end
   for k,tr in ipairs(score.tracks) do
    local name=tostring(tr.name or ("Spur "..k)):gsub("[|\r\n]"," "):sub(1,120)
    local channel=tonumber(tr.channel or ((k-1)%16))
    if not numeric(channel) or channel%1~=0 or channel<0 or channel>15 then return nil,"Ungültiger Pedalkanal "..k end
    lines[#lines+1]=string.format("CSCTRL|%s|%.6f|%d|cc|64|%d",name,at,channel,value)
   end
  end
 end
 local count=0
 for k,tr in ipairs(score.tracks) do
  if type(tr)~="table" or type(tr.notes)~="table" then return nil,"Notenliste fehlt: Spur "..k end
  local name=tostring(tr.name or ("Spur "..k)):gsub("[|\r\n]"," "):sub(1,120)
  local pg,channel=tonumber(tr.program or 0),tonumber(tr.channel or ((k-1)%16))
  if not numeric(pg) or pg%1~=0 or pg<0 or pg>127 or not numeric(channel) or channel%1~=0 or channel<0 or channel>15 then return nil,"Ungültiges Programm oder Kanal: Spur "..k end
  if tr.ccEvents~=nil then
   if type(tr.ccEvents)~="table" then return nil,"Controller müssen eine Liste sein." end
   for j,e in ipairs(tr.ccEvents) do
    local at=type(e)=="table" and tonumber(e.at); local cc=type(e)=="table" and tonumber(e.controller); local v=type(e)=="table" and tonumber(e.value)
    if not numeric(at) or at<0 or not numeric(cc) or cc%1~=0 or cc<0 or cc>127 or not numeric(v) or v%1~=0 or v<0 or v>127 then return nil,"Ungültiges Controllerereignis in Spur "..k end
    lines[#lines+1]=string.format("CSCTRL|%s|%.6f|%d|cc|%d|%d",name,at,channel,cc,v)
   end
  end
  local notes={}
  for j,note in ipairs(tr.notes) do
   if type(note)~="table" or #note<4 then return nil,"Unvollständige Note "..j.." in Spur "..k end
   local st,dur,pitch,vel=tonumber(note[1]),tonumber(note[2]),tonumber(note[3]),tonumber(note[4])
   if not numeric(st) or st<0 or not numeric(dur) or dur<=0 or
      not numeric(pitch) or pitch%1~=0 or pitch<0 or pitch>127 or
      not numeric(vel) or vel%1~=0 or vel<1 or vel>127 then return nil,"Ungültige Note "..j.." in Spur "..k end
   notes[#notes+1]=string.format("%.6f,%.6f,%d,%d,%d",st,dur,pitch,vel,channel)
   count=count+1
  end
  if #notes>0 then lines[#lines+1]="CS|new|-|"..name.."|"..pg.."|"..table.concat(notes,";") end
 end
 if count==0 then return nil,"JSON enthält keine MIDI-Noten." end
 return table.concat(lines,"\n")
end
-- BEGIN MODULE EXPORTS
return {engine_translate_json=engine_translate_json}
end
