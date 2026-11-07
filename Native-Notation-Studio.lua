-- @description Native Notation Studio - Lesbare Notation erstellen
-- @version 0.1.0-test
-- @author Klangwerke
-- @about Independent REAPER action. No Composition Studio dependency.
-- Experimental standalone action: OpenAI API or prepared DISPLAY rows.
-- Offline and isolated REAPER 7.84/Linux runtime tested; visual/platform acceptance pending.
local R=reaper
local project=R.EnumProjects(-1, "")
local MAX_RESPONSE=1024*1024
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function fail(message) R.ShowMessageBox(tostring(message),"Native Notation Studio",0) end
-- A loop-source checkbox does not imply that the item actually repeats.
local function check_loop_extent(item,take,chunk)
 if R.GetMediaItemInfo_Value(item,"B_LOOPSRC")==0 then return end
 local source=assert(R.GetMediaItemTake_Source(take),"MIDI-Quelle fehlt.")
 local length,isQN=R.GetMediaSourceLength(source)
 assert(finite(length) and length>0,"MIDI-Quelllaenge ist nicht eindeutig.")
 local position=R.GetMediaItemInfo_Value(item,"D_POSITION")
 local finish=position+R.GetMediaItemInfo_Value(item,"D_LENGTH")
 local origin,first,last
 if isQN then
  assert(not chunk:match("IGNTEMPO%s+1%f[%D]"),"Loop-Quelle mit eigenem Tempo wird noch nicht unterstuetzt.")
  origin=R.MIDI_GetProjQNFromPPQPos(take,0)
  first=R.TimeMap2_timeToQN(project,position)
  last=R.TimeMap2_timeToQN(project,finish)
 else
  origin=R.MIDI_GetProjTimeFromPPQPos(take,0)
  first,last=position,finish
 end
 assert(finite(origin) and finite(first) and finite(last) and first>=origin-1e-7 and last<=origin+length+1e-7,
  "Tatsaechlich geloopte MIDI-Items werden noch nicht unterstuetzt. Keine Teilbearbeitung.")
end
local function check_note(a,b,ch,pitch,velocity)
 assert(finite(a) and finite(b) and b>a,"Ungueltige MIDI-Notenzeiten.")
 for _,v in ipairs({ch,pitch,velocity}) do assert(finite(v) and v%1==0,"Ungueltiger MIDI-Notenwert.") end
 assert(ch>=0 and ch<=15 and pitch>=0 and pitch<=127 and velocity>=1 and velocity<=127,"MIDI-Notenwert ausserhalb des Wertebereichs.")
end
-- Every in-project MIDI source has a pool identity, even when unpooled.
-- It is shared only when that identity occurs in multiple project takes.
local function project_pools()
 local counts,chunks={},{}
 for i=0,R.CountMediaItems(project)-1 do
  local item=R.GetMediaItem(project,i)
  local midi=false
  for j=0,R.CountTakes(item)-1 do if R.TakeIsMIDI(R.GetTake(item,j)) then midi=true;break end end
  if midi then
   local ok,chunk=R.GetItemStateChunk(item,"",false)
   assert(ok and type(chunk)=="string","MIDI-Pool-Inventar konnte nicht gelesen werden.")
   chunks[item]=chunk
   for id in chunk:gmatch("POOLEDEVTS%s+{([^}]+)}") do
    if id:gsub("[0%-]",""):match("%w") then
     id=id:upper();counts[id]=(counts[id] or 0)+1
    end
   end
  end
 end
 return counts,chunks
end
local stream
local function selected(viewOnly)
 local out={}
 local editor=assert(R.MIDIEditor_GetActive(),"Bitte den MIDI-/Notationseditor mit den gewuenschten Tracks oeffnen.")
 local pools,itemChunks={},{}
 if not viewOnly then pools,itemChunks=project_pools() end
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
   assert(ok and type(raw)=="string","MIDI-Ereignisse konnten nicht gelesen werden.")
   if not viewOnly then
   stream(raw,{}) -- Reject a damaged event buffer before any paid request.
   assert(R.GetMediaItemTakeInfo_Value(take,"D_PLAYRATE")==1,"Take-Playrate ungleich 1 wird noch nicht unterstuetzt.")
   local chunk=assert(itemChunks[item],"Item-Quellschutz konnte nicht geprueft werden.")
   for pool in chunk:gmatch("POOLEDEVTS%s+{([^}]+)}") do
    assert((pools[pool:upper()] or 0)<=1,"Tatsaechlich gepoolte MIDI-Quellen werden zum Schutz weiterer Items nicht bearbeitet.")
   end
   check_loop_extent(item,take,chunk)
   end
   local notes={}
   local counted,count=R.MIDI_CountEvts(take)
   assert(counted and finite(count) and count>=0 and count%1==0,"MIDI-Noteninventar konnte nicht gelesen werden.")
   for j=0,count-1 do
    local yes,sel,muted,a,b,ch,pitch,velocity=R.MIDI_GetNote(take,j)
    assert(yes,"MIDI-Note konnte nicht gelesen werden; keine Teilanalyse.")
    check_note(a,b,ch,pitch,velocity)
    if yes then
     local start=R.MIDI_GetProjQNFromPPQPos(take,a)
     local finish=R.MIDI_GetProjQNFromPPQPos(take,b)
     assert(finite(start) and finite(finish) and finish>start,"Ungueltiger musikalischer Zeitbezug.")
     notes[#notes+1]={start_qn=start,duration_qn=finish-start,channel=ch,pitch=pitch,velocity=velocity,ppq=a,selected=sel,muted=muted}
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
stream=function(raw,changes)
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
-- Windows first-run key setup. The secret is entered inside PowerShell's modal
-- password dialog and encrypted by Windows DPAPI for the current user.
-- The Lua process never receives or persists the plaintext credential.
local function windows_credential_path()
 local appdata=os.getenv("APPDATA")
 assert(appdata and appdata~="" and not appdata:find('[\r\n]'),"Windows APPDATA ist nicht verfuegbar.")
 return appdata:gsub("\\","/").."/NativeNotationStudio/api-key.dpapi"
end
local function windows_powershell_command(script,sta)
 local root=os.getenv("SystemRoot") or "C:/Windows"
 assert(not root:find('["\r\n]') and not script:find('["\r\n]'),"Ungueltiger PowerShell-Pfad.")
 return '"'..root..'/System32/WindowsPowerShell/v1.0/powershell.exe" -NoLogo -NoProfile -NonInteractive'..
  (sta and " -STA" or "")..' -ExecutionPolicy Bypass -WindowStyle Hidden -File "'..script..'"'
end
local function ensure_windows_credential()
 if os.getenv("OPENAI_API_KEY") and os.getenv("OPENAI_API_KEY"):match("%S") then return end
 local path=windows_credential_path()
 if read_file(path,32768) then return end
 local script=R.GetResourcePath().."/NNS-credential-"..R.genGuid():gsub("[^%w]","")..".ps1"
 local q=quote_ps
 local body=[[
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Native Notation Studio - OpenAI API-Key'
$form.Width = 510
$form.Height = 190
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$label = New-Object System.Windows.Forms.Label
$label.Text = 'API-Key einmal eingeben (wird fuer dieses Windows-Konto geschuetzt gespeichert):'
$label.AutoSize = $true
$label.Left = 16
$label.Top = 16
$form.Controls.Add($label)
$input = New-Object System.Windows.Forms.TextBox
$input.Left = 16
$input.Top = 44
$input.Width = 460
$input.UseSystemPasswordChar = $true
$form.Controls.Add($input)
$save = New-Object System.Windows.Forms.Button
$save.Text = 'Speichern'
$save.Left = 292
$save.Top = 83
$save.Width = 88
$save.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($save)
$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = 'Abbrechen'
$cancel.Left = 388
$cancel.Top = 83
$cancel.Width = 88
$cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($cancel)
$form.AcceptButton = $save
$form.CancelButton = $cancel
$form.Add_Shown({ $input.Focus() })
if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit 2 }
if (-not $input.Text.StartsWith('sk-') -or $input.Text.Length -lt 20) {
 [System.Windows.Forms.MessageBox]::Show('Bitte einen gueltigen OpenAI API-Key eingeben.')
 exit 3
}
$secret = ConvertTo-SecureString -String $input.Text -AsPlainText -Force
$encrypted = ConvertFrom-SecureString -SecureString $secret
$folder = [IO.Path]::GetDirectoryName(__PATH__)
[IO.Directory]::CreateDirectory($folder) | Out-Null
[IO.File]::WriteAllText(__PATH__, $encrypted, [Text.Encoding]::ASCII)
$input.Clear()
]] 
 body=body:gsub("__PATH__",function() return q(path) end)
 write_file(script,"\239\187\191"..body)
 local ok,result=pcall(R.ExecProcess,windows_powershell_command(script,true),120000)
 os.remove(script)
 assert(ok and result~=nil,"API-Key-Dialog konnte nicht ausgefuehrt werden.")
 assert(read_file(path,32768),"API-Key wurde nicht gespeichert. Eingabe abgebrochen oder ungueltig.")
end
-- ExecProcess parses executable arguments, not shell expressions. Scripts contain
-- literal quoted paths; credentials are expanded by the child, never stored here.
local function transport_files(base,windows,prompt,model)
 local req,out,done,script=base..".json",base..".response",base..".done",base..(windows and ".ps1" or ".sh")
 write_file(req,'{"model":'..json_string(model)..',"store":false,"max_output_tokens":6000,"input":'..json_string(prompt)..'}')
 local args=' -q -sS --fail-with-body --connect-timeout 15 --max-time 90 --max-filesize 1048576 --retry 0 '
 local command,body
 if windows then
  local q=quote_ps
  body="$ErrorActionPreference='Stop'\r\n$code=999\r\ntry {\r\n"..
   "$key=$env:OPENAI_API_KEY\r\nif ([string]::IsNullOrWhiteSpace($key)) {\r\n"..
   "$encrypted=[IO.File]::ReadAllText("..q(windows_credential_path())..")\r\n"..
   "$secure=ConvertTo-SecureString -String $encrypted\r\n"..
   "$ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)\r\n"..
   "try { $key=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }\r\n}\r\n"..
   "& ($env:SystemRoot + '/System32/curl.exe')"..args..
   " -H 'Content-Type: application/json' -H (\"Authorization: Bearer \" + $key) --data-binary "..q('@'..req).." -o "..q(out).." 'https://api.openai.com/v1/responses'\r\n$code=$LASTEXITCODE\r\n} finally {\r\n[IO.File]::WriteAllText("..q(done..".pending")..",[string]$code)\r\nMove-Item -LiteralPath "..q(done..".pending").." -Destination "..q(done).. " -Force\r\n}\r\n"
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
 if R.GetOS():match("Win") then
  if key and key:find("[\r\n]") then error("Ungueltiger OPENAI_API_KEY.") end
  ensure_windows_credential()
 else
  assert(key and key:match("%S") and not key:find("[\r\n]"),"OPENAI_API_KEY fehlt in der REAPER-Umgebung.")
 end
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
    if cancelled then cleanup(job);gfx.quit();return end
    local readOK,data=pcall(function() return tonumber(code)==0 and read_file(job.output) or nil end)
    cleanup(job);gfx.quit()
    assert(readOK,data)
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
  assert(R.GetMediaItemTake_Item(row.take)==row.item,"Take-Item-Zuordnung wurde geaendert.")
  local ok,raw=R.MIDI_GetAllEvts(row.take)
  assert(ok and raw==row.raw,"Quell-MIDI wurde veraendert.")
  assert(R.GetMediaItemInfo_Value(row.item,"D_POSITION")==row.position and R.GetMediaItemInfo_Value(row.item,"D_LENGTH")==row.length
   and R.GetMediaItemTakeInfo_Value(row.take,"D_PLAYRATE")==row.rate and R.GetMediaItemTakeInfo_Value(row.take,"D_STARTOFFS")==row.offset,"Item-Zeitbezug wurde geaendert.")
 end
end

-- Only the second field of the TRACK-level SCORE line is edited. Nested item,
-- plugin and source chunks are retained byte-for-byte, as are all other fields.
local function track_clef_chunk(chunk,wanted,force)
 assert(type(chunk)=="string" and #chunk<4*1024*1024,"Track-State fehlt oder ist zu gross.")
 local depth,root,found,current=0,false,nil,0
 local pos=1
 local top,scoreFields,scoreExtra={},nil,""
 while pos<=#chunk do
  local stop=chunk:find("\n",pos,true) or #chunk+1
  local line=chunk:sub(pos,stop-1):gsub("\r$","")
  local text=line:match("^%s*(.-)%s*$")
  if depth==1 then top[#top+1]={first=pos,last=math.min(stop,#chunk),text=text} end
  if depth==1 and text:match("^SCORE%s") then
   assert(not found,"Mehrdeutige SCORE-Zeilen im Track.")
   local prefix,first,gap,clef,rest=line:match("^(%s*SCORE%s+)(%S+)(%s+)(%S+)(.*)$")
   local a,b,extra
   if rest then a,b,extra=rest:match("^%s+(%S+)%s+(%S+)(.*)$") end
   current=tonumber(clef)
   assert(first and tonumber(first) and tonumber(first)%1==0 and current and current%1==0 and current>=0 and current<=12
    and finite(tonumber(a)) and finite(tonumber(b)),"Unbekanntes SCORE-Format.")
   scoreFields={tonumber(first),current,tonumber(a),tonumber(b)};scoreExtra=extra or ""
   found={first=pos+#prefix+#first+#gap,last=pos+#prefix+#first+#gap+#clef-1}
  end
  if text:sub(1,1)=="<" then
   if depth==0 then assert(not root and (text=="<TRACK" or text:match("^<TRACK%s")),"Kein eindeutiger Track-State.");root=true end
   depth=depth+1
  elseif text==">" then depth=depth-1;assert(depth>=0,"Beschaedigter Track-State.")
  elseif depth==0 then assert(text=="","Daten ausserhalb des Track-State.") end
  pos=stop+1
 end
 assert(root and depth==0,"Unvollstaendiger Track-State.")
 local info={top=top,fields=scoreFields or {0,0,0,0},extra=scoreExtra}
 if wanted==nil or (wanted==current and not (force and not found)) then return chunk,current,info end
 assert(wanted%1==0 and wanted>=0 and wanted<=12,"Ungueltiger Schluessel.")
 if found then return chunk:sub(1,found.first-1)..wanted..chunk:sub(found.last+1),current,info end
 local lineEnd=assert(chunk:find("\n",1,true),"Track-Kopf ohne Zeilenende.")
 local nl=chunk:sub(lineEnd-1,lineEnd)=="\r\n" and "\r\n" or "\n"
 return chunk:sub(1,lineEnd).."SCORE 0 "..wanted.." 0 0"..nl..chunk:sub(lineEnd+1),current,info
end
-- REAPER 7.84 moves SCORE into its canonical position and may add the
-- default LANEREC line. Permit only those observed normalizations; compare
-- every SCORE value and all remaining track bytes, including nested chunks.
local function track_equivalent(expected,actual)
 local _,_,a=track_clef_chunk(expected)
 local _,_,b=track_clef_chunk(actual)
 for i=1,4 do if a.fields[i]~=b.fields[i] then return false end end
 if a.extra~=b.extra then return false end
 local function stripped(chunk,info)
  local result,pos={},1
  for _,line in ipairs(info.top) do
   if line.text:match("^SCORE%s") or line.text=="LANEREC -1 -1 -1 0" then
    result[#result+1]=chunk:sub(pos,line.first-1);pos=line.last+1
   end
  end
  result[#result+1]=chunk:sub(pos)
  return table.concat(result)
 end
 return stripped(expected,a)==stripped(actual,b)
end
local steps={0,0,1,1,2,3,3,4,4,5,5,6}
local function diatonic(p) return math.floor(p/12)*7+steps[p%12+1] end
local staff={{37,45},{25,33},{31,39},{29,37}} -- E4/F5, G2/A3, F3/G4, D3/E4
local function choose_clef(notes,current)
 if current>=5 then return current end -- preserve octave/percussion/chart conventions
 local costs={0,0,0,0}
 local active,drums,low,high={},0,127,0
 for _,n in ipairs(notes) do
  if not n.muted then
   if n.channel==9 then drums=drums+1 else
    active[#active+1]=n;low=math.min(low,n.pitch);high=math.max(high,n.pitch)
    local p=diatonic(n.pitch)
    local weight=math.max(0.25,math.min(2,n.duration_qn))
    for clef,range in ipairs(staff) do
     local distance=math.max(range[1]-p,p-range[2],0)
     local ledger=math.floor(distance/2)
     costs[clef]=costs[clef]+weight*ledger*ledger
    end
   end
  end
 end
 if #active==0 then return drums>0 and 10 or current end
 -- Retain an existing piano staff only for clear simultaneous broad chords.
 -- A single line, even with a large range, never creates a piano staff.
 if current==0 and low<55 and high>67 then
  for _,n in ipairs(active) do
   local chord,lo,hi=0,127,0
   for _,other in ipairs(active) do
    if math.abs(n.start_qn-other.start_qn)<0.08 and math.min(n.duration_qn,other.duration_qn)>0.125 then
     chord=chord+1;lo=math.min(lo,other.pitch);hi=math.max(hi,other.pitch)
    end
   end
   if chord>=3 and lo<55 and hi>67 then return 0 end
  end
 end
 local best=costs[2]<costs[1] and 2 or 1
 if current==1 or current==2 then
  if costs[current]<=costs[best]+0.5 then return current end
 elseif current==3 or current==4 then
  if costs[current]<=costs[best]*1.1+0.5 then return current end
 end
 return best
end
local function guid(object,take)
 local ok,id
 if take then ok,id=R.GetSetMediaItemTakeInfo_String(object,"GUID","",false)
 else ok,id=R.GetSetMediaItemInfo_String(object,"GUID","",false) end
 assert(ok and type(id)=="string" and id~="","MIDI-Identitaet fehlt.")
 return id
end
local function track_inventory(track)
 local byGUID={}
 for i=0,R.CountTrackMediaItems(track)-1 do
  local item=R.GetTrackMediaItem(track,i)
  for j=0,R.CountTakes(item)-1 do
   local take=R.GetTake(item,j)
   local id=guid(take,true)
   assert(not byGUID[id],"Doppelte Take-Identitaet.")
   local raw
   if R.TakeIsMIDI(take) then
    local ok;ok,raw=R.MIDI_GetAllEvts(take);assert(ok and type(raw)=="string","Track-Inventar nicht lesbar.")
   end
   byGUID[id]={take=take,item=item,itemGUID=guid(item,false),raw=raw,
    position=R.GetMediaItemInfo_Value(item,"D_POSITION"),length=R.GetMediaItemInfo_Value(item,"D_LENGTH"),
    rate=R.GetMediaItemTakeInfo_Value(take,"D_PLAYRATE"),offset=R.GetMediaItemTakeInfo_Value(take,"D_STARTOFFS")}
  end
 end
 return byGUID
end
local function read_track(track)
 local ok,chunk=R.GetTrackStateChunk(track,"",false)
 assert(ok and type(chunk)=="string","Track-State nicht lesbar.")
 return chunk
end
local function prepare_clefs(rows)
 local tracks,seen={},{}
 for _,row in ipairs(rows) do
  row.track=assert(R.GetMediaItem_Track(row.item),"Track fehlt.")
  row.takeGUID=guid(row.take,true);row.itemGUID=guid(row.item,false)
  local target=seen[row.track]
  if not target then
   local before=read_track(row.track)
   local _,current=track_clef_chunk(before)
   target={track=row.track,before=before,current=current,notes={},sources=track_inventory(row.track)}
   tracks[#tracks+1]=target;seen[row.track]=target
  end
  for _,note in ipairs(row.notes) do target.notes[#target.notes+1]=note end
 end
 local changed=0
 for _,target in ipairs(tracks) do
  target.wanted=choose_clef(target.notes,target.current)
  if target.wanted~=target.current then changed=changed+1 end
 end
 return tracks,changed
end
local function verify_tracks(tracks,rows,expected)
 for _,target in ipairs(tracks) do
  local now=track_inventory(target.track)
  for id,before in pairs(target.sources) do
   local after=now[id]
   assert(after and after.itemGUID==before.itemGUID and after.position==before.position and after.length==before.length
    and after.rate==before.rate and after.offset==before.offset,"Track-Items oder Takes wurden veraendert.")
   assert(after.raw==((expected and expected[id]) or before.raw),"MIDI-Integritaetspruefung nach Schluesselwahl fehlgeschlagen.")
   for _,row in ipairs(rows) do if row.takeGUID==id then row.take=after.take;row.item=after.item end end
   now[id]=nil
  end
  assert(next(now)==nil,"Unerwarteter Take nach Schluesselwahl.")
 end
end
local function zoom_value(rows,editor,percent)
 percent=percent or tonumber(R.GetExtState("NativeNotationStudio","ZoomPercent")) or 100
 assert(finite(percent) and percent>=50 and percent<=250,"Zoomfaktor muss zwischen 50 und 250 Prozent liegen.")
 local measures={}
 for _,row in ipairs(rows) do
  local track=row.track or R.GetMediaItem_Track(row.item)
  local counts=measures[track] or {};measures[track]=counts
  for _,note in ipairs(row.notes) do
   local bar=R.TimeMap_QNToMeasures(project,note.start_qn)
   counts[bar]=(counts[bar] or 0)+1
  end
 end
 local density=0
 for _,counts in pairs(measures) do for _,count in pairs(counts) do density=math.max(density,count) end end
 local base=density>=28 and 120 or density>=18 and 105 or density>=10 and 90 or 80
 local pixels=base*percent/100
 local unit=R.MIDIEditor_GetSetting_int(editor,"timebase_unit")
 assert(unit==0 or unit==1,"Zoom-Zeitbasis wird nicht unterstuetzt.")
 if unit==0 then
  local bpm=R.TimeMap2_GetDividedBpmAtTime(project,R.GetCursorPositionEx(project))
  assert(finite(bpm) and bpm>0,"Tempo fuer Zoom fehlt.")
  pixels=pixels*bpm/60
 end
 return math.floor(pixels*1024+0.5),percent,base
end
local function apply_zoom(rows,editor,percent)
 local value,factor,base=zoom_value(rows,editor,percent)
 local before=R.MIDIEditor_GetSetting_int(editor,"pixels_per_timebase_unit")
 assert(before>=0,"Aktueller Zoom konnte nicht gelesen werden.")
 local ok,why=pcall(function()
  assert(R.MIDIEditor_SetSetting_int(editor,"pixels_per_timebase_unit",value),"REAPER hat den Zoom nicht uebernommen.")
  assert(R.MIDIEditor_GetSetting_int(editor,"pixels_per_timebase_unit")==value,"Zoom-Ruecklesepruefung fehlgeschlagen.")
 end)
 if not ok then
  local restored=pcall(function()
   assert(R.MIDIEditor_SetSetting_int(editor,"pixels_per_timebase_unit",before))
   assert(R.MIDIEditor_GetSetting_int(editor,"pixels_per_timebase_unit")==before)
  end)
  error(tostring(why)..(restored and "" or " Vorheriger Zoom konnte nicht wiederhergestellt werden."))
 end
 return factor,base
end
local function zoom_dialog()
 local rows,editor=selected(true)
 local _,current=zoom_value(rows,editor)
 local ok,value=R.GetUserInputs("Native Notation Studio - Zoom",1,"Zoomfaktor in Prozent (50-250):",tostring(current))
 if not ok then return end
 local factor=tonumber(value)
 assert(factor,"Ungueltiger Zoomfaktor.")
 apply_zoom(rows,editor,factor)
 R.SetExtState("NativeNotationStudio","ZoomPercent",tostring(factor),true)
end

local function guard_visible(rows,editor)
 local focused=R.MIDIEditor_GetActive()
 assert(R.MIDIEditor_GetMode(editor)~=-1 and (not focused or focused==editor),"Editor wurde geschlossen oder gewechselt.")
 local current={}
 for i=0,65535 do
  local take=R.MIDIEditor_EnumTakes(editor,i,false);if not take then break end
  assert(R.ValidatePtr2(project,take,"MediaItem_Take*"),"Dargestellter Take ist nicht mehr gueltig.")
  current[guid(take,true)]=true
 end
 for _,row in ipairs(rows) do assert(current[row.takeGUID],"Dargestellte Tracks wurden geaendert.");current[row.takeGUID]=nil end
 assert(next(current)==nil,"Dargestellte Tracks wurden geaendert.")
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
 local tracks,clefCount=prepare_clefs(rows)
 zoom_value(rows,editor) -- Validate settings before any API request.
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
  lines[#lines+1]=string.format("Take %d | ",row_ids[t.row])..string.format("Takt %d | Taktgrenzen %.9f %.9f | ",measure+1,bar,barend)..string.format("ID %d | Start %.9f | Dauer %.9f | Ton %d | Kanal %d | Velocity %d | Stumm %s",i,n.start_qn,n.duration_qn,n.pitch,n.channel,n.velocity,tostring(n.muted))
 end
 local path=R.GetResourcePath().."/NativeNotationStudio-notes.txt"
 write_file(path,"NATIVE NOTATION STUDIO - Noteninventar\n"..table.concat(lines,"\n").."\n")
 local promptPath=R.GetResourcePath().."/NativeNotationStudio-prompt.txt"
 write_file(promptPath,[[Du bist ein Experte fuer klassische Musiknotation. Rekonstruiere fuer jede MIDI-Note den musikalisch gemeinten Einsatz und Notenwert anhand der gesamten Phrase, nicht anhand einer pauschalen Quantisierung. Unterscheide Melodie, Bass, Begleitung, Mittelstimmen und expressive Timingabweichungen. Unklare Noten, Vorschlagsnoten und mehrdeutige Faelle nicht veraendern. Gib ausschliesslich Zeilen im Format DISPLAY|ID|Start_QN|Dauer_QN|SICHER aus. Jede Zeile muss sich auf die unten genannte Originalnote beziehen. Keine erfundenen Noten. Die Antwort wird vor dem Schreiben streng validiert.
]].."\n"..table.concat(lines,"\n").."\n")
 local stamp=R.GetProjectStateChangeCount(project)
 local function complete(response)
 source_guard(rows,stamp)
 guard_visible(rows,editor)
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
 if changed==0 and clefCount==0 then show();apply_zoom(rows,editor);fail("Keine sicheren Rhythmusaenderungen; Schluessel bereits passend, Zoom angewendet.");return end
 source_guard(rows,stamp)
 guard_visible(rows,editor)
 for _,target in ipairs(tracks) do assert(read_track(target.track)==target.before,"Track-State wurde waehrend der Analyse geaendert.") end
 R.Undo_BeginBlock2(project)
 local attempted=0
 local trackAttempts={}
 local expected={}
 for _,w in ipairs(writes) do expected[w.row.takeGUID]=w.after end
 local okWrite,why=pcall(function()
  for i,w in ipairs(writes) do
   attempted=i
   local yes,now=R.MIDI_GetAllEvts(w.row.take)
   assert(yes and now==w.before,"Quell-MIDI wurde inzwischen verändert.")
   assert(R.MIDI_SetAllEvts(w.row.take,w.after),"Schreiben fehlgeschlagen.")
   local check,actual=R.MIDI_GetAllEvts(w.row.take)
   assert(check and actual==w.after,"Schreibprüfung fehlgeschlagen.")
  end
  for _,target in ipairs(tracks) do
   if target.wanted~=target.current then
    local chunk=read_track(target.track)
    local patched=track_clef_chunk(chunk,target.wanted)
    trackAttempts[#trackAttempts+1]=target
    assert(R.SetTrackStateChunk(target.track,patched,false),"Schluessel konnte nicht gesetzt werden.")
    assert(track_equivalent(patched,read_track(target.track)),"Schluessel-Ruecklesepruefung fehlgeschlagen.")
    verify_tracks(tracks,rows,expected)
    guard_visible(rows,editor)
   end
  end
  verify_tracks(tracks,rows,expected)
 end)
 if not okWrite then
  local errors={}
  for i=#trackAttempts,1,-1 do
   local target=trackAttempts[i]
   local ok=pcall(function()
    local original=track_clef_chunk(target.before,target.current,true)
    assert(R.SetTrackStateChunk(target.track,original,false))
    assert(track_equivalent(target.before,read_track(target.track)))
   end)
   if not ok then errors[#errors+1]="Track "..i end
  end
  -- Chunk setters can replace item/take pointers. Resolve stable GUIDs first.
  for _,target in ipairs(tracks) do
   local ok=pcall(function()
    local inventory=track_inventory(target.track)
    for _,row in ipairs(rows) do if row.track==target.track then
     local found=assert(inventory[row.takeGUID]);row.take=found.take;row.item=found.item
    end end
   end)
   if not ok then errors[#errors+1]="Take-Identitaet" end
  end
  for i=attempted,1,-1 do
   local w=writes[i]
   local restored=pcall(function()
    assert(R.MIDI_SetAllEvts(w.row.take,w.before))
    local yes,raw=R.MIDI_GetAllEvts(w.row.take);assert(yes and raw==w.before)
   end)
   if not restored then errors[#errors+1]=tostring(i) end
  end
  local verified=pcall(verify_tracks,tracks,rows)
  if not verified then errors[#errors+1]="Integritaetspruefung" end
  if #errors>0 then why=tostring(why).."\nWiederherstellung fehlgeschlagen fuer Takes "..table.concat(errors,",")..". Bitte sofort REAPER Undo verwenden." end
 end
 R.Undo_EndBlock2(project,okWrite and "Native Notation Studio" or "Native Notation Studio: Rücknahme",clefCount>0 and 5 or 4)
 for _,w in ipairs(writes) do if R.ValidatePtr2(project,w.row.item,"MediaItem*") then pcall(R.UpdateItemInProject,w.row.item) end end
 assert(okWrite,why)
 show()
 local zoomOK,zoomWhy=pcall(apply_zoom,rows,editor)
 fail(changed.." Rhythmus-Anzeigeaenderungen, "..clefCount.." Track-Schluessel gesetzt. REAPER Undo kann sie rueckgaengig machen."..(zoomOK and (" Zoom "..tostring(zoomWhy).."%.") or " Zoom: "..tostring(zoomWhy)))
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
 json_string=json_string,transport_files=transport_files,selected=selected,run=run,source_guard=source_guard,call_openai=call_openai,check_loop_extent=check_loop_extent,track_clef_chunk=track_clef_chunk,track_equivalent=track_equivalent,choose_clef=choose_clef,prepare_clefs=prepare_clefs,zoom_value=zoom_value,apply_zoom=apply_zoom,zoom_dialog=zoom_dialog}
if _G.NATIVE_NOTATION_TEST or _G.NATIVE_NOTATION_MODULE then return exports end
local ok,err=xpcall(run,debug.traceback)
if not ok then fail(err) end
