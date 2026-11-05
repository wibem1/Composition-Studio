local function lily_compile_import(source,insert_qn,expected_bars,prefix_items)
 -- ExecProcess returns one string: exit code, newline, captured output.
 local function process_result(raw)
  if type(raw)~="string" then return nil,"Prozess konnte nicht ausgeführt werden." end
  local first,output=raw:match("^([^\n]*)\n(.*)$")
  first=first or raw; output=output or ""
  local code=trim(first):match("^([%-]?%d+)$")
  if not code then return nil,"Ungültige Prozessantwort: "..raw:sub(-1200) end
  return tonumber(code),output
 end
 if not IS_WINDOWS then return nil,"LilyPond-MIDI-Integration derzeit für Windows." end
 local exe=lily_exe()
 if not exe then return nil,"LilyPond-Pfad nicht gefunden. Menü ... → LilyPond-Pfad einstellen." end
 local src,err=midi_score(source)
 if not src then return nil,err end
 local input=temp_path(".ly")
 local base=input:sub(1,-4)
 if not write_file(input,src) then return nil,"LilyPond-Datei konnte nicht gespeichert werden." end
 local command=shell_quote(exe)..' -dno-print-pages -dmidi-extension=mid -o '..shell_quote(base)..' '..shell_quote(input)
 local result,output=process_result(reaper.ExecProcess(command,120000))
 diag_set("lilypond_log",tostring(output or ""):sub(-12000))
 if result~=0 then return nil,"LilyPond Fehler "..tostring(result)..": "..tostring(output or ""):sub(-1200) end
 local midi=base..".mid"
 if not reaper.file_exists(midi) then return nil,"LilyPond hat keine MIDI-Datei erzeugt." end
 local prior=reaper.CountTracks(0)
 local existing={}
 for ix=0,prior-1 do existing[reaper.GetTrack(0,ix)]=true end
 local cursor=reaper.GetCursorPosition()
 reaper.Undo_BeginBlock2(0)
 local at=insert_qn and reaper.TimeMap2_QNToTime(0,insert_qn) or 0
 reaper.SetEditCurPos(at,false,false)
 local n=reaper.InsertMedia(midi,1)
 reaper.SetEditCurPos(cursor,false,false)
 local tracks=reaper.CountTracks(0)-prior
 local imported={}
 -- InsertMedia may insert after the selected track, rather than at project end.
 for ix=0,reaper.CountTracks(0)-1 do
  local tr=reaper.GetTrack(0,ix)
  if not existing[tr] then imported[#imported+1]=tr end
 end
 local made,ids={},{}
 for _,tr in ipairs(imported) do
  for j=0,reaper.CountTrackMediaItems(tr)-1 do
   local it=reaper.GetTrackMediaItem(tr,j)
   local tk=it and reaper.GetActiveTake(it)
   if tk and reaper.TakeIsMIDI(tk) then made[#made+1]=it; ids[#ids+1]=item_guid(it) end
  end
 end
 if tracks<=0 or #made==0 then
  reaper.Undo_EndBlock2(0,"Composition Studio – MIDI-Import fehlgeschlagen",-1)
  if #imported>0 then reaper.Undo_DoUndo2(0) end
  return nil,"MIDI-Datei erzeugt, aber REAPER-Import fehlgeschlagen ("..tostring(n)..")."
 end
 if prefix_items then
  local source_tracks={}; local order={}
  for _,src in ipairs(prefix_items) do if not source_tracks[src.track] then source_tracks[src.track]=true; order[#order+1]=src.track end end
  table.sort(order,function(a,b) return reaper.GetMediaTrackInfo_Value(a,"IP_TRACKNUMBER")<reaper.GetMediaTrackInfo_Value(b,"IP_TRACKNUMBER") end)
  if #order~=#imported then reaper.Undo_EndBlock2(0,"Composition Studio – Übergang abgebrochen",-1); reaper.Undo_DoUndo2(0); return nil,"Die MIDI-Spurzuordnung ist nicht eindeutig; Original unverändert." end
  local ok,err=pcall(function()
   for k,tr in ipairs(order) do
    for _,src in ipairs(prefix_items) do if src.track==tr then
     local pos=reaper.GetMediaItemInfo_Value(src.item,"D_POSITION"); local length=reaper.GetMediaItemInfo_Value(src.item,"D_LENGTH"); local boundary=reaper.TimeMap2_QNToTime(0,insert_qn)
     if pos<boundary then
      local yes,chunk=reaper.GetItemStateChunk(src.item,"",false); assert(yes,"Original nicht lesbar")
      chunk=chunk:gsub("(\nIGUID%s+){[^}]+}",function(a)return a..reaper.genGuid() end):gsub("(\nGUID%s+){[^}]+}",function(a)return a..reaper.genGuid() end)
      local copy=reaper.AddMediaItemToTrack(imported[k]); assert(copy and reaper.SetItemStateChunk(copy,chunk,false),"Original konnte nicht kopiert werden")
      reaper.SetMediaItemInfo_Value(copy,"D_LENGTH",math.min(length,boundary-pos)); made[#made+1]=copy; ids[#ids+1]=item_guid(copy)
     end
    end end
   end
  end)
  if not ok then reaper.Undo_EndBlock2(0,"Composition Studio – Übergang abgebrochen",-1); reaper.Undo_DoUndo2(0); return nil,tostring(err) end
 end
 if expected_bars then
  local num,den=reaper.TimeMap_GetTimeSigAtTime(0,at)
  num=tonumber(num) or 4; den=tonumber(den) or 4
  local expected_qn=expected_bars*4*num/den
  local highest=insert_qn
  local total_items=0
  local earliest=math.huge
  for _,tr in ipairs(imported) do
   for j=0,reaper.CountTrackMediaItems(tr)-1 do
    local item=reaper.GetTrackMediaItem(tr,j)
    local take=reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
     total_items=total_items+1
     local st=reaper.GetMediaItemInfo_Value(item,"D_POSITION")
     local en=st+reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
     earliest=math.min(earliest,reaper.TimeMap2_timeToQN(0,st))
     highest=math.max(highest,reaper.TimeMap2_timeToQN(0,en))
    end
   end
  end
  local valid=tracks>0 and total_items>0 and (prefix_items or math.abs(earliest-insert_qn)<0.05) and math.abs(highest-(insert_qn+expected_qn))<0.05
  reaper.Undo_EndBlock2(0,"Composition Studio – MIDI-Fortsetzung",-1)
  if not valid then
   reaper.Undo_DoUndo2(0)
   return nil,"Fortsetzung nicht übernommen: importierte MIDI-Länge oder Startposition stimmt nicht mit "..expected_bars.." Takten überein (Soll-QN "..string.format("%.2f",expected_qn)..", Ist-QN "..string.format("%.2f",highest-insert_qn)..")."
  end
 else
  reaper.Undo_EndBlock2(0,"Composition Studio – LilyPond MIDI",-1)
 end
 last_made=made
 reaper.SetProjExtState(0,EXT_SECTION,"LastMadeGUIDs",table.concat(ids,"\n"))
 reaper.UpdateArrange()
 return tracks
end

