local write_last_midi_to
local ensure_title_then
local export_last_midi
local save_diagnosis
local save_panel=nil
local function begin_save_panel(kind,title,default_name,ext)
 if save_panel then update_status="Ein Speichern-Dialog ist bereits geöffnet."; return end
 local script=temp_path(IS_WINDOWS and ".ps1" or ".applescript"); local out=temp_path(".path"); local done=temp_path(".done")
 if IS_WINDOWS then
  local ps=[[Add-Type -AssemblyName System.Windows.Forms
try {
  $dialog = New-Object System.Windows.Forms.SaveFileDialog
  ]]
  ps=ps.."$dialog.Title = "..ps_quote(title).."\r\n$dialog.FileName = "..ps_quote(default_name).."\r\n"
  ps=ps.."$dialog.Filter = "..ps_quote(string.upper(ext).." (*."..ext..")|*."..ext.."|Alle Dateien (*.*)|*.*").."\r\n"
  ps=ps.."$result = $dialog.ShowDialog()\r\n"
  ps=ps.."if ($result -eq [System.Windows.Forms.DialogResult]::OK) { [System.IO.File]::WriteAllText("..ps_quote(out)..",$dialog.FileName) } else { [System.IO.File]::WriteAllText("..ps_quote(out)..",'') }\r\n"
  ps=ps.."} catch { [System.IO.File]::WriteAllText("..ps_quote(out)..",'ERROR: ' + $_.Exception.Message) } finally { [System.IO.File]::WriteAllText("..ps_quote(done)..",'done') }\r\n"
  if not write_file(script,"\239\187\191"..ps) then update_status="Speichern-Dialog konnte nicht vorbereitet werden."; return end
  if not ps_launch(script,true) then os.remove(script); update_status="Windows-Speicherdialog konnte nicht gestartet werden."; return end
 else
  local function aq(v) return tostring(v or ""):gsub("\\","\\\\"):gsub('"','\\"') end
  local as='try\nset f to choose file name with prompt "'..aq(title)..'" default name "'..aq(default_name)..'"\nreturn POSIX path of f\non error number -128\nreturn ""\nend try\n'
  if not write_file(script,as) then update_status="Speichern-Dialog konnte nicht vorbereitet werden."; return end
  local cmd="(/usr/bin/osascript "..shell_quote(script).." > "..shell_quote(out).." 2>/dev/null; echo done > "..shell_quote(done)..") &"
  os.execute(cmd)
 end
 save_panel={kind=kind,script=script,out=out,done=done,ext=ext,items=(kind=="swam_midi") and swam_last_made or nil}; update_status="Speicherort wählen …"
end

local function finish_save_panel()
 if not save_panel or not read_file(save_panel.done) then return end
 local p=save_panel; save_panel=nil; local fn=trim(read_file(p.out)); os.remove(p.script); os.remove(p.out); os.remove(p.done)
 if fn:match("^ERROR:") then update_status="Windows-Dialog: "..fn; return end
  if fn=="" then update_status="Speichern abgebrochen."; return end
 if not fn:lower():match("%."..p.ext.."$") then fn=fn.."."..p.ext end
 if p.kind=="swam_midi" then write_last_midi_to(fn,p.items); return end
 if p.kind=="diagnosis" then
  local raw=diag_json(); if write_file(fn,raw) then local chk=read_file(fn); if chk and #chk==#raw then persist_diag(); write_file(DIAG_CACHE_PATH,raw); update_status="Diagnose gespeichert: "..fn.." ("..tostring(#raw).." Bytes)" else update_status="Diagnose konnte nach dem Schreiben nicht verifiziert werden: "..fn end else update_status="Diagnose konnte nicht gespeichert werden: "..fn end
 elseif p.kind=="midi" then local ok,msg=write_last_midi_to(fn); update_status=msg end
end
save_diagnosis=function()
 local title=safe_work_title(work_title)
 if title=="" then title="Composition Studio" end
 begin_save_panel("diagnosis","Diagnose speichern",title.." - Diagnose.json","json")
end

local function be16(n) return string.char(math.floor(n/256)%256,n%256) end
local function be32(n) return string.char(math.floor(n/16777216)%256,math.floor(n/65536)%256,math.floor(n/256)%256,n%256) end
local function vlq(n)
 n=math.max(0,math.floor(n+0.5)); local b={n%128}; n=math.floor(n/128)
 while n>0 do table.insert(b,1,128+n%128); n=math.floor(n/128) end
 local a={}; for _,v in ipairs(b) do a[#a+1]=string.char(v) end; return table.concat(a)
end
local function midi_track_chunk(events,name)
 table.sort(events,function(a,b) if a.tick~=b.tick then return a.tick<b.tick end return a.order<b.order end)
 local out={vlq(0),string.char(0xFF,0x03,#name),name}; local last=0
 for _,e in ipairs(events) do out[#out+1]=vlq(e.tick-last); out[#out+1]=e.data; last=e.tick end
 out[#out+1]=vlq(0)..string.char(0xFF,0x2F,0); local d=table.concat(out); return "MTrk"..be32(#d)..d
end
local function recover_last_made()
 local _,raw=reaper.GetProjExtState(0,EXT_SECTION,"LastMadeGUIDs"); if not raw or raw=="" then return {} end
 local wanted={}; for g in raw:gmatch("[^\r\n]+") do wanted[g]=true end; local found={}
 for i=0,reaper.CountMediaItems(0)-1 do local it=reaper.GetMediaItem(0,i); local ok,g=reaper.GetSetMediaItemInfo_String(it,"GUID","",false); if ok and wanted[g] then found[#found+1]=it end end
 return found
end
write_last_midi_to=function(fn,items_override)
 local valid={}; for _,it in ipairs(items_override or last_made) do if it and reaper.ValidatePtr2(0,it,"MediaItem*") then valid[#valid+1]=it end end
 if #valid==0 then valid=recover_last_made() end
 if #valid==0 then update_status="Noch keine gültige von Composition Studio erzeugte Komposition zum Exportieren."; return end

 local ppq=960; local chunks={}; local map_events={}; local count=reaper.CountTempoTimeSigMarkers(0); if count==0 then local tempo=math.max(1,reaper.Master_GetTempo()); local us=math.floor(60000000/tempo+0.5); map_events[#map_events+1]={tick=0,order=0,data=string.char(0xFF,0x51,0x03,math.floor(us/65536)%256,math.floor(us/256)%256,us%256)}; map_events[#map_events+1]={tick=0,order=1,data=string.char(0xFF,0x58,0x04,4,2,24,8)} else for i=0,count-1 do local ok,timepos,_,_,bpm,num,den=reaper.GetTempoTimeSigMarker(0,i); if ok then local qn=reaper.TimeMap2_timeToQN(0,timepos); local tick=math.max(0,math.floor(qn*ppq+0.5)); local us=math.floor(60000000/math.max(1,bpm)+0.5); local dd=0; local d=math.max(1,den); while d>1 do d=math.floor(d/2); dd=dd+1 end; map_events[#map_events+1]={tick=tick,order=0,data=string.char(0xFF,0x51,0x03,math.floor(us/65536)%256,math.floor(us/256)%256,us%256)}; map_events[#map_events+1]={tick=tick,order=1,data=string.char(0xFF,0x58,0x04,math.max(1,num),dd,24,8)} end end end; chunks[#chunks+1]=midi_track_chunk(map_events,"Tempo & Takt")
 for _,item in ipairs(valid) do
  local take=reaper.GetActiveTake(item); if take and reaper.TakeIsMIDI(take) then
   local _,name=reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false); name=name~="" and name or "MIDI"; local ev={}; local _,nc,cc=reaper.MIDI_CountEvts(take)
   for i=0,(cc or 0)-1 do local ok,_,mut,pp,typ,ch,m2,m3=reaper.MIDI_GetCC(take,i); if ok and not mut then local tm=reaper.MIDI_GetProjTimeFromPPQPos(take,pp); local q=reaper.TimeMap2_timeToQN(0,tm); local tick=math.max(0,math.floor(q*ppq+0.5)); if typ==0xC0 then ev[#ev+1]={tick=tick,order=0,data=string.char(0xC0+(ch or 0),m2 or 0)} elseif typ==0xB0 then ev[#ev+1]={tick=tick,order=0,data=string.char(0xB0+(ch or 0),m2 or 0,m3 or 0)} end end end
   for i=0,(nc or 0)-1 do local ok,_,mut,sn,en,ch,pit,vel=reaper.MIDI_GetNote(take,i); if ok and not mut then local st=reaper.MIDI_GetProjTimeFromPPQPos(take,sn); local et=reaper.MIDI_GetProjTimeFromPPQPos(take,en); local ta=math.max(0,math.floor(reaper.TimeMap2_timeToQN(0,st)*ppq+0.5)); local tb=math.max(ta+1,math.floor(reaper.TimeMap2_timeToQN(0,et)*ppq+0.5)); ev[#ev+1]={tick=ta,order=2,data=string.char(0x90+ch,pit,vel)}; ev[#ev+1]={tick=tb,order=1,data=string.char(0x80+ch,pit,0)} end end
   chunks[#chunks+1]=midi_track_chunk(ev,name)
  end
 end
 local smf="MThd"..be32(6)..be16(1)..be16(#chunks)..be16(ppq)..table.concat(chunks); if write_file(fn,smf) then local chk=read_file(fn); if chk and #chk==#smf and chk:sub(1,4)=="MThd" then update_status="MIDI gespeichert: "..fn.." ("..tostring(#valid).." Spur(en), "..tostring(#smf).." Bytes)" else update_status="MIDI-Datei konnte nach dem Schreiben nicht verifiziert werden: "..fn end else update_status="MIDI konnte nicht gespeichert werden: "..fn end
end
