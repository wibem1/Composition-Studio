-- @description Native Notation Studio (standalone, preview and safe display offsets)
-- @version 0.1.0-test
-- @author Klangwerke
-- @about Independent REAPER action. No Composition Studio dependency.
-- This standalone test harness accepts DISPLAY rows from a prepared musical interpretation.
-- AI provider integration is not included in this first extraction.
local R=reaper
local function fail(message) R.ShowMessageBox(tostring(message),"Native Notation Studio",0) end
local function selected()
 local out={}
 for i=0,R.CountSelectedMediaItems(0)-1 do
  local item=R.GetSelectedMediaItem(0,i)
  local take=R.GetActiveTake(item)
  if take and R.TakeIsMIDI(take) then
   local ok,raw=R.MIDI_GetAllEvts(take)
   assert(ok,"MIDI-Ereignisse konnten nicht gelesen werden.")
   local notes={}
   local _,count=R.MIDI_CountEvts(take)
   for j=0,count-1 do
    local yes,_,_,a,b,ch,pitch,velocity=R.MIDI_GetNote(take,j)
    if yes then
     local start=R.MIDI_GetProjQNFromPPQPos(take,a)
     local finish=R.MIDI_GetProjQNFromPPQPos(take,b)
     notes[#notes+1]={start_qn=start,duration_qn=finish-start,channel=ch,pitch=pitch,velocity=velocity,ppq=a}
    end
   end
   out[#out+1]={item=item,take=take,raw=raw,notes=notes,
     start_qn=R.TimeMap2_timeToQN(0,R.GetMediaItemInfo_Value(item,"D_POSITION")),
     end_qn=R.TimeMap2_timeToQN(0,R.GetMediaItemInfo_Value(item,"D_POSITION")+R.GetMediaItemInfo_Value(item,"D_LENGTH"))}
  end
 end
 return out
end
local function parse(reply,targets)
 local plan,seen={},{}
 local function grid(v,n) return math.abs(v*n-math.floor(v*n+0.5))<0.0001 end
 for line in tostring(reply):gmatch("[^\r\n]+") do
  local id,s,d,certainty=line:match("^DISPLAY|(%d+)|([^|]+)|([^|]+)|([^|]+)$")
  id,s,d=tonumber(id),tonumber(s),tonumber(d)
  local t=id and targets[id]
  if t then
   local n=t.note
   local _,bar=R.TimeMap_QNToMeasures(0,s and s>=0 and s<1e8 and s or n.start_qn)
   if seen[id] then plan[id]=nil
   elseif certainty=="SICHER" and s and d and s==s and d==d and bar
     and s>=t.row.start_qn-1e-7 and s+d<=t.row.end_qn+1e-7
     and math.abs(s-n.start_qn)<=0.126 and d>=0.125 and d<=32
     and math.abs(d-n.duration_qn)<=math.min(0.5,n.duration_qn/2)
     and (grid(s-bar,8) or grid(s-bar,6))
     and (grid(d,8) or grid(d,6)) then
    plan[id]={start=s-n.start_qn,length=d-n.duration_qn}
   end
   seen[id]=true
  end
 end
 return plan
end
local function stream(raw,changes)
 local events,ons,metadata,after={}, {}, {}, {}
 local pos,tick=1,0
 local prefix=string.char(255,15)
 local function key(at,ch,pitch) return string.format("%d:%d:%d",at,ch,pitch) end
 while pos<=#raw do
  local first=pos
  local delta,flags,msg
  delta,flags,msg,pos=string.unpack("i4Bs4",raw,pos)
  tick=tick+delta
  local index=#events+1
  events[index]={raw=raw:sub(first,pos-1),delta=delta,flags=flags,msg=msg}
  local status,pitch,velocity=msg:byte(1,3)
  if #msg==3 and status>>4==9 and velocity>0 then
   local k=key(tick,status&15,pitch)
   ons[k]=ons[k]==nil and index or false
  elseif msg:sub(1,2)==prefix then
   local ch,p=msg:sub(3):match("^NOTE (%d+) (%d+)%f[%D]")
   if ch then
    local k=key(tick,tonumber(ch),tonumber(p))
    metadata[k]=metadata[k]==nil and index or false
   end
  end
 end
 local changed=0
 for _,edit in ipairs(changes) do
  local k=key(edit.tick,edit.channel,edit.pitch)
  local on,meta=ons[k],metadata[k]
  if on and meta~=false then
   local previous=meta and events[meta].msg
   if not previous or not (previous:find("%sdisp_pos%s") or previous:find("%sdisp_len%s")) then
    local fields=""
    if math.abs(edit.start)>0.00001 then fields=fields..string.format(" disp_pos %.9f",edit.start) end
    if math.abs(edit.length)>0.00001 then fields=fields..string.format(" disp_len %.9f",edit.length) end
    if fields~="" then
     if previous then
      local e=events[meta]
      e.raw=string.pack("i4Bs4",e.delta,e.flags,e.msg..fields)
     else
      after[on]=string.pack("i4Bs4",0,0,prefix..string.format("NOTE %d %d",edit.channel,edit.pitch)..fields)
     end
     changed=changed+1
    end
   end
  end
 end
 local out={}
 for i,e in ipairs(events) do
  out[#out+1]=e.raw
  if after[i] then out[#out+1]=after[i] end
 end
 return table.concat(out),changed
end
-- OpenAI Responses API, without placing API credentials in script files.
-- Requires curl and an OPENAI_API_KEY environment variable available to REAPER.
local function call_openai(promptPath)
 local file=assert(io.open(promptPath,"rb"))
 local prompt=file:read("*a");file:close()
 local function escape_json(value)
  return (value:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t"))
 end
 local root=R.GetResourcePath()
 local request=root.."/NativeNotationStudio-request.json"
 local output=root.."/NativeNotationStudio-response.json"
 local body=assert(io.open(request,"wb"))
 body:write('{"model":"gpt-5.4","input":"',escape_json(prompt),'"}')
 body:close()
 local windows=package.config:sub(1,1)=="\\"
 local cmd
 if windows then
  cmd='cmd.exe /C curl.exe -sS --fail-with-body --max-time 180 -X POST https://api.openai.com/v1/responses -H "Content-Type: application/json" -H "Authorization: Bearer %OPENAI_API_KEY%" --data-binary "@'..request..'" -o "'..output..'"'
 else
  cmd='/bin/sh -c '..string.format("%q",'/usr/bin/curl -sS --fail-with-body --max-time 180 -X POST https://api.openai.com/v1/responses -H "Content-Type: application/json" -H "Authorization: Bearer $OPENAI_API_KEY" --data-binary "@'..request..'" -o "'..output..'"')
 end
 local result=R.ExecProcess(cmd,190000)
 os.remove(request)
 assert(type(result)=="string","KI-Aufruf konnte nicht ausgeführt werden.")
 local f=assert(io.open(output,"rb"),"Keine Antwort vom KI-Dienst.")
 local data=f:read("*a");f:close()
 -- Decode JSON string values without interpreting escaped text as JSON structure.
 local function strings(json)
  local out={}
  local i=1
  while i<=#json do
   if json:sub(i,i)=='"' then
    local j=i+1
    local decoded={}
    while j<=#json do
     local c=json:sub(j,j)
     if c=='"' then break end
     if c=="\\" then
      j=j+1
      local e=json:sub(j,j)
      if e=="n" then c="\n" elseif e=="r" then c="\r" elseif e=="t" then c="\t" else c=e end
     end
     decoded[#decoded+1]=c
     j=j+1
    end
    out[#out+1]={value=table.concat(decoded),finish=j}
    i=j+1
   else i=i+1 end
  end
  return out
 end
 local tokens=strings(data)
 for i=1,#tokens-1 do
  if tokens[i].value=="text" then
   local gap=data:sub(tokens[i].finish+1,data:find('"',tokens[i].finish+1,true) or #data)
   if gap:match("^%s*:%s*") and tokens[i+1].value:find("DISPLAY|",1,true) then return tokens[i+1].value end
  end
 end
 error("Keine gültige DISPLAY-Antwort erhalten. Bitte API-Konfiguration und Antwortdatei prüfen: "..output)
end

local function run()
 local rows=selected()
 assert(#rows>0,"Bitte mindestens ein MIDI-Item auswählen.")
 local targets={}
 for _,row in ipairs(rows) do
  for _,note in ipairs(row.notes) do
   if #targets>=500 then break end
   targets[#targets+1]={row=row,note=note}
  end
 end
 assert(#targets>0,"Keine MIDI-Noten gefunden.")
 local lines={}
 for i,t in ipairs(targets) do
  local n=t.note
  lines[#lines+1]=string.format("%d | Start %.9f | Dauer %.9f | Ton %d | Kanal %d",i,n.start_qn,n.duration_qn,n.pitch,n.channel)
 end
 local path=R.GetResourcePath().."/NativeNotationStudio-notes.txt"
 local file=assert(io.open(path,"wb"))
 file:write("NATIVE NOTATION STUDIO - Noteninventar\n",table.concat(lines,"\n"),"\n")
 file:close()
 local promptPath=R.GetResourcePath().."/NativeNotationStudio-prompt.txt"
 local promptFile=assert(io.open(promptPath,"wb"))
 promptFile:write([[Du bist ein Experte fuer klassische Musiknotation. Rekonstruiere fuer jede MIDI-Note den musikalisch gemeinten Einsatz und Notenwert anhand der gesamten Phrase, nicht anhand einer pauschalen Quantisierung. Unterscheide Melodie, Bass, Begleitung, Mittelstimmen und expressive Timingabweichungen. Unklare Noten, Vorschlagsnoten und mehrdeutige Faelle nicht veraendern. Gib ausschliesslich Zeilen im Format DISPLAY|ID|Start_QN|Dauer_QN|SICHER aus. Jede Zeile muss sich auf die unten genannte Originalnote beziehen. Keine erfundenen Noten. Die Antwort wird vor dem Schreiben streng validiert.
]],"\n",table.concat(lines,"\n"),"\n")
 promptFile:close()
 local mode=R.ShowMessageBox("KI automatisch aufrufen?\nJa: OpenAI (Umgebungsvariable OPENAI_API_KEY).\nNein: vorbereitete DISPLAY-Datei verwenden.\nAbbrechen: nichts ändern.","Native Notation Studio",3)
 if mode==2 then return end
 local response
 if mode==6 then
  response=call_openai(promptPath)
 else
  local ok,value=R.GetUserInputs("Native Notation Studio - Test",1,"DISPLAY-Zeilen-Datei (vollständiger Pfad):","")
  if not ok then return end
  local input=assert(io.open(value,"rb"),"DISPLAY-Datei nicht lesbar.")
  response=input:read("*a");input:close()
 end

 local plan=parse(response,targets)
 local edits,counts={},{}
 for i,t in ipairs(targets) do
  local p=plan[i]
  if p then
   local n,row=t.note,t.row
   local tick=R.MIDI_GetPPQPosFromProjQN(row.take,n.start_qn)
   local integer=math.floor(tick+0.5)
   if math.abs(tick-integer)<0.0001 then
    edits[row]=edits[row] or {}
    counts[row]=counts[row] or {}
    local k=string.format("%d:%d:%d",integer,n.channel,n.pitch)
    counts[row][k]=(counts[row][k] or 0)+1
    edits[row][#edits[row]+1]={key=k,tick=integer,channel=n.channel,pitch=n.pitch,start=p.start,length=p.length}
   end
  end
 end
 local writes,changed={},0
 for row,changes in pairs(edits) do
  local yes,now=R.MIDI_GetAllEvts(row.take)
  assert(yes and now==row.raw,"Quell-MIDI wurde verändert; Vorgang abgebrochen.")
  local unique={}
  for _,edit in ipairs(changes) do if counts[row][edit.key]==1 then unique[#unique+1]=edit end end
  local output,n=stream(now,unique)
  if n>0 then writes[#writes+1]={row=row,before=now,after=output};changed=changed+n end
 end
 if changed==0 then fail("Keine sicheren Anzeigeänderungen. Noteninventar: "..path);return end
 local choice=R.ShowMessageBox(changed.." Anzeige-Offsets setzen? Originalnoten bleiben erhalten.\nNoteninventar: "..path,"Native Notation Studio",4)
 if choice~=6 then return end
 R.Undo_BeginBlock2(0)
 local attempted=0
 local okWrite,why=pcall(function()
  for i,w in ipairs(writes) do
   attempted=i
   local yes,now=R.MIDI_GetAllEvts(w.row.take)
   assert(yes and now==w.before,"Quell-MIDI wurde inzwischen verändert.")
   assert(R.MIDI_SetAllEvts(w.row.take,w.after),"Schreiben fehlgeschlagen.")
   local check,actual=R.MIDI_GetAllEvts(w.row.take)
   assert(check and actual==w.after,"Schreibprüfung fehlgeschlagen.")
  end
 end)
 if not okWrite then
  for i=attempted,1,-1 do R.MIDI_SetAllEvts(writes[i].row.take,writes[i].before) end
 end
 R.Undo_EndBlock2(0,okWrite and "Native Notation Studio" or "Native Notation Studio: Rücknahme",4)
 for _,w in ipairs(writes) do R.UpdateItemInProject(w.row.item) end
 assert(okWrite,why)
 fail(changed.." Anzeigeänderungen geschrieben. REAPER Undo kann sie rückgängig machen.")
end
local ok,err=xpcall(run,debug.traceback)
if not ok then fail(err) end
