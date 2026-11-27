-- Local AI component discovery and MIDI-DDSP adapter.
-- External worker is user-selected and is never installed, edited, or auto-downloaded here.
local ai_component_manager=(function()
local manager={open=false,job=nil,status="Python und Worker auswählen, dann Verbindung prüfen.",
 python=reaper.GetExtState(EXT_SECTION,"LocalDDSPPythonV1"),
 worker=reaper.GetExtState(EXT_SECTION,"LocalDDSPWorkerV1"),
 instrument=1,checked=false,weights=false,output=nil,output_position=0,cancel_requested=false}
local AI_DDSP_INSTRUMENTS={
 {"Violine","violin"},{"Bratsche","viola"},{"Cello","cello"},{"Kontrabass","double-bass"},
 {"Flöte","flute"},{"Oboe","oboe"},{"Klarinette","clarinet"},{"Saxophon","saxophone"},
 {"Fagott","bassoon"},{"Trompete","trumpet"},{"Horn","horn"},{"Posaune","trombone"},{"Tuba","tuba"}
}
local function ai_component_file_exists(path)
 local f=io.open(path,"rb");if not f then return false end;f:close();return true
end
local function ai_component_choose(key,title,extension)
 local ok,path=reaper.GetUserFileNameForRead("",title,extension)
 if ok and path and path~="" then
  manager[key]=path
  reaper.SetExtState(EXT_SECTION,key=="python" and "LocalDDSPPythonV1" or "LocalDDSPWorkerV1",path,true)
  manager.checked=false;manager.weights=false
  manager.status="Pfad gespeichert. Bitte Verbindung prüfen."
 end
end
local function ai_component_start(action,request_path,output_path)
 if manager.job then return false end
 if not IS_WINDOWS then manager.status="MIDI-DDSP-Worker wird in dieser Fassung nur unter Windows gestartet.";return false end
 if manager.python=="" or manager.worker=="" then
  manager.status="Bitte Python.exe und midi_ddsp_worker.py auswählen.";return false
 end
 local py_leaf=(manager.python:gsub("\\","/"):match("([^/]+)$") or ""):lower()
 local worker_leaf=(manager.worker:gsub("\\","/"):match("([^/]+)$") or ""):lower()
 if py_leaf~="python.exe" and py_leaf~="python3.exe" then
  manager.status="Nur python.exe oder python3.exe wird gestartet.";return false
 end
 if worker_leaf~="midi_ddsp_worker.py" then
  manager.status="Es wird ausschließlich midi_ddsp_worker.py gestartet.";return false
 end
 local stdout,stderr,exit,pid,script=temp_path(".ddsp.out"),temp_path(".ddsp.err"),temp_path(".ddsp.exit"),temp_path(".ddsp.pid"),temp_path(".ddsp.ps1")
 local args='"'..manager.worker..'" '..(action=="check" and "--check" or '"'..request_path..'"')
 local lines={
  "$ErrorActionPreference = 'Stop'",
  "$p = Start-Process -FilePath "..ps_quote(manager.python).." -ArgumentList "..ps_quote(args)..
    " -PassThru -WindowStyle Hidden -RedirectStandardOutput "..ps_quote(stdout).." -RedirectStandardError "..ps_quote(stderr),
  "[IO.File]::WriteAllText("..ps_quote(pid)..",[string]$p.Id)",
  "if (-not $p.WaitForExit(900000)) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; [IO.File]::WriteAllText("..ps_quote(exit)..",'TIMEOUT') } else { $p.WaitForExit(); [IO.File]::WriteAllText("..ps_quote(exit)..",[string]$p.ExitCode) }",
  "Remove-Item -LiteralPath "..ps_quote(script).." -ErrorAction SilentlyContinue"
 }
 local f=io.open(script,"wb")
 if not f then manager.status="PowerShell-Startdatei konnte nicht erstellt werden.";return false end
 f:write("\239\187\191"..table.concat(lines,"\r\n"));f:close()
 if not ps_launch(script,true) then os.remove(script);manager.status="Der lokale MIDI-DDSP-Prozess konnte nicht gestartet werden.";return false end
 manager.job={action=action,request=request_path,output=output_path,stdout=stdout,stderr=stderr,exit=exit,pid=pid,script=script,deadline=reaper.time_precise()+905,cancelled=false}
 manager.status=action=="check" and "MIDI-DDSP-Umgebung wird geprüft …" or "MIDI-DDSP rendert die ausgewählte MIDI-Partie …"
 return true
end
local function poll_ai_components()
 local j=manager.job;if not j then return end
 local code=read_file(j.exit)
 if not code and reaper.time_precise()<j.deadline then return end
 manager.job=nil
 local stdout=read_file(j.stdout) or "";local stderr=read_file(j.stderr) or ""
 local value=trim(code or "TIMEOUT")
 if j.cancelled or manager.cancel_requested then
  manager.status="MIDI-DDSP-Auftrag abgebrochen.";manager.cancel_requested=false
 elseif value=="0" then
  if j.action=="check" then
   manager.checked=stdout:find('"ok"%s*:%s*true')~=nil
   manager.weights=stdout:find('"weights"%s*:%s*true')~=nil
   if manager.checked and manager.weights then manager.status="MIDI-DDSP einsatzbereit; Modellgewichte gefunden."
   elseif manager.checked then manager.status="Python-Pakete importierbar, aber MIDI-DDSP-Modellgewichte fehlen. Es wird nichts automatisch heruntergeladen."
   else manager.status="Der Worker meldet keinen erfolgreichen Importtest. Diagnoseausgabe prüfen." end
  elseif stdout:find('"done"%s*:%s*true') and j.output and ai_component_file_exists(j.output) then
   manager.output=j.output;manager.output_position=j.position or 0
   manager.status="Audio fertig. Vor dem Import kannst du die Datei prüfen."
  else manager.status="Der Worker endete ohne gültige Audioausgabe. "..trim(stderr):sub(-500) end
 else
  manager.checked=false;manager.weights=false
  local detail=trim(stderr);if detail=="" then detail=trim(stdout) end
  if value=="TIMEOUT" then manager.status="MIDI-DDSP nach 15 Minuten beendet (Zeitlimit)."
  else manager.status="MIDI-DDSP fehlgeschlagen ("..value.."): "..detail:sub(-500) end
 end
 for _,p in ipairs({j.stdout,j.stderr,j.exit,j.pid,j.request,j.script}) do if p and p~="" then os.remove(p) end end
end
local function ai_component_cancel()
 local j=manager.job;if not j then return end
 local raw=read_file(j.pid);local pid=tonumber(trim(raw or ""))
 if not pid then manager.status="Abbruch wird vorbereitet; Prozesskennung noch nicht verfügbar.";return end
 local script=temp_path(".ddsp-cancel.ps1");local f=io.open(script,"wb")
 if not f then manager.status="Abbruchskript konnte nicht erstellt werden.";return end
 f:write("\239\187\191Stop-Process -Id "..math.floor(pid).." -Force -ErrorAction SilentlyContinue\r\nRemove-Item -LiteralPath "..ps_quote(script).." -ErrorAction SilentlyContinue\r\n");f:close()
 if ps_launch(script,true) then j.cancelled=true;manager.status="MIDI-DDSP wird abgebrochen …"
 else manager.status="Abbruch konnte nicht ausgelöst werden." end
end
local function ai_component_check()
 manager.checked=false;manager.weights=false
 ai_component_start("check")
end
local function ai_component_selected_notes()
 local item=reaper.GetSelectedMediaItem(0,0)
 local take=item and reaper.GetActiveTake(item) or nil
 if not take then
  local editor=reaper.MIDIEditor_GetActive()
  take=editor and reaper.MIDIEditor_GetTake(editor) or nil
  if take then item=reaper.GetMediaItemTake_Item(take) end
 end
 if not take or not item or not reaper.TakeIsMIDI(take) then return nil,nil,"Bitte ein MIDI-Item auswählen oder im MIDI-Editor öffnen." end
 local ok,count=reaper.MIDI_CountEvts(take)
 if not ok or not count or count<1 then return nil,nil,"Das MIDI-Item enthält keine Noten." end
 local item_start=reaper.GetMediaItemInfo_Value(item,"D_POSITION")
 local notes={}
 for i=0,count-1 do
  local good,_,muted,startppq,endppq,_,pitch,velocity=reaper.MIDI_GetNote(take,i)
  if good and not muted then
   local start=reaper.MIDI_GetProjTimeFromPPQPos(take,startppq)-item_start
   local finish=reaper.MIDI_GetProjTimeFromPPQPos(take,endppq)-item_start
   if finish>start then notes[#notes+1]=string.format('{"pitch":%d,"start":%.6f,"end":%.6f,"velocity":%d}',pitch,start,finish,velocity) end
  end
 end
 if #notes==0 then return nil,nil,"Keine spielbaren MIDI-Noten gefunden." end
 return notes,item_start,nil
end
local function ai_component_render()
 if not manager.checked then manager.status="Zuerst die MIDI-DDSP-Umgebung prüfen.";return end
 if not manager.weights then manager.status="MIDI-DDSP-Modelle fehlen. Der Worker wird nicht gestartet, damit er nichts ungefragt herunterlädt.";return end
 local notes,position,err=ai_component_selected_notes()
 if not notes then manager.status=err;return end
 local instrument=AI_DDSP_INSTRUMENTS[manager.instrument][2]
 local output=temp_path(".wav");local request=temp_path(".json")
 local payload='{"notes":['..table.concat(notes,",")..'],"instrument":"'..instrument..'","out":"'..json_escape(output)..'","voices":4,"transpose":0}'
 if not write_file(request,payload) then manager.status="MIDI-Anfrage konnte nicht geschrieben werden.";return end
 local started=ai_component_start("render",request,output)
 if started then manager.job.position=position else os.remove(request) end
end
local function ai_component_import()
 local path=manager.output
 if not path or not ai_component_file_exists(path) then manager.status="Die erzeugte WAV-Datei wurde nicht gefunden.";return end
 local cursor=reaper.GetCursorPosition()
 local selected={}
 local n=reaper.CountTracks(0)
 for i=0,n-1 do
  local tr=reaper.GetTrack(0,i)
  local was=reaper.GetMediaTrackInfo_Value(tr,"I_SELECTED")>0
  selected[#selected+1]={track=tr,selected=was}
  reaper.SetMediaTrackInfo_Value(tr,"I_SELECTED",0)
 end
 reaper.Undo_BeginBlock2(0)
 local ok,err=xpcall(function()
  local index=reaper.CountTracks(0);reaper.InsertTrackAtIndex(index,true)
  local track=reaper.GetTrack(0,index)
  assert(track,"Neue Audiospur konnte nicht angelegt werden.")
  reaper.GetSetMediaTrackInfo_String(track,"P_NAME","MIDI-DDSP – "..AI_DDSP_INSTRUMENTS[manager.instrument][1],true)
  reaper.SetMediaTrackInfo_Value(track,"I_SELECTED",1)
  reaper.SetEditCurPos(manager.output_position,false,false)
  reaper.InsertMedia(path,0)
  assert(reaper.CountTrackMediaItems(track)>0,"REAPER hat die WAV-Datei nicht auf der neuen Spur eingefügt.")
 end,function(e)return tostring(e) end)
 if not ok then
  reaper.Undo_EndBlock2(0,"MIDI-DDSP-Import zurücknehmen",-1)
  pcall(reaper.Undo_DoUndo2,0)
 else
  reaper.Undo_EndBlock2(0,"MIDI-DDSP-Audio auf neuer Spur übernehmen",-1)
 end
 reaper.SetEditCurPos(cursor,false,false)
 for _,entry in ipairs(selected) do pcall(reaper.SetMediaTrackInfo_Value,entry.track,"I_SELECTED",entry.selected and 1 or 0) end
 if ok then manager.status="Audio auf neuer REAPER-Spur übernommen.";manager.output=nil
 else manager.status="Import zurückgenommen: "..tostring(err) end
end
local function open_ai_components() manager.open=true end
local function draw_ai_components(ctx)
 reaper.ImGui_Text(ctx,"Lokale Engine · MIDI-DDSP")
 reaper.ImGui_TextWrapped(ctx,"Composition Studio ruft den ausgewählten Worker direkt auf. AI Music Studio muss nicht laufen; seine Dateien werden nicht geändert.")
 if reaper.ImGui_Button(ctx,"Python.exe auswählen …",-1) then ai_component_choose("python","MIDI-DDSP Python auswählen","exe") end
 reaper.ImGui_TextWrapped(ctx,manager.python~="" and manager.python or "Python: nicht ausgewählt")
 if reaper.ImGui_Button(ctx,"midi_ddsp_worker.py auswählen …",-1) then ai_component_choose("worker","MIDI-DDSP Worker auswählen","py") end
 reaper.ImGui_TextWrapped(ctx,manager.worker~="" and manager.worker or "Worker: nicht ausgewählt")
 if reaper.ImGui_Button(ctx,"Umgebung prüfen",-1) and not manager.job then ai_component_check() end
 if manager.job then
  if reaper.ImGui_Button(ctx,"Auftrag abbrechen",-1) then ai_component_cancel() end
 else
  local inst=AI_DDSP_INSTRUMENTS[manager.instrument]
  if reaper.ImGui_Button(ctx,"Instrument: "..inst[1].." (weiter)",-1) then
   manager.instrument=manager.instrument%#AI_DDSP_INSTRUMENTS+1
  end
  if reaper.ImGui_Button(ctx,"Ausgewähltes MIDI rendern",-1) then ai_component_render() end
  if manager.output and reaper.ImGui_Button(ctx,"WAV auf neuer REAPER-Spur übernehmen",-1) then ai_component_import() end
 end
 reaper.ImGui_Separator(ctx)
 reaper.ImGui_TextWrapped(ctx,"Status: "..manager.status)
 if manager.checked then
  reaper.ImGui_TextWrapped(ctx,"Komponentenstatus: Python/Worker importierbar"..(manager.weights and " · Gewichte vorhanden" or " · Gewichte fehlen"))
 end
 if manager.output then reaper.ImGui_TextWrapped(ctx,"Renderdatei: "..manager.output.."\nMIDI-Item-Start: "..string.format("%.3f s",manager.output_position)) end
 reaper.ImGui_TextWrapped(ctx,"Prüfen und Rendern sind lokale CPU-Aufrufe. Fehlende Modellgewichte werden nicht automatisch geladen.")
end
manager.draw=draw_ai_components
manager.open_window=open_ai_components
manager.poll=poll_ai_components
return manager
end)()
-- BEGIN MODULE EXPORTS
return {ai_component_manager=ai_component_manager}
