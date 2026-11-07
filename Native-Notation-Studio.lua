-- @description Native Notation Studio - Lesbare Notation erstellen
-- @version 0.1.0-test
-- @author Klangwerke
-- @about Independent REAPER action. No Composition Studio dependency.
-- Experimental standalone action: OpenAI API or prepared DISPLAY rows.
-- Technically simulated test candidate; native REAPER acceptance remains required.
local R=reaper
local project=R.EnumProjects(-1, "")
local MAX_RESPONSE=1024*1024
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function fail(message) R.ShowMessageBox(tostring(message),"Native Notation Studio",0) end
local function selected()
 local out={}
 local editor=assert(R.MIDIEditor_GetActive(),"Bitte den MIDI-/Notationseditor mit den gewuenschten Tracks oeffnen.")
 local takes,seen={},{}
 assert(R.MIDIEditor_EnumTakes,"REAPER mit MIDIEditor_EnumTakes wird benoetigt.")
 for i=0,65535 do
  local take=R.MIDIEditor_EnumTakes(editor,i,false)
  if not take then break end
  if not seen[take] then takes[#takes+1]=take;seen[take]=true end
 end
 for _,take in ipairs(takes) do
  local item=R.GetMediaItemTake_Item(take)
  if take and R.TakeIsMIDI(take) then
   local ok,raw=R.MIDI_GetAllEvts(take)
   assert(ok,"MIDI-Ereignisse konnten nicht gelesen werden.")
   assert(R.GetMediaItemTakeInfo_Value(take,"D_PLAYRATE")==1,"Take-Playrate ungleich 1 wird noch nicht unterstuetzt.")
   local chunkOK,chunk=R.GetItemStateChunk(item,"",false)
   assert(chunkOK,"Item-Quellschutz konnte nicht geprueft werden.")
   local pool=chunk:match("POOLEDEVTS%s+{([^}]+)}")
   assert(not pool or not pool:gsub("[0%-]",""):match("%w"),"Gepoolte MIDI-Quellen werden zum Schutz weiterer Items nicht bearbeitet.")
   assert(R.GetMediaItemInfo_Value(item,"B_LOOPSRC")==0,"Geloopte MIDI-Items bitte zuerst entloopen; keine Aenderung.")
   local notes={}
   local _,count=R.MIDI_CountEvts(take)
   for j=0,count-1 do
    local yes,sel,_,a,b,ch,pitch,velocity=R.MIDI_GetNote(take,j)
    if yes then
     local start=R.MIDI_GetProjQNFromPPQPos(take,a)
     local finish=R.MIDI_GetProjQNFromPPQPos(take,b)
     notes[#notes+1]={start_qn=start,duration_qn=finish-start,channel=ch,pitch=pitch,velocity=velocity,ppq=a,selected=sel}
    end
   end
   out[#out+1]={item=item,take=take,raw=raw,notes=notes,
     position=R.GetMediaItemInfo_Value(item,"D_POSITION"), length=R.GetMediaItemInfo_Value(item,"D_LENGTH"),
     rate=R.GetMediaItemTakeInfo_Value(take,"D_PLAYRATE"), offset=R.GetMediaItemTakeInfo_Value(take,"D_STARTOFFS"),
     start_qn=R.TimeMap2_timeToQN(project,R.GetMediaItemInfo_Value(item,"D_POSITION")),
     end_qn=R.TimeMap2_timeToQN(project,R.GetMediaItemInfo_Value(item,"D_POSITION")+R.GetMediaItemInfo_Value(item,"D_LENGTH"))}
  end
 end
 return out,editor
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
   local _,bar=R.TimeMap_QNToMeasures(project,s and s>=0 and s<1e8 and s or n.start_qn)
   if seen[id] then plan[id]=nil
   elseif certainty=="SICHER" and finite(s) and finite(d) and bar
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
   if ons[k]==nil then ons[k]=index else ons[k]=false end
  elseif msg:sub(1,2)==prefix then
   local ch,p=msg:sub(3):match("^NOTE (%d+) (%d+)%f[%D]")
   if ch then
    local k=key(tick,tonumber(ch),tonumber(p))
    if metadata[k]==nil then metadata[k]=index else metadata[k]=false end
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
local function decode_json(src)
 assert(type(src)=="string" and utf8.len(src),"JSON enthaelt ungueltiges UTF-8.")
 local s=tostring(src or ""):gsub("^[ \t\r\n]+",""):gsub("[ \t\r\n]+$","")
 local i,n,depth=1,#s,0
 local function ws() while i<=n and s:sub(i,i):match("[ \t\r\n]") do i=i+1 end end
 local function bad(m) error("JSON Zeichen "..i..": "..m,0) end
 local function quote()
  if s:sub(i,i)~='"' then bad("Text erwartet") end
  i=i+1;local out={}
  while i<=n do
   local ch=s:sub(i,i);i=i+1
   if ch=='"' then return table.concat(out) end
   if ch=="\\" then
    local x=s:sub(i,i);i=i+1
    local esc={['"']='"',["\\"]="\\",["/"]="/",b="\b",f="\f",n="\n",r="\r",t="\t"}
    if esc[x] then out[#out+1]=esc[x]
    elseif x=="u" then
     local hex=s:sub(i,i+3)
     if not hex:match("^%x%x%x%x$") then bad("Unicode-Escape") end
     local cp=tonumber(hex,16);i=i+4
     if cp>=0xD800 and cp<=0xDBFF and s:sub(i,i+1)=="\\u" then
      local lo=tonumber(s:sub(i+2,i+5),16)
      if lo and lo>=0xDC00 and lo<=0xDFFF then cp=0x10000+(cp-0xD800)*1024+lo-0xDC00;i=i+6 end
     end
     if cp>=0xD800 and cp<=0xDFFF then bad("Unicode-Surrogat") end
     out[#out+1]=utf8.char(cp)
    else bad("Escape") end
   else
    if ch:byte()<32 then bad("Steuerzeichen") end
    out[#out+1]=ch
   end
  end
  bad("Text nicht abgeschlossen")
 end
 local parse
 parse=function()
  depth=depth+1;if depth>48 then bad("Verschachtelung") end;ws()
  local ch=s:sub(i,i);local out
  if ch=='"' then out=quote()
  elseif ch=="{" then
   i=i+1;out={};ws()
   if s:sub(i,i)=="}" then i=i+1 else
    while true do
     ws();local k=quote();ws()
     if s:sub(i,i)~=":" then bad("Doppelpunkt") end
     if out[k]~=nil then bad("Doppelter Schluessel") end
     i=i+1;out[k]=parse();ws()
     local sep=s:sub(i,i);i=i+1
     if sep=="}" then break end
     if sep~="," then bad("Komma oder }") end
    end
   end
  elseif ch=="[" then
   i=i+1;out={};ws()
   if s:sub(i,i)=="]" then i=i+1 else
    while true do
     out[#out+1]=parse();ws()
     local sep=s:sub(i,i);i=i+1
     if sep=="]" then break end
     if sep~="," then bad("Komma oder ]") end
    end
   end
  elseif s:sub(i,i+3)=="true" then i=i+4;out=true
  elseif s:sub(i,i+4)=="false" then i=i+5;out=false
  elseif s:sub(i,i+3)=="null" then i=i+4;out=false
  else
   local token=s:sub(i):match("^-?%d+%.?%d*[eE]?[+%-]?%d*") or s:sub(i):match("^-?%.%d+[eE]?[+%-]?%d*")
   if not token or token=="" then bad("Wert") end
   local mant,exp=token:match("^(.-)[eE](.*)$")
   mant=mant or token
   if not mant:match("^-?%d+$") and not mant:match("^-?%d+%.%d+$") then bad("Zahl") end
   if mant:match("^-?0%d") or (exp and not exp:match("^[+%-]?%d+$")) then bad("Zahl") end
   out=tonumber(token);if not finite(out) then bad("Zahl") end;i=i+#token
  end
  depth=depth-1;return out
 end
 local value=parse();ws()
 if i<=n then bad("Zeichen nach JSON") end
 return value
end
local function json_string(value)
 return '"'..value:gsub('[%z\1-\31\\"]',function(c)
  return string.format("\\u%04x",c:byte())
 end)..'"'
end
local function response_text(data)
 assert(#data<=MAX_RESPONSE,"KI-Antwort ist zu gross.")
 local obj=decode_json(data)
 assert(type(obj)=="table" and not obj.error,"KI-Dienst meldet einen Fehler.")
 assert(obj.status=="completed","KI-Antwort ist nicht vollstaendig abgeschlossen.")
 local result={}
 assert(type(obj.output)=="table","KI-Antwort ohne Ausgabe.")
 for _,message in ipairs(obj.output) do
  if message.type=="message" and message.role=="assistant" then
   assert(message.status=="completed","Unvollstaendige Nachricht.")
   for _,part in ipairs(message.content or {}) do
    assert(part.type~="refusal","KI-Dienst hat die Anfrage abgelehnt.")
    if part.type=="output_text" then
     assert(type(part.text)=="string","Antworttext fehlt.")
     result[#result+1]=part.text
    end
   end
  end
 end
 assert(#result>0,"Keine Textantwort vom KI-Dienst.")
 return table.concat(result,"\n")
end
local function write_file(path,data)
 local f=assert(io.open(path,"wb"),"Datei nicht schreibbar: "..path)
 local ok,why=f:write(data);local closed=f:close()
 assert(ok and closed,why or "Datei konnte nicht gespeichert werden.")
end
local function read_file(path,limit)
 local f=io.open(path,"rb");if not f then return nil end
 local data=f:read((limit or MAX_RESPONSE)+1) or "";f:close()
 assert(#data<=(limit or MAX_RESPONSE),"Datei ist zu gross.")
 return data
end
local function quote_sh(s) return "'"..s:gsub("'","'\\''").."'" end
local function quote_ps(s) return "'"..s:gsub("'","''").."'" end
-- ExecProcess parses executable arguments, not shell expressions. Scripts contain
-- literal quoted paths; credentials are expanded by the child, never stored here.
local function transport_files(base,windows,prompt,model)
 local req,out,done,script=base..".json",base..".response",base..".done",base..(windows and ".ps1" or ".sh")
 write_file(req,'{"model":'..json_string(model)..',"store":false,"max_output_tokens":6000,"input":'..json_string(prompt)..'}')
 local args=' -q -sS --fail-with-body --connect-timeout 15 --max-time 90 --max-filesize 1048576 --retry 0 '
 local command,body
 if windows then
  local q=quote_ps
  body="$ErrorActionPreference='Stop'\r\n$code=999\r\ntry {\r\n& ($env:SystemRoot + '/System32/curl.exe')"..args..
   " -H 'Content-Type: application/json' -H (\"Authorization: Bearer \" + $env:OPENAI_API_KEY) --data-binary "..q('@'..req).." -o "..q(out).." 'https://api.openai.com/v1/responses'\r\n$code=$LASTEXITCODE\r\n} finally {\r\n[IO.File]::WriteAllText("..q(done..".pending")..",[string]$code)\r\nMove-Item -LiteralPath "..q(done..".pending").." -Destination "..q(done).." -Force\r\n}\r\n"
  local root=os.getenv("SystemRoot") or "C:/Windows"
  assert(not root:find('["\r\n]'),"Ungueltiger SystemRoot.")
  command='"'..root..'/System32/WindowsPowerShell/v1.0/powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "'..script..'"'
  body="\239\187\191"..body
 else
  body='/usr/bin/curl'..args..' -H \'Content-Type: application/json\' -H "Authorization: Bearer $OPENAI_API_KEY" --data-binary '..quote_sh('@'..req)..' -o '..quote_sh(out)..' https://api.openai.com/v1/responses\nprintf "%s" "$?" > '..quote_sh(done..'.pending')..'\nmv -f '..quote_sh(done..'.pending')..' '..quote_sh(done)..'\n'
  command='/bin/sh "'..script..'"'
 end
 assert(not script:find('["\r\n]'),"Nicht unterstuetzte Zeichen im Temporaerpfad.")
 write_file(script,body)
 return {request=req,output=out,done=done,script=script,command=command}
end
local function cleanup(job)
 for _,k in ipairs({"request","output","done","script"}) do os.remove(job[k]) end
 os.remove(job.done..".pending")
end
local function call_openai(prompt,complete)
 local key=os.getenv("OPENAI_API_KEY")
 assert(key and key:match("%S") and not key:find("[\r\n]"),"OPENAI_API_KEY fehlt in der REAPER-Umgebung.")
 local model=os.getenv("NATIVE_NOTATION_MODEL") or "gpt-5.4"
 assert(model:match("^[%w._%-]+$"),"Ungueltige Modellkennung.")
 local base=R.GetResourcePath().."/NNS-"..R.genGuid():gsub("[^%w]","")
 local job=transport_files(base,R.GetOS():match("Win")~=nil,prompt,model)
 local started,result=pcall(R.ExecProcess,job.command,-2)
 if not started or result==nil then cleanup(job);error("KI-Hintergrundprozess konnte nicht starten.") end
 local cancelled=false
 local began=R.time_precise()
 gfx.init("Lesbare Notation erstellen",440,100)
 R.atexit(function() cancelled=true;gfx.quit() end)
 local function poll()
  local ok,err=pcall(function()
   local ch=gfx.getchar()
   if ch<0 or ch==27 or gfx.mouse_cap&1==1 then cancelled=true;gfx.quit() end
   if not cancelled then
    gfx.x,gfx.y=12,15;gfx.drawstr("Musikalische Interpretation laeuft …\nAbbrechen: Esc oder Fenster anklicken")
    gfx.update()
   end
   local code=read_file(job.done,64)
   if code and tonumber(code:match("^%s*(%d+)%s*$")) then
    local data=tonumber(code)==0 and read_file(job.output) or nil
    cleanup(job);gfx.quit()
    if cancelled then return end
    assert(tonumber(code)==0,"KI-Transport fehlgeschlagen (Exitcode "..code..").")
    assert(data,"Keine Antwort vom KI-Dienst.")
    complete(response_text(data));return
   end
   if R.time_precise()-began>100 then
    gfx.quit()
    error("KI-Transport: Zeitlimit. Keine Aenderung; temporaere Diagnose: "..base)
   end
   R.defer(poll)
  end)
  if not ok then gfx.quit();fail(err) end
 end
 R.defer(poll)
end
local function source_guard(rows,tempo)
 assert(R.EnumProjects(-1,"")==project,"Aktives Projekt wurde gewechselt.")
 assert(R.GetProjectStateChangeCount(project)==tempo,"Projekt wurde waehrend der Analyse geaendert.")
 for _,row in ipairs(rows) do
  assert(R.ValidatePtr2(project,row.item,"MediaItem*") and R.ValidatePtr2(project,row.take,"MediaItem_Take*"),"MIDI-Quelle existiert nicht mehr.")
  assert(R.GetMediaItemTake_Item(row.take)==row.item,"Aktiver Take wurde gewechselt.")
  local ok,raw=R.MIDI_GetAllEvts(row.take)
  assert(ok and raw==row.raw,"Quell-MIDI wurde veraendert.")
  assert(R.GetMediaItemInfo_Value(row.item,"D_POSITION")==row.position and R.GetMediaItemInfo_Value(row.item,"D_LENGTH")==row.length
   and R.GetMediaItemTakeInfo_Value(row.take,"D_PLAYRATE")==row.rate and R.GetMediaItemTakeInfo_Value(row.take,"D_STARTOFFS")==row.offset,"Item-Zeitbezug wurde geaendert.")
 end
end

local function prepare_view(editor)
 local section=assert(R.SectionFromUniqueID(32060),"MIDI-Aktionsbereich fehlt.")
 local mode,spacing
 for i=0,19999 do
  local id,label=R.kbd_enumerateActions(section,i)
  if not id or id==0 then break end
  label=(label or ""):lower()
  if label=="view: mode: musical notation" or label=="view: mode: notation" or label=="mode: notation" then mode=id end
  if label=="notation: proportional (musical) note spacing" then spacing=id end
 end
 assert(mode and spacing,"Native Notationsaktionen fehlen; keine Aenderung.")
 return function()
  R.MIDIEditor_OnCommand(editor,mode)
  if R.GetToggleCommandStateEx(32060,spacing)==0 then R.MIDIEditor_OnCommand(editor,spacing) end
 end
end
local function run()
 local rows,editor=selected()
 assert(#rows>0,"Keine dargestellten MIDI-Takes gefunden.")
 local show=prepare_view(editor)
 local targets={}
 for _,row in ipairs(rows) do
  for _,note in ipairs(row.notes) do
   assert(#targets<500,"Mehr als 500 Noten in den dargestellten Tracks: Analysegrenze erreicht. Keine Teilbearbeitung.")
   targets[#targets+1]={row=row,note=note}
  end
 end
 assert(#targets>0,"Keine MIDI-Noten gefunden.")
 assert(#targets<=500,"Analyseumfang ueberschritten.")
 local row_ids={}
 for i,row in ipairs(rows) do row_ids[row]=i end
 local lines={}
 for i,t in ipairs(targets) do
  local n=t.note
  local measure,bar,barend=R.TimeMap_QNToMeasures(project,n.start_qn)
  lines[#lines+1]=string.format("Take %d | ",row_ids[t.row])..string.format("Takt %d | Taktgrenzen %.9f %.9f | ",measure+1,bar,barend)..string.format("ID %d | Start %.9f | Dauer %.9f | Ton %d | Kanal %d | Velocity %d",i,n.start_qn,n.duration_qn,n.pitch,n.channel,n.velocity)
 end
 local path=R.GetResourcePath().."/NativeNotationStudio-notes.txt"
 write_file(path,"NATIVE NOTATION STUDIO - Noteninventar\n"..table.concat(lines,"\n").."\n")
 local promptPath=R.GetResourcePath().."/NativeNotationStudio-prompt.txt"
 write_file(promptPath,[[Du bist ein Experte fuer klassische Musiknotation. Rekonstruiere fuer jede MIDI-Note den musikalisch gemeinten Einsatz und Notenwert anhand der gesamten Phrase, nicht anhand einer pauschalen Quantisierung. Unterscheide Melodie, Bass, Begleitung, Mittelstimmen und expressive Timingabweichungen. Unklare Noten, Vorschlagsnoten und mehrdeutige Faelle nicht veraendern. Gib ausschliesslich Zeilen im Format DISPLAY|ID|Start_QN|Dauer_QN|SICHER aus. Jede Zeile muss sich auf die unten genannte Originalnote beziehen. Keine erfundenen Noten. Die Antwort wird vor dem Schreiben streng validiert.
]].."\n"..table.concat(lines,"\n").."\n")
 local stamp=R.GetProjectStateChangeCount(project)
 local function complete(response)
 source_guard(rows,stamp)
 local focused=R.MIDIEditor_GetActive()
 assert(R.MIDIEditor_GetMode(editor)~=-1 and (not focused or focused==editor),"Editor wurde geschlossen oder gewechselt.")
 local current={}
 for i=0,65535 do local tk=R.MIDIEditor_EnumTakes(editor,i,false);if not tk then break end;current[tk]=true end
 for _,row in ipairs(rows) do assert(current[row.take],"Dargestellte Tracks wurden geaendert.");current[row.take]=nil end
 assert(next(current)==nil,"Dargestellte Tracks wurden geaendert.")
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
 for _,row in ipairs(rows) do
  local changes=edits[row] or {}
  local yes,now=R.MIDI_GetAllEvts(row.take)
  assert(yes and now==row.raw,"Quell-MIDI wurde verändert; Vorgang abgebrochen.")
  local unique={}
  for _,edit in ipairs(changes) do if counts[row][edit.key]==1 then unique[#unique+1]=edit end end
  local output,n=stream(now,unique)
  if n>0 then writes[#writes+1]={row=row,before=now,after=output};changed=changed+n end
 end
 if changed==0 then show();fail("Keine sicheren Anzeigeänderungen. Noteninventar: "..path);return end
 source_guard(rows,stamp)
 local focused=R.MIDIEditor_GetActive()
 assert(R.MIDIEditor_GetMode(editor)~=-1 and (not focused or focused==editor),"Editor wurde geschlossen oder gewechselt.")
 local current={}
 for i=0,65535 do local tk=R.MIDIEditor_EnumTakes(editor,i,false);if not tk then break end;current[tk]=true end
 for _,row in ipairs(rows) do assert(current[row.take],"Dargestellte Tracks wurden geaendert.");current[row.take]=nil end
 assert(next(current)==nil,"Dargestellte Tracks wurden geaendert.")
 R.Undo_BeginBlock2(project)
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
  local errors={}
  for i=attempted,1,-1 do
   local w=writes[i]
   local restored=pcall(function()
    assert(R.MIDI_SetAllEvts(w.row.take,w.before))
    local yes,raw=R.MIDI_GetAllEvts(w.row.take);assert(yes and raw==w.before)
   end)
   if not restored then errors[#errors+1]=tostring(i) end
  end
  if #errors>0 then why=tostring(why).."\nWiederherstellung fehlgeschlagen fuer Takes "..table.concat(errors,",")..". Bitte sofort REAPER Undo verwenden." end
 end
 R.Undo_EndBlock2(project,okWrite and "Native Notation Studio" or "Native Notation Studio: Rücknahme",4)
 for _,w in ipairs(writes) do R.UpdateItemInProject(w.row.item) end
 assert(okWrite,why)
 show()
 fail(changed.." Anzeigeänderungen geschrieben. REAPER Undo kann sie rückgängig machen.")
 end
 -- Prepared response is a deterministic test hook, never the normal UI path.
 local fixture=R.GetExtState("NativeNotationStudio","TestResponseFile")
 if fixture~="" then
  complete(assert(read_file(fixture),"DISPLAY-Testdatei nicht lesbar."))
 else
  call_openai(assert(read_file(promptPath)),complete)
 end
end
local exports={parse=parse,stream=stream,decode_json=decode_json,response_text=response_text,
 json_string=json_string,transport_files=transport_files,selected=selected,run=run,source_guard=source_guard,call_openai=call_openai}
if _G.NATIVE_NOTATION_TEST then return exports end
local ok,err=xpcall(run,debug.traceback)
if not ok then fail(err) end
